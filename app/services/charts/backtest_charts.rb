module Charts
  # The backtest as figures: is "high confidence" really more reliable
  # than "low", which kinds of prediction hold up, and how each week did.
  class BacktestCharts
    def call
      judgements = Judgement.of_kind("prediction").order(:week_start).to_a
      return [] if judgements.empty?

      summary = Backtest::Summary.new(judgements)
      [ hit_rate("backtest-confidence", "Is high confidence more reliable?", summary.by_confidence,
                 "Share of predictions that came true (a partial hit counts half). If \"high\" is not above \"low\", the stated confidence means little."),
        hit_rate("backtest-basis", "Which predictions hold up?", summary.by_basis,
                 "By what the prediction rested on: the weekly trend counts, a topic that recurs, or a known release or beta."),
        by_week(judgements) ]
    end

    private

    def hit_rate(id, title, rows, caption)
      trace = { type: "bar", x: rows.map(&:label), y: rows.map { _1.hit_rate && (_1.hit_rate * 100) },
                text: rows.map { "#{_1.hit_rate ? "#{(_1.hit_rate * 100).round}%" : "n/a"} of #{_1.scored}" },
                textposition: "outside", marker: { color: Palette::ARM_COLORS["rag"] }, showlegend: false }
      Chart.build(id:, title:, caption:, traces: [ trace ], layout: { yaxis: { title: "% that came true", range: [ 0, 110 ] } })
    end

    def by_week(judgements)
      weeks = judgements.map { _1.data["scored_week"] }
      traces = Backtest::Scorer::VERDICTS.map do |verdict|
        { type: "bar", name: verdict.humanize, x: weeks,
          y: judgements.map { |j| j.data["results"].count { _1["verdict"] == verdict } }, marker: { color: Palette::VERDICT_COLORS[verdict] } }
      end
      Chart.build(id: "backtest-weeks", title: "Verdicts, week by week",
                  caption: "Each bar is one week's predictions, scored against the week they were about (labelled by that week's first day).",
                  traces:, layout: { barmode: "stack", xaxis: { type: "category" }, yaxis: { title: "predictions" } })
    end
  end
end
