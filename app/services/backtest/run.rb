module Backtest
  # The backtest: for each past week whose following week is complete,
  # make sure a RAG report exists for it (written from data before the
  # following week, by construction), then score its predictions.
  #
  # Reports and judgements already stored are reused, so a re-run only
  # pays for what is new.
  class Run
    def initialize(builder: Reports::Builder.new, scorer: Scorer.new, today: Time.zone.today)
      @builder = builder
      @scorer = scorer
      @today = today
    end

    # The `count` most recent weeks that can be scored.
    def weeks(count) = Array.new(count) { |i| Week.last_complete(@today).previous(i + 1) }.reverse

    def call(weeks)
      weeks.filter_map do |week|
        report = report_for(week)
        next if report.predictions.empty?

        Judgement.find_by(kind: "prediction", report:) || @scorer.call(report)
      end
    end

    private

    def report_for(week)
      Report.done.where(week_start: week.start, arm: "rag").latest_first.first || @builder.call(week)
    end
  end
end
