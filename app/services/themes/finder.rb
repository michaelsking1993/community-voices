module Themes
  # Finds a week's themes in three moves:
  #
  # 1. Vectors   one per forum thread: the average of its chunks' embeddings
  #              from that week (pgvector's avg() does this in SQL).
  # 2. Cluster   k-means groups threads that point the same way.
  # 3. Name      one model call labels every cluster from a few excerpts.
  #
  # Counts (threads, posts, authors) come from SQL. The model only names
  # and summarises; it never counts. Re-running a week replaces its themes.
  class Finder
    K = 8              # themes per week (~60 threads, so ~8 threads each)
    EXCERPTS = 5       # threads shown to the model per cluster
    TITLES = 12        # thread titles listed per cluster
    EXCERPT_WORDS = 80

    SYSTEM = <<~PROMPT.freeze
      You name the themes in one week of posts from the Anki forums (forums.ankiweb.net), the community for the Anki flashcard app.

      An algorithm grouped the week's forum threads into clusters of similar threads. For each cluster, write:
      - label: 2 to 6 plain words a product team would recognise, e.g. "Media lost after sync".
      - summary: one sentence on what people are saying or asking.
      - kind: problem, request, discussion, announcement, or other.

      Use only the titles and excerpts given. If a cluster mixes unrelated threads, say so in the summary and use kind "other".
    PROMPT

    SCHEMA = {
      type: "object", additionalProperties: false, required: [ "themes" ],
      properties: { themes: { type: "array", items: {
        type: "object", additionalProperties: false, required: %w[cluster label summary kind],
        properties: { cluster: { type: "integer" }, label: { type: "string" }, summary: { type: "string" },
                      kind: { type: "string", enum: Theme::KINDS } }
      } } }
    }.freeze

    Cluster = Data.define(:number, :centroid, :members) # members: [[topic_id, similarity]], closest first

    def initialize(llm: Llm::Client.new(effort: :low), k: K)
      @llm = llm
      @k = k
    end

    attr_reader :last_response

    def call(week)
      vectors = thread_vectors(week)
      return [] if vectors.empty?

      clusters = cluster(vectors)
      posts_per_topic = Post.posted_between(week.range.begin, week.range.end).group(:topic_id).count
      labels = name(clusters, week)
      save(week, clusters, labels, posts_per_topic)
    end

    private

    def thread_vectors(week)
      Chunk.joins(:post).where(posts: { posted_at: week.range }).where.not(embedding: nil)
           .group("posts.topic_id").pluck("posts.topic_id", Arel.sql("avg(chunks.embedding)::text"))
           .to_h { |topic_id, avg| [ topic_id, KMeans.normalize(JSON.parse(avg)) ] }
    end

    def cluster(vectors)
      result = KMeans.new(k: @k).call(vectors.values)
      ids = vectors.keys
      result.centroids.each_with_index.filter_map do |centroid, number|
        members = ids.each_index.select { |i| result.assignments[i] == number }
                     .map { |i| [ ids[i], KMeans.dot(vectors[ids[i]], centroid) ] }
                     .sort_by { -_2 }
        Cluster.new(number: number + 1, centroid:, members:) if members.any?
      end
    end

    def name(clusters, week)
      prompt = "Week: #{week}\n\n" + clusters.map { |c| describe(c, week) }.join("\n\n")
      @last_response = @llm.json(system: SYSTEM, prompt:, schema: SCHEMA)
      @last_response.data.fetch("themes").index_by { _1["cluster"] }
    end

    def describe(cluster, week)
      topics = Topic.where(id: cluster.members.map(&:first)).index_by(&:id)
      ordered = cluster.members.map { |id, _| topics[id] }
      excerpts = ordered.first(EXCERPTS).map { |topic| "- [#{topic.category_name}] \"#{topic.title}\": #{excerpt(topic, week)}" }
      <<~TEXT.strip
        ## Cluster #{cluster.number} (#{ordered.size} threads)
        Titles: #{ordered.first(TITLES).map(&:title).join(" | ")}
        Excerpts:
        #{excerpts.join("\n")}
      TEXT
    end

    # The thread's first chunk that week, without its header.
    def excerpt(topic, week)
      chunk = Chunk.joins(:post).where(posts: { topic_id: topic.id, posted_at: week.range })
                   .order("posts.posted_at", :position).first
      chunk.content.split("\n\n", 2).last.split.first(EXCERPT_WORDS).join(" ")
    end

    def save(week, clusters, labels, posts_per_topic)
      rows = clusters.map { |c| [ c, c.members.sum { |id, _| posts_per_topic.fetch(id, 0) } ] }.sort_by { -_2 }
      Theme.transaction do
        Theme.where(week_start: week.start).destroy_all
        rows.each_with_index.map do |(cluster, post_count), i|
          create_theme(week, cluster, labels[cluster.number], post_count, i + 1, posts_per_topic)
        end
      end
    end

    def create_theme(week, cluster, label, post_count, position, posts_per_topic)
      topic_ids = cluster.members.map(&:first)
      authors = Post.posted_between(week.range.begin, week.range.end).where(topic_id: topic_ids).distinct.count(:username)
      fallback = Topic.find(topic_ids.first).title
      Theme.create!(
        week_start: week.start, position:, centroid: cluster.centroid,
        label: label&.dig("label") || fallback, summary: label&.dig("summary") || "", kind: label&.dig("kind") || "other",
        topic_count: topic_ids.size, post_count:, author_count: authors,
        theme_topics: cluster.members.map { |id, sim| ThemeTopic.new(topic_id: id, similarity: sim, post_count: posts_per_topic.fetch(id, 0)) }
      )
    end
  end
end
