require "rails_helper"

RSpec.describe Reports::RagEvidence do
  let(:model) { FakeEmbeddingModel.new }
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:signals) { instance_double(Reports::Signals, call: nil) }
  let(:evidence_source) { described_class.new(retriever: Search::Retriever.new(model:), signals:) }

  def theme_with(topic_counts, position: 1)
    Theme.create!(week_start: week.start, position:, label: "Sync errors", summary: "sync fails with an error",
                  kind: "problem", centroid: [ 1.0 ] + [ 0.0 ] * 383, topic_count: topic_counts.size, post_count: 1, author_count: 1,
                  theme_topics: topic_counts.map { |topic, posts| ThemeTopic.new(topic:, similarity: 0.5, post_count: posts) })
  end

  def thread(id, raw, posts: 1)
    topic = Topic.create!(discourse_id: id, title: "Thread #{id}", slug: "t-#{id}", category_name: "Anki")
    posts.times { |i| Chunking::Chunker.new.call(create_post(raw: "#{raw} #{i}", topic:, posted_at: Time.zone.parse("2026-11-18 10:00"))) }
    topic
  end

  before { stub_const("Search::Retriever::MAX_DISTANCE", 0.95) }

  it "gives a theme's busiest thread a chunk even when it is far from the theme's centre" do
    close = thread(1, "sync fails with an error sync fails with an error every time i open it")
    busy = thread(2, "the add note screen lost its save and cancel buttons on the ipad after the update", posts: 5)
    Embeddings::Embedder.new(model:).call
    stub_const("#{described_class}::THIS_WEEK", 1..1)

    evidence = Reports::Evidence.new
    allow(signals).to receive(:call) { |_, _, e| evidence = e }
    evidence_source.call(week, [ theme_with({ close => 1, busy => 5 }) ])

    expect(evidence.for_theme(1).map(&:title)).to eq([ "Thread 1", "Thread 2" ])
    expect(Retrieval.pluck(:purpose)).to include("report_busiest")
  end

  it "shares the chunk budget by each theme's share of the threads" do
    expect(evidence_source.budget(instance_double(Theme, topic_count: 33), 96)).to eq(12)
    expect(evidence_source.budget(instance_double(Theme, topic_count: 17), 96)).to eq(6)
    expect(evidence_source.budget(instance_double(Theme, topic_count: 2), 96)).to eq(3)
  end
end
