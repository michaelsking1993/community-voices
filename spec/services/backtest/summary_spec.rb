require "rails_helper"

RSpec.describe Backtest::Summary do
  def judgement(*results) = Judgement.new(kind: "prediction", week_start: Date.new(2026, 11, 9), data: { "results" => results })

  def result(verdict, confidence, basis = "trend") = { "verdict" => verdict, "confidence" => confidence, "basis" => basis }

  let(:summary) do
    described_class.new([ judgement(result("happened", "high"), result("did_not_happen", "high"), result("no_evidence", "high")),
                          judgement(result("partly", "low", "event"), result("did_not_happen", "low", "event")) ])
  end

  it "scores happened as 1, partly as 0.5 and ignores no_evidence" do
    expect(summary.overall).to have_attributes(scored: 4, hit_rate: 0.38, no_evidence: 1) # 1.5 / 4
  end

  it "breaks the rate down by confidence and by basis, in a fixed order" do
    expect(summary.by_confidence.map(&:label)).to eq(%w[low high])
    expect(summary.by_confidence.map(&:hit_rate)).to eq([ 0.25, 0.5 ])
    expect(summary.by_basis.map { [ _1.label, _1.scored ] }).to eq([ [ "trend", 2 ], [ "event", 2 ] ])
  end
end
