require "rails_helper"

RSpec.describe Chunk do
  describe ".similar_to" do
    it "returns the nearest chunks by cosine distance, closest first" do
      model = FakeEmbeddingModel.new
      Chunking::Chunker.new.call(create_post(raw: "sync fails with a network error every time I open the app on my phone"))
      Chunking::Chunker.new.call(create_post(raw: "how do I change the font size on the back of my cards in the editor"))
      Embeddings::Embedder.new(model:).call

      results = described_class.similar_to("sync network error", limit: 2, model:)

      expect(results.first.content).to include("sync fails")
      expect(results.first.neighbor_distance).to be < results.last.neighbor_distance
    end
  end
end
