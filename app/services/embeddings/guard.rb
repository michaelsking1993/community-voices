module Embeddings
  # Catches a model that does not fit the `chunks.embedding` column before
  # anything is written or searched, with a message that says what to do.
  #
  # Two checks:
  # - check_model!   before any work: does the model *say* it makes
  #                  vectors as long as the column? (no model call needed)
  # - check_vectors! after a model call, before saving or searching: did
  #                  it really?
  #
  # Same length is not enough on its own: two different 384-number models
  # still draw different maps. That is what the `embedding_model` stamp on
  # each chunk is for.
  class Guard
    class Mismatch < StandardError; end

    def self.column_dimensions = Chunk.columns_hash.fetch("embedding").limit

    def self.check_model!(model)
      return if model.dimensions == column_dimensions

      raise Mismatch, "#{model.model_id} makes #{model.dimensions}-number vectors, but chunks.embedding holds " \
                      "#{column_dimensions}. Use a #{column_dimensions}-number model, or change the column " \
                      "with a migration and re-embed every chunk."
    end

    def self.check_vectors!(model, vectors)
      bad = vectors.find { _1.size != column_dimensions }
      return unless bad

      raise Mismatch, "#{model.model_id} returned a #{bad.size}-number vector, but chunks.embedding holds " \
                      "#{column_dimensions}. Nothing was saved."
    end
  end
end
