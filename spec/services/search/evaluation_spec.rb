require "rails_helper"

RSpec.describe Search::Evaluation do
  subject(:evaluation) { described_class.new(retriever: Search::Retriever.new(model:), k: 3) }

  let(:model) { FakeEmbeddingModel.new }
  let(:long_thread) { Topic.create!(discourse_id: 10, title: "Sync thread", slug: "sync-thread") }
  let(:other_thread) { Topic.create!(discourse_id: 20, title: "Another sync thread", slug: "another-sync-thread") }

  before do
    4.times { |i| Chunking::Chunker.new.call(create_post(raw: "sync error #{i} again when syncing my whole collection with the server today", topic: long_thread)) }
    Chunking::Chunker.new.call(create_post(raw: "sync error on the ipad when syncing a collection with the server after update", topic: other_thread))
    Embeddings::Embedder.new(model:).call
    stub_const("Search::Retriever::MAX_DISTANCE", 1.0)
  end

  let(:cases) { [ described_class::Case.new(query: "sync error syncing collection server", relevant: [ 10, 20 ]) ] }

  it "shows the per-thread cap finding more of the relevant threads" do
    rows = evaluation.call(cases).index_by(&:config)

    expect(rows["plain top-k"]).to have_attributes(hit: true, recall: 0.5, threads: 1)
    expect(rows["max 2 per thread"]).to have_attributes(hit: true, recall: 1.0, threads: 2)
  end

  it "skips queries whose threads are not loaded instead of counting them as misses" do
    missing = described_class::Case.new(query: "anything", relevant: [ 999 ])

    expect(evaluation.call([ missing ])).to be_empty
  end

  it "summarizes each configuration" do
    summary = evaluation.summarize(evaluation.call(cases)).index_by(&:config)

    expect(summary["max 2 per thread"]).to have_attributes(queries: 1, hit_rate: 1.0, recall: 1.0, threads: 2.0)
  end

  it "counts off-topic queries that correctly return nothing" do
    stub_const("Search::Retriever::MAX_DISTANCE", 0.5)

    expect(evaluation.off_topic_empty_rate([ "chocolate cake recipe", "sync error syncing collection server" ])).to eq(0.5)
  end

  it "loads the committed query set" do
    expect(described_class.cases).to all(have_attributes(query: a_kind_of(String), relevant: all(a_kind_of(Integer))))
    expect(described_class.off_topic).to all(a_kind_of(String))
  end
end
