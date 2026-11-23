# Stands in for the real model in specs: deterministic, instant, offline.
# Each text becomes a unit vector seeded from its words, so identical
# texts get identical vectors and texts sharing words land close together.
class FakeEmbeddingModel
  attr_reader :calls

  def initialize = @calls = []

  def embed(texts)
    @calls << texts
    texts.map { |text| vector_for(text) }
  end

  private

  def vector_for(text)
    v = Array.new(Embeddings::LocalModel::DIMENSIONS, 0.0)
    text.downcase.scan(/\w+/).each { |word| v[Zlib.crc32(word) % v.size] += 1.0 }
    norm = Math.sqrt(v.sum { _1 * _1 })
    norm.zero? ? v.tap { _1[0] = 1.0 } : v.map { _1 / norm }
  end
end
