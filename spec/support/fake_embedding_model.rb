# Stands in for the real model in specs: deterministic, instant, offline.
# Each text becomes a unit vector seeded from its words, so identical
# texts get identical vectors and texts sharing words land close together.
class FakeEmbeddingModel
  attr_reader :calls, :model_id, :dimensions

  def initialize(model_id: "fake-embedding-model", dimensions: Embeddings::LocalModel::DIMENSIONS, returns: nil)
    @calls = []
    @model_id = model_id
    @dimensions = dimensions
    @returns = returns # vector length to actually return, to fake a model that lies about its size
  end

  def embed(texts)
    @calls << texts
    texts.map { |text| vector_for(text) }
  end

  private

  def vector_for(text)
    v = Array.new(@returns || dimensions, 0.0)
    text.downcase.scan(/\w+/).each { |word| v[Zlib.crc32(word) % v.size] += 1.0 }
    norm = Math.sqrt(v.sum { _1 * _1 })
    norm.zero? ? v.tap { _1[0] = 1.0 } : v.map { _1 / norm }
  end
end
