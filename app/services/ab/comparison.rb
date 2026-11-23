module Ab
  # The numbers behind the A/B charts: for each arm, averages over the
  # weeks that have a report for every arm.
  class Comparison
    Row = Data.define(:arm, :weeks, :input_tokens, :output_tokens, :cost_usd, :seconds, :citations_valid, :quotes_verbatim,
                      :sentences_uncited, :support_rate, :scores, :wins)

    def initialize(arms: Run::ARMS) = @arms = arms

    def weeks
      @weeks ||= Report.done.where(arm: @arms).group(:week_start).having("count(distinct arm) = ?", @arms.size)
                       .pluck(:week_start).sort
    end

    def rows = @arms.map { row(_1) }

    private

    def row(arm)
      reports = Report.done.where(arm:, week_start: weeks).latest_first.to_a.uniq(&:week_start)
      supports = Judgement.of_kind("support").where(report: reports)
      rankings = Judgement.of_kind("ranking").where(week_start: weeks)
      Row.new(arm:, weeks: reports.size, input_tokens: avg(reports.map(&:input_tokens)), output_tokens: avg(reports.map(&:output_tokens)),
              cost_usd: avg(reports.map { _1.cost_usd&.to_f }, 3), seconds: avg(reports.map { _1.duration_ms.to_i / 1000.0 }, 1),
              citations_valid: share(reports, "citations_valid", "citations"), quotes_verbatim: share(reports, "quotes_verbatim", "quotes"),
              sentences_uncited: share(reports, "sentences_uncited", "sentences"),
              support_rate: avg(supports.filter_map { _1.data["support_rate"] }, 2),
              scores: Ranker::DIMENSIONS.to_h { |d| [ d, avg(rankings.filter_map { _1.data.dig("scores", arm, d) }, 1) ] },
              wins: rankings.count { _1.data["ranking"]&.first == arm })
    end

    def avg(values, digits = 0)
      list = values.compact
      list.empty? ? nil : (list.sum.to_f / list.size).round(digits).then { digits.zero? ? _1.to_i : _1 }
    end

    # Pooled over weeks: total checks passed / total checks made (nil if none were made).
    def share(reports, good, total)
      made = reports.sum { _1.grounding[total].to_i }
      made.zero? ? nil : (reports.sum { _1.grounding[good].to_i }.to_f / made).round(2)
    end
  end
end
