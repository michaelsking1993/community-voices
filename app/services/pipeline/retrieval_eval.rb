module Pipeline
  # The retrieval eval as a task: score the retriever on the hand-labelled
  # queries (Search::Evaluation), then return a printable table plus the
  # same numbers as data for the Evaluate tab.
  #
  # Eval searches are deleted afterwards, so they never count in the
  # "most retrieved" stats on the Charts page.
  class RetrievalEval
    Result = Data.define(:text, :data)
    OffTopic = Data.define(:queries, :empty_rate)

    def initialize(evaluation: Search::Evaluation.new)
      @evaluation = evaluation
    end

    def call
      rows = @evaluation.call(Search::Evaluation.cases)
      raise Error, "None of the labelled threads are loaded. Crawl 12 weeks first." if rows.empty?

      summary = @evaluation.summarize(rows)
      off_topic = off_topic_result
      Retrieval.where(purpose: "eval").delete_all
      Result.new(text: text(rows, summary, off_topic), data: data(summary, off_topic))
    end

    private

    def off_topic_result
      queries = Search::Evaluation.off_topic
      OffTopic.new(queries: queries.size, empty_rate: @evaluation.off_topic_empty_rate(queries))
    end

    def text(rows, summary, off_topic)
      [ *per_query_lines(rows), "", *summary_lines(summary), "", off_topic_line(off_topic) ].join("\n")
    end

    def per_query_lines(rows)
      rows.group_by(&:query).flat_map do |query, by_config|
        [ query, *by_config.map { |r| format("  %-18s hit=%-5s recall=%.2f threads=%d", r.config, r.hit, r.recall, r.threads) } ]
      end
    end

    def summary_lines(summary)
      header = "config              queries  hit rate  recall  threads in top #{Search::Retriever::K}"
      [ header, *summary.map { |s| format("%-18s  %7d  %8.2f  %6.2f  %7.1f", s.config, s.queries, s.hit_rate, s.recall, s.threads) } ]
    end

    def off_topic_line(off_topic)
      "Off-topic queries that correctly found nothing: #{(off_topic.empty_rate * 100).round}% of #{off_topic.queries}"
    end

    def data(summary, off_topic)
      { "configs" => summary.map { _1.to_h.transform_keys(&:to_s) },
        "off_topic_empty_rate" => off_topic.empty_rate, "off_topic_queries" => off_topic.queries }
    end
  end
end
