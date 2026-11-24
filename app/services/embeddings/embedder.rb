module Embeddings
  # Fills in embeddings for chunks that do not have one yet, or whose
  # embedding came from a different model. The Chunker clears a chunk's
  # embedding when its text changes, so this only ever embeds new or
  # changed text, plus everything once after the model is switched.
  #
  # Each chunk is stamped with the model that embedded it, and lengths are
  # checked before anything is saved (Embeddings::Guard).
  #
  # The model is injected: specs pass a fake, production uses LocalModel.
  class Embedder
    BATCH_SIZE = 64

    def initialize(model: LocalModel.instance)
      @model = model
    end

    def call(scope = Chunk.needs_embedding(@model.model_id))
      Guard.check_model!(@model)
      count = 0
      scope.in_batches(of: BATCH_SIZE) do |batch|
        chunks = batch.to_a
        vectors = @model.embed(chunks.map(&:content))
        Guard.check_vectors!(@model, vectors)
        Chunk.transaction do
          chunks.zip(vectors) do |chunk, vector|
            chunk.update_columns(embedding: vector, embedding_model: @model.model_id, updated_at: Time.current)
          end
        end
        count += chunks.size
      end
      count
    end
  end
end
