require "rails_helper"

RSpec.describe Ab::Comparison do
  let(:week) { Date.new(2026, 11, 16) }

  def report(arm, grounding:, tokens:, cost:)
    Report.create!(week_start: week, arm:, status: "done", grounding:, input_tokens: tokens, output_tokens: 100, cost_usd: cost, duration_ms: 4000)
  end

  before do
    rag = report("rag", grounding: { "citations" => 10, "citations_valid" => 10, "quotes" => 4, "quotes_verbatim" => 3, "sentences" => 20, "sentences_uncited" => 2 }, tokens: 8000, cost: 0.13)
    paste = report("paste_all", grounding: { "citations" => 10, "citations_valid" => 9, "quotes" => 0, "quotes_verbatim" => 0, "sentences" => 20, "sentences_uncited" => 4 }, tokens: 60_000, cost: 0.3)
    none = report("none", grounding: { "citations" => 0, "citations_valid" => 0, "quotes" => 0, "quotes_verbatim" => 0, "sentences" => 10, "sentences_uncited" => 10 }, tokens: 300, cost: 0.01)
    Judgement.create!(kind: "support", week_start: week, report: rag, data: { "support_rate" => 0.9 })
    Judgement.create!(kind: "ranking", week_start: week,
                      data: { "ranking" => %w[rag paste_all none], "scores" => { "rag" => { "coverage" => 4 }, "none" => { "coverage" => 1 } } })
    Report.create!(week_start: Date.new(2026, 11, 9), arm: "rag", status: "done") # no other arms that week: left out
    [ paste, none ]
  end

  it "uses only weeks that have a report for every arm" do
    expect(described_class.new.weeks).to eq([ week ])
  end

  it "averages cost and tokens, pools the checks and counts judge wins per arm" do
    rows = described_class.new.rows.index_by(&:arm)

    expect(rows["rag"]).to have_attributes(input_tokens: 8000, cost_usd: 0.13, seconds: 4.0, citations_valid: 1.0,
                                           quotes_verbatim: 0.75, sentences_uncited: 0.1, support_rate: 0.9, wins: 1)
    expect(rows["rag"].scores["coverage"]).to eq(4.0)
    expect(rows["paste_all"]).to have_attributes(input_tokens: 60_000, citations_valid: 0.9, quotes_verbatim: nil, support_rate: nil, wins: 0)
    expect(rows["none"]).to have_attributes(citations_valid: nil, sentences_uncited: 1.0)
  end
end
