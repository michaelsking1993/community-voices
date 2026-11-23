module Embeddings
  # Fills in embeddings for chunks that do not have one yet. The Chunker
  # clears a chunk's embedding when its text changes, so this only ever
  # embeds new or changed text.
  #
  # The model is injected: specs pass a fake, production uses LocalModel.
  class Embedder
    BATCH_SIZE = 64

    def initialize(model: LocalModel.instance)
      @model = model
    end

    def call(scope = Chunk.pending_embedding)
      count = 0
      scope.in_batches(of: BATCH_SIZE) do |batch|
        chunks = batch.to_a
        vectors = @model.embed(chunks.map(&:content))
        Chunk.transaction do
          chunks.zip(vectors) { |chunk, vector| chunk.update_columns(embedding: vector, updated_at: Time.current) }
        end
        count += chunks.size
      end
      count
    end
  end
end
