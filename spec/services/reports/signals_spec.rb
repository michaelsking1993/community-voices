require "rails_helper"

RSpec.describe Reports::Signals do
  let(:model) { FakeEmbeddingModel.new }
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:text) { "the toolbar disappeared from the review screen on my iphone after the latest app update" }

  def add(id, title, raw, posted_at, category: "AnkiMobile › Help")
    topic = Topic.find_or_create_by!(discourse_id: id) { |t| t.assign_attributes(title:, slug: title.parameterize, category_name: category) }
    Chunking::Chunker.new.call(create_post(raw:, topic:, posted_at:))
  end

  before do
    add(1, "Toolbar gone", text, Time.zone.parse("2026-11-18"))
    add(1, "Toolbar gone", "#{text} as well", Time.zone.parse("2026-11-19"))
    add(2, "Toolbar missing", text, Time.zone.parse("2026-11-09 03:00"))
    add(3, "Anki 26.11 Beta 1", "please test the new beta build and report any problems you find with the editor", Time.zone.parse("2026-11-17"), category: "Anki › Beta Testing")
    add(4, "Anki 26.12 Beta 1", "a future beta that must not leak into a report for the week of the sixteenth of november", Time.zone.parse("2026-11-25"), category: "Anki › Beta Testing")
    Embeddings::Embedder.new(model:).call
  end

  let(:theme) do
    centroid = Themes::KMeans.normalize(model.embed([ Chunk.first.content ]).first)
    Theme.create!(week_start: week.start, position: 1, label: "Toolbar gone", summary: "s", kind: "problem", centroid:,
                  topic_count: 1, post_count: 2, author_count: 2)
  end

  it "counts posts close to each theme per week, oldest first, ending with the report's week" do
    stub_const("#{described_class}::TREND_DISTANCE", 0.2)

    expect(described_class.new.trend_line(week, theme)).to eq("Theme 1 (Toolbar gone): 1, 2")
  end

  it "leaves out weeks before the data starts instead of showing them as zeros" do
    stub_const("#{described_class}::TREND_DISTANCE", 0.2)
    coverage = Ingest::Coverage.new(oldest_post_at: Time.zone.parse("2026-10-19 01:00"))

    expect(described_class.new(coverage:).trend_line(week, theme)).to eq("Theme 1 (Toolbar gone): 0, 0, 0, 1, 2")
  end

  it "adds recent beta and release threads to the evidence, and nothing from after the week" do
    evidence = described_class.new.call(week, [ theme ], Reports::Evidence.new)

    expect(evidence.for_theme(0).map(&:title)).to eq([ "Anki 26.11 Beta 1" ])
    expect(evidence.signals.first).to start_with("Theme 1 (Toolbar gone):")
  end
end
