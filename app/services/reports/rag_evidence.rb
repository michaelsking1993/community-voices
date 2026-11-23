module Reports
  # The RAG arm's evidence: for each theme, retrieve this week's closest
  # posts (max 2 per thread), plus a few look-alike posts from earlier
  # weeks so the model can say "this came up before" or spot a trend.
  #
  # Themes with no chunk under the retriever's distance cut-off get no
  # evidence, and the report lists them as "not enough evidence".
  class RagEvidence
    THIS_WEEK = 6        # chunks per theme from the report's week
    HISTORY = 3          # chunks per theme from earlier weeks
    HISTORY_WEEKS = 12

    def initialize(retriever: Search::Retriever.new)
      @retriever = retriever
    end

    attr_reader :retrievals

    def call(week, themes)
      @retrievals = []
      evidence = Evidence.new
      themes.each do |theme|
        query = "#{theme.label}. #{theme.summary}"
        add(evidence, theme, retrieve(query, week.range, THIS_WEEK, "report"))
        add(evidence, theme, retrieve(query, history_window(week), HISTORY, "report_history", per_topic: 1), history: true)
      end
      evidence
    end

    private

    def retrieve(query, window, k, purpose, per_topic: Search::Retriever::PER_TOPIC)
      @retriever.call(query, window:, k:, per_topic:, purpose:).tap { @retrievals << _1.retrieval }
    end

    def add(evidence, theme, result, history: false)
      result.chunks.each { |chunk| evidence.add(chunk, theme: theme.position, history:) }
    end

    def history_window(week) = week.previous(HISTORY_WEEKS).range.begin...week.range.begin
  end
end
