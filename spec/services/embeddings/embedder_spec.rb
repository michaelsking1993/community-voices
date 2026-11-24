require "rails_helper"

RSpec.describe Embeddings::Embedder do
  let(:model) { FakeEmbeddingModel.new }

  before do
    Chunking::Chunker.new.call(create_post(raw: words(20, "sync")))
    Chunking::Chunker.new.call(create_post(raw: words(20, "font")))
  end

  it "embeds every chunk that has no embedding yet" do
    expect(described_class.new(model:).call).to eq(2)
    expect(Chunk.needs_embedding(model.model_id)).to be_empty
    expect(Chunk.first.embedding.size).to eq(384)
  end

  it "does not re-embed chunks that already have one" do
    described_class.new(model:).call
    expect(described_class.new(model:).call).to eq(0)
    expect(model.calls.size).to eq(1)
  end

  it "stamps each chunk with the model that embedded it" do
    described_class.new(model:).call

    expect(Chunk.pluck(:embedding_model)).to all(eq("fake-embedding-model"))
  end

  it "re-embeds everything once the model changes, since old vectors are on a different map" do
    described_class.new(model:).call
    other = FakeEmbeddingModel.new(model_id: "another-384-model")

    expect(described_class.new(model: other).call).to eq(2)
    expect(Chunk.pluck(:embedding_model)).to all(eq("another-384-model"))
  end

  it "stops before calling the model when the model's length does not fit the column" do
    wrong = FakeEmbeddingModel.new(model_id: "a-1536-model", dimensions: 1536)

    expect { described_class.new(model: wrong).call }
      .to raise_error(Embeddings::Guard::Mismatch, /a-1536-model makes 1536-number vectors, but chunks.embedding holds 384/)
    expect(wrong.calls).to be_empty
  end

  it "saves nothing when the model returns vectors of the wrong length" do
    liar = FakeEmbeddingModel.new(model_id: "liar", returns: 512)

    expect { described_class.new(model: liar).call }
      .to raise_error(Embeddings::Guard::Mismatch, /returned a 512-number vector/)
    expect(Chunk.where.not(embedding: nil)).to be_empty
  end
end
