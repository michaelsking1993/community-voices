require "rails_helper"

# The backtest is only honest if a report for week W cannot see week W+1.
RSpec.describe "Backtest: no peeking" do
  let(:model) { FakeEmbeddingModel.new }
  let(:week) { Week.new(start: Date.new(2026, 11, 9)) }
  let(:text) { "my deck vanished after sync and the ankiweb server shows an older copy of my whole collection" }
  let(:llm) do
    FakeLlm.new do |call|
      if call[:schema] == Themes::Finder::SCHEMA
        { themes: [ { cluster: 1, label: "Sync loses decks", summary: "Decks vanish after sync.", kind: "problem" } ] }
      else
        { headline: "h", overview: "o [E1].", sections: [], predictions: [] }
      end
    end
  end

  before do
    stub_const("Search::Retriever::MAX_DISTANCE", 0.95)
    [ [ 1, "2026-11-10 10:00", "" ], [ 2, "2026-11-11 10:00", " today" ], [ 3, "2026-11-17 10:00", " FUTURE-MARKER" ] ].each do |id, at, extra|
      topic = Topic.create!(discourse_id: id, title: "Sync #{id}", slug: "sync-#{id}", category_name: "Anki › Syncing")
      Chunking::Chunker.new.call(create_post(raw: "#{text}#{extra}", topic:, posted_at: Time.zone.parse(at)))
    end
    Embeddings::Embedder.new(model:).call
  end

  it "never shows the writer a post from the week it predicts" do
    builder = Reports::Builder.new(llm:, evidence_source: Reports::RagEvidence.new(retriever: Search::Retriever.new(model:)),
                                   theme_finder: Themes::Finder.new(llm:, k: 1))
    report = builder.call(week)

    expect(llm.calls.map { _1[:prompt] }.join).not_to include("FUTURE-MARKER")
    expect(report.evidence.values.map { _1["text"] }.join).not_to include("FUTURE-MARKER")
  end
end
