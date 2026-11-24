module Ab
  # The A/B test for one week: write the report three ways (same rules,
  # same schema, same model; only the context differs), check each
  # in code, have a judge check support and rank them blind.
  #
  #   none       no posts at all: what you get by just asking an LLM
  #   paste_all  every post of the week in the prompt once: no search, no themes
  #   rag        themes, then retrieval per theme (the app's own method)
  #
  # Stored reports and judgements are reused, so re-running is free.
  class Run
    ARMS = %w[rag paste_all none].freeze # rag first: it finds and stores the week's themes

    def initialize(llm: Llm.client, judge_llm: llm, builders: nil)
      @builders = builders || default_builders(llm)
      @support = SupportJudge.new(llm: judge_llm)
      @ranker = Ranker.new(llm: judge_llm)
    end

    def call(week)
      reports = ARMS.index_with { |arm| report_for(week, arm) }
      reports.each_value { |report| Judgement.find_by(kind: "support", report:) || @support.call(report) }
      Judgement.find_by(kind: "ranking", week_start: week.start) || @ranker.call(week, reports)
      reports
    end

    private

    def report_for(week, arm)
      Report.done.where(week_start: week.start, arm:).latest_first.first || @builders.fetch(arm).call(week)
    end

    def default_builders(llm)
      { "rag" => Reports::Builder.new(llm:),
        "paste_all" => Reports::Builder.new(llm:, arm: "paste_all", evidence_source: Reports::PasteAllEvidence.new, themes: false),
        "none" => Reports::Builder.new(llm:, arm: "none", evidence_source: Reports::NoEvidence.new, grounded: false) }
    end
  end
end
