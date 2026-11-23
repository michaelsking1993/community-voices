require "rails_helper"

RSpec.describe Embeddings::Embedder do
  let(:model) { FakeEmbeddingModel.new }

  before do
    Chunking::Chunker.new.call(create_post(raw: words(20, "sync")))
    Chunking::Chunker.new.call(create_post(raw: words(20, "font")))
  end

  it "embeds every chunk that has no embedding yet" do
    expect(described_class.new(model:).call).to eq(2)
    expect(Chunk.pending_embedding).to be_empty
    expect(Chunk.first.embedding.size).to eq(384)
  end

  it "does not re-embed chunks that already have one" do
    described_class.new(model:).call
    expect(described_class.new(model:).call).to eq(0)
    expect(model.calls.size).to eq(1)
  end
end
