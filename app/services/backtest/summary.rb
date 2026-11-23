module Backtest
  # Turns prediction judgements into hit rates: overall, by the confidence
  # the report claimed, and by the basis it gave. "no_evidence" verdicts
  # are counted separately and left out of the rate.
  #
  # If "high" confidence does not score better than "low", the report's
  # confidence is not worth reading: that is the point of the chart.
  class Summary
    Row = Data.define(:label, :scored, :hit_rate, :happened, :partly, :did_not_happen, :no_evidence)

    def initialize(judgements) = @results = judgements.flat_map { _1.data.fetch("results", []) }

    def overall = row("all", @results)
    def by_confidence = group("confidence", %w[low medium high])
    def by_basis = group("basis", %w[trend recurring event])

    private

    def group(key, order)
      order.map { |value| row(value, @results.select { _1[key] == value }) }.reject { _1.scored.zero? && _1.no_evidence.zero? }
    end

    def row(label, results)
      counts = Scorer::VERDICTS.index_with { |verdict| results.count { _1["verdict"] == verdict } }
      scored = counts.values_at("happened", "partly", "did_not_happen").sum
      points = counts["happened"] + (0.5 * counts["partly"])
      Row.new(label:, scored:, hit_rate: scored.zero? ? nil : (points / scored).round(2),
              happened: counts["happened"], partly: counts["partly"], did_not_happen: counts["did_not_happen"],
              no_evidence: counts["no_evidence"])
    end
  end
end
