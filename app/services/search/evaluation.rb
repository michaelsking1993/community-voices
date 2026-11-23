module Search
  # Scores the retriever against a small hand-labelled set. For each query
  # we wrote down which forum threads a good answer should come from, then:
  #
  #   hit      did any relevant thread show up in the top k?
  #   recall   what share of the relevant threads showed up?
  #   threads  how many different threads the top k covered
  #
  # Each query runs twice, with and without the per-thread cap, so the
  # effect of diversity is measured rather than assumed. Off-topic queries
  # check the other direction: nothing about Anki should come back at all.
  class Evaluation
    Case = Data.define(:query, :relevant) # relevant: forum (Discourse) topic ids
    Row = Data.define(:query, :config, :hit, :recall, :threads)
    Summary = Data.define(:config, :queries, :hit_rate, :recall, :threads)

    CONFIGS = { "plain top-k" => { per_topic: nil }, "max 2 per thread" => { per_topic: 2 } }.freeze
    CASES_PATH = Rails.root.join("config/eval/retrieval.yml")

    def self.cases(path = CASES_PATH)
      YAML.load_file(path).fetch("queries").map { |c| Case.new(query: c.fetch("query"), relevant: c.fetch("relevant")) }
    end

    def self.off_topic(path = CASES_PATH) = YAML.load_file(path).fetch("off_topic")

    def initialize(retriever: Retriever.new, k: Retriever::K)
      @retriever = retriever
      @k = k
    end

    # Cases whose threads are not in the database (a different crawl
    # window) are skipped rather than counted as misses.
    def call(cases)
      ids = Topic.where(discourse_id: cases.flat_map(&:relevant)).pluck(:discourse_id, :id).to_h
      cases.flat_map do |c|
        relevant = c.relevant.filter_map { ids[_1] }
        relevant.empty? ? [] : CONFIGS.map { |name, opts| score(c.query, relevant, name, opts) }
      end
    end

    # Share of off-topic queries that correctly came back empty.
    def off_topic_empty_rate(queries)
      queries.count { |q| @retriever.call(q, k: @k, purpose: "eval").empty? }.fdiv(queries.size).round(2)
    end

    def summarize(rows)
      rows.group_by(&:config).map do |config, group|
        Summary.new(config:, queries: group.size, hit_rate: mean(group.map { _1.hit ? 1 : 0 }),
                    recall: mean(group.map(&:recall)), threads: mean(group.map(&:threads)))
      end
    end

    private

    def score(query, relevant, config, opts)
      topics = @retriever.call(query, k: @k, purpose: "eval", **opts).chunks.map { _1.post.topic_id }
      found = relevant & topics
      Row.new(query:, config:, hit: found.any?, recall: found.size.fdiv(relevant.size), threads: topics.uniq.size)
    end

    def mean(values) = values.sum.fdiv(values.size).round(2)
  end
end
