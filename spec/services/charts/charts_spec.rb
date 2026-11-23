require "rails_helper"

RSpec.describe "Chart data" do
  let(:week) { Date.new(2026, 11, 16) }

  def judgement(kind, **attrs) = Judgement.create!(kind:, week_start: week, **attrs)

  describe Charts::BacktestCharts do
    it "is empty without a backtest" do
      expect(described_class.new.call).to eq([])
    end

    it "draws hit rate by confidence and verdicts by week" do
      judgement("prediction", data: { "scored_week" => "2026-11-16", "results" => [
        { "verdict" => "happened", "confidence" => "high", "basis" => "trend" },
        { "verdict" => "did_not_happen", "confidence" => "low", "basis" => "event" } ] })
      confidence, _basis, weeks = described_class.new.call

      expect(confidence.traces.first).to include(x: %w[low high], y: [ 0.0, 100.0 ])
      expect(weeks.traces.find { _1[:name] == "Happened" }).to include(x: [ "2026-11-16" ], y: [ 1 ])
    end
  end

  describe Charts::AbCharts do
    it "is empty until every arm has a report for a week" do
      Report.create!(week_start: week, arm: "rag", status: "done")
      expect(described_class.new.call).to eq([])
    end

    it "draws checks, cost and judge scores per arm" do
      Ab::Run::ARMS.each do |arm|
        Report.create!(week_start: week, arm:, status: "done", cost_usd: 0.1, input_tokens: 1000, duration_ms: 2000,
                       grounding: { "citations" => 2, "citations_valid" => 2, "sentences" => 4, "sentences_uncited" => 1 })
      end
      checks, cost, judge = described_class.new.call

      expect(checks.traces.map { _1[:name] }).to eq([ "RAG", "Paste the whole week", "No context" ])
      expect(checks.traces.first[:y]).to eq([ 100.0, nil, 75.0, nil ])
      expect(cost.traces.first[:text]).to eq([ "$0.1  ·  1,000 tokens in  ·  2.0s" ])
      expect(judge.title).to include("blind judge")
    end
  end

  describe Charts::RetrievalCharts do
    it "counts how often each chunk was retrieved and bins the distances" do
      Chunking::Chunker.new.call(create_post(raw: words(30)))
      chunk = Chunk.first
      retrieval = Retrieval.create!(query: "q", purpose: "report", k: 8, per_topic: 2, max_distance: 0.6, candidates_count: 5, hits_count: 1, duration_ms: 12)
      RetrievalHit.create!(retrieval:, chunk:, rank: 1, distance: 0.31)
      top, distances = described_class.new.call

      expect(top.traces.first[:x]).to eq([ 1 ])
      expect(distances.traces.first[:x]).to eq([ 0.3 ])
      expect(described_class.new.purposes).to eq([ { purpose: "report", searches: 1, empty: 0, ms: 12, hits: 1.0 } ])
    end
  end

  describe Charts::EmbeddingMap do
    it "places each thread once and colours by category" do
      model = FakeEmbeddingModel.new
      4.times do |i|
        topic = Topic.create!(discourse_id: i + 1, title: "Thread #{i}", slug: "t#{i}", category_name: i.even? ? "Anki › Syncing" : "AnkiMobile › Help")
        Chunking::Chunker.new.call(create_post(raw: "#{words(20, "alpha#{i}")}", topic:, posted_at: Time.zone.parse("2026-11-10 10:00")))
      end
      Embeddings::Embedder.new(model:).call
      figure, = described_class.new.call(weeks: 4)

      expect(figure.traces.sum { _1[:x].size }).to eq(4)
      expect(figure.traces.map { _1[:name] }).to contain_exactly("Anki", "AnkiMobile")
    end
  end
end
