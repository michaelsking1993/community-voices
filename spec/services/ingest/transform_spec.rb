require "rails_helper"

RSpec.describe Ingest::Transform do
  it "chunks posts inside the window and embeds them" do
    create_post(raw: words(20), posted_at: 2.days.ago)
    create_post(raw: words(20), posted_at: 30.days.ago)
    create_post(raw: "thanks!", posted_at: 1.day.ago)

    result = described_class.new(embedder: Embeddings::Embedder.new(model: FakeEmbeddingModel.new)).call(since: 7.days.ago)

    expect(result.to_h).to eq(posts: 2, chunks: 1, embedded: 1)
  end
end
