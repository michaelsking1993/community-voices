require "rails_helper"

RSpec.describe Search::Retriever do
  subject(:retriever) { described_class.new(model:) }

  let(:model) { FakeEmbeddingModel.new }
  let(:this_week) { Time.zone.parse("2026-11-16")...Time.zone.parse("2026-11-23") }

  def thread(id, title)
    Topic.create!(discourse_id: id, title:, slug: title.parameterize, category_name: "Anki")
  end

  def add_post(raw, topic:, posted_at: Time.zone.parse("2026-11-20 09:00"))
    create_post(raw:, topic:, posted_at:).tap { |post| Chunking::Chunker.new.call(post) }
  end

  def embed_all = Embeddings::Embedder.new(model:).call

  let(:sync) { thread(1, "Sync keeps failing") }
  let(:fonts) { thread(2, "Card fonts") }

  it "returns the chunks nearest in meaning, closest first" do
    add_post("sync fails with a network error every time I open the app on my phone today", topic: sync)
    add_post("how do I change the font size on the back of my cards in the editor window", topic: fonts)
    embed_all

    result = retriever.call("sync network error phone", max_distance: 1.0)

    expect(result.chunks.first.content).to include("sync fails")
    expect(result.hits.map(&:distance)).to eq(result.hits.map(&:distance).sort)
    expect(result.hits.map(&:rank)).to eq([ 1, 2 ])
  end

  it "can search only some threads" do
    add_post("sync fails with a network error every time I open the app on my phone today", topic: sync)
    add_post("how do I change the font size on the back of my cards in the editor window", topic: fonts)
    embed_all

    result = retriever.call("sync network error phone", max_distance: 1.0, topic_ids: [ fonts.id ])

    expect(result.chunks.map { _1.post.topic }).to eq([ fonts ])
  end

  it "keeps at most per_topic chunks from one thread, so other threads get a slot" do
    4.times { |i| add_post("sync error number #{i} again when syncing the collection with the server today", topic: sync) }
    add_post("sync error on the ipad when syncing the collection with the server after update", topic: fonts)
    embed_all

    result = retriever.call("sync error syncing collection server", per_topic: 2, k: 5, max_distance: 1.0)

    expect(result.chunks.map { _1.post.topic }).to contain_exactly(sync, sync, fonts)
  end

  it "only compares chunks embedded by the same model as the query" do
    add_post("sync fails with a network error every time I open the app on my phone today", topic: sync)
    add_post("how do I change the font size on the back of my cards in the editor window", topic: fonts)
    embed_all
    Chunk.joins(:post).where(posts: { topic_id: fonts.id }).update_all(embedding_model: "another-384-model")

    result = retriever.call("font size cards editor", max_distance: 1.0)

    expect(result.chunks.map { _1.post.topic }).to eq([ sync ])
  end

  it "refuses a model whose vectors do not fit the column, before searching" do
    wrong = FakeEmbeddingModel.new(model_id: "a-768-model", dimensions: 768)

    expect { described_class.new(model: wrong).call("sync") }.to raise_error(Embeddings::Guard::Mismatch)
    expect(wrong.calls).to be_empty
    expect(Retrieval.count).to eq(0)
  end

  it "only looks inside the time window" do
    add_post("sync error when syncing my collection with the server, last month edition", topic: sync, posted_at: Time.zone.parse("2026-10-01"))
    add_post("sync error when syncing my collection with the server, this week edition", topic: sync)
    embed_all

    result = retriever.call("sync error syncing collection", window: this_week, max_distance: 1.0)

    expect(result.chunks.map(&:content)).to all(include("this week edition"))
  end

  it "returns nothing when no chunk is close enough, so the caller can say there is not enough evidence" do
    add_post("how do I change the font size on the back of my cards in the editor window", topic: fonts)
    embed_all

    result = retriever.call("sync network error", max_distance: 0.3)

    expect(result).to be_empty
    expect(result.retrieval.hits_count).to eq(0)
  end

  it "logs the query, its settings and every hit" do
    add_post("sync fails with a network error every time I open the app on my phone today", topic: sync)
    embed_all

    result = retriever.call("sync network error", window: this_week, max_distance: 1.0, purpose: "report")
    retrieval = result.retrieval.reload

    expect(retrieval).to have_attributes(query: "sync network error", purpose: "report", hits_count: 1,
                                         window_start: this_week.begin, k: described_class::K)
    expect(retrieval.hits.map(&:chunk)).to eq(result.chunks)
    expect(RetrievalHit.most_retrieved).to eq(result.chunks.first.id => 1)
  end
end
