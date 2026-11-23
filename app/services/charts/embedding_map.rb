module Charts
  # The "flattened visualization of the embeddings": one dot per forum
  # thread (the average of its chunk vectors) squashed from 384 numbers to
  # 2 with PCA, so threads about similar things land near each other.
  #
  # PCA finds the two directions along which the threads differ most. It is
  # a blunt tool (a lot is lost going from 384 to 2 numbers), but it is
  # deterministic, needs no library, and is enough to see clusters.
  class EmbeddingMap
    MAX_THREADS = 1500
    TOP_CATEGORIES = 7

    def call(weeks: 12)
      rows = thread_vectors(weeks)
      return [] if rows.size < 3

      points = Pca.project(rows.map(&:last).map { Themes::KMeans.normalize(_1) })
      [ Chart.build(id: "embedding-map", title: "Map of the forum's threads",
                    caption: "#{rows.size} threads from the last #{weeks} weeks, each placed by the meaning of its posts (384 numbers flattened to 2 with PCA). Closer means more similar; colours are the forum's own categories. Hover for the title.",
                    traces: traces(rows, points), layout: { xaxis: { visible: false }, yaxis: { visible: false }, hovermode: "closest", height: 520 }) ]
    end

    private

    # [[topic, vector], ...] for threads with a post in the window.
    def thread_vectors(weeks)
      since = Week.last_complete.finish.in_time_zone - weeks.weeks
      sql = Chunk.joins(:post).where(posts: { posted_at: since.. }).where.not(embedding: nil).group("posts.topic_id")
                 .order(Arel.sql("count(*) desc")).limit(MAX_THREADS)
      averages = sql.pluck("posts.topic_id", Arel.sql("avg(chunks.embedding)"))
      topics = Topic.where(id: averages.map(&:first)).index_by(&:id)
      averages.map { |id, vector| [ topics[id], vector.is_a?(String) ? JSON.parse(vector) : vector.to_a ] }
    end

    def traces(rows, points)
      names = rows.map { _1.first.category_name.to_s.split("›").first.to_s.strip.presence || "Other" }
      top = names.tally.max_by(TOP_CATEGORIES, &:last).map(&:first)
      names.each_with_index.group_by { |name, _| top.include?(name) ? name : "Other" }.map do |name, members|
        indexes = members.map(&:last)
        { type: "scatter", mode: "markers", name:, x: indexes.map { points[_1][0].round(4) }, y: indexes.map { points[_1][1].round(4) },
          text: indexes.map { rows[_1].first.title.truncate(80) }, hovertemplate: "%{text}<extra>#{name}</extra>", marker: { size: 7, opacity: 0.75 } }
      end
    end
  end
end
