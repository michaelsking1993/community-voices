module Reports
  # The RAG arm's evidence: for each theme, retrieve this week's closest
  # posts (max 2 per thread), plus a few look-alike posts from earlier
  # weeks so the model can say "this came up before" or spot a trend.
  #
  # Two guards against missing what mattered (DECISIONS #53):
  # - Budget by size: a theme's share of THIS_WEEK_TOTAL follows its share
  #   of the week's threads, so a 33-thread theme is not given the same 6
  #   chunks as a 4-thread one.
  # - Busiest threads: a query built from the theme's label lands near its
  #   centre, and a big thread at the edge can lose. So each theme's
  #   BUSIEST threads by post count (SQL) always get their chunk closest to
  #   the query (vectors).
  #
  # Themes with no chunk under the retriever's distance cut-off get no
  # evidence, and the report lists them as "not enough evidence".
  # Signals for predictions (trends, releases) are added at the end.
  class RagEvidence
    THIS_WEEK_TOTAL = 36 # chunks from the report's week, shared by size
    THIS_WEEK = 3..12    # fewest and most chunks one theme gets
    BUSIEST = 2          # threads per theme that always get a chunk
    HISTORY = 3          # chunks per theme from earlier weeks
    HISTORY_WEEKS = 12

    def initialize(retriever: Search::Retriever.new, signals: Signals.new)
      @retriever = retriever
      @signals = signals
    end

    attr_reader :retrievals

    def call(week, themes)
      @retrievals = []
      evidence = Evidence.new
      threads = themes.sum(&:topic_count)
      themes.each do |theme|
        query = "#{theme.label}. #{theme.summary}"
        found = retrieve(query, week.range, budget(theme, threads), "report").chunks
        found += busiest(theme, query, week, found)
        found.each { |chunk| evidence.add(chunk, theme: theme.position) }
        add_history(evidence, theme, retrieve(query, history_window(week), HISTORY, "report_history", per_topic: 1))
      end
      @signals.call(week, themes, evidence)
    end

    def budget(theme, threads)
      return THIS_WEEK.min if threads.zero?

      (THIS_WEEK_TOTAL * theme.topic_count.fdiv(threads)).round.clamp(THIS_WEEK)
    end

    private

    # The best chunk of each of the theme's busiest threads that the
    # similarity search did not already bring back.
    def busiest(theme, query, week, found)
      have = found.map { _1.post.topic_id }
      missing = theme.theme_topics.sort_by { -_1.post_count }.first(BUSIEST).map(&:topic_id) - have
      return [] if missing.empty?

      retrieve(query, week.range, missing.size, "report_busiest", per_topic: 1, topic_ids: missing).chunks
    end

    def retrieve(query, window, k, purpose, per_topic: Search::Retriever::PER_TOPIC, topic_ids: nil)
      @retriever.call(query, window:, k:, per_topic:, purpose:, topic_ids:).tap { @retrievals << _1.retrieval }
    end

    def add_history(evidence, theme, result)
      result.chunks.each { |chunk| evidence.add(chunk, theme: theme.position, history: true) }
    end

    def history_window(week) = week.previous(HISTORY_WEEKS).range.begin...week.range.begin
  end
end
