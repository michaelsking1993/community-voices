require "rails_helper"

RSpec.describe Backtest::Scorer do
  let(:model) { FakeEmbeddingModel.new }
  let(:week) { Week.new(start: Date.new(2026, 11, 9)) } # the report's week; predictions are about 11-16
  let(:toolbar) { "the toolbar disappeared from the review screen on my iphone after the latest app update" }
  let(:report) do
    Report.create!(week_start: week.start, status: "done", content: { "predictions" => [
      { "claim" => "Toolbar threads continue", "reasoning" => "r", "basis" => "trend", "confidence" => "high", "theme" => 1 },
      { "claim" => "Nothing about tax", "reasoning" => "r", "basis" => "recurring", "confidence" => "low", "theme" => 0 }
    ] })
  end

  def add(raw, posted_at)
    Chunking::Chunker.new.call(create_post(raw:, posted_at: Time.zone.parse(posted_at)))
  end

  before do
    stub_const("Search::Retriever::MAX_DISTANCE", 0.95)
    add(toolbar, "2026-11-17 10:00")
    add("#{toolbar} and it is still gone", "2026-11-18 10:00")
    add("posts from the report's own week must not be offered as proof #{toolbar}", "2026-11-10 10:00")
    Embeddings::Embedder.new(model:).call
  end

  let(:llm) do
    FakeLlm.new(results: [
      { prediction: 1, verdict: "happened", rationale: "Still discussed.", evidence: %w[E1 E99] },
      { prediction: 2, verdict: "partly", rationale: "Guess.", evidence: [] },
      { prediction: 7, verdict: "happened", rationale: "Not a prediction.", evidence: %w[E1] }
    ])
  end

  subject(:judgement) { described_class.new(llm:, retriever: Search::Retriever.new(model:)).call(report) }

  it "judges each prediction against the following week only" do
    judgement
    prompt = llm.calls.last[:prompt]

    expect(prompt).to include("week 2026-11-16 to 2026-11-22", "Prediction 1: Toolbar threads continue", "disappeared from the review screen")
    expect(prompt).not_to include("report's own week")
  end

  it "keeps only real citations, demotes uncited verdicts and drops unknown predictions" do
    results = judgement.data["results"]

    expect(judgement).to have_attributes(kind: "prediction", report:, week_start: week.start)
    expect(results.size).to eq(2)
    expect(results.first).to include("verdict" => "happened", "evidence" => [ "E1" ], "confidence" => "high")
    expect(results.first["urls"]["E1"]).to start_with("https://forums.ankiweb.net/t/")
    expect(results.last).to include("verdict" => "no_evidence", "basis" => "recurring")
  end

  it "refuses a report with no predictions" do
    report.update!(content: {})
    expect { judgement }.to raise_error(ArgumentError, /no predictions/)
  end
end
