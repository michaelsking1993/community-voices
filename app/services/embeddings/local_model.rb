module Embeddings
  # all-MiniLM-L6-v2 running locally through ONNX (the informers gem).
  # No API key, no per-call cost. The first call downloads ~90 MB to
  # ~/.cache/informers; after that it works offline.
  #
  # Returns unit-length vectors, so cosine distance and dot product agree.
  class LocalModel
    MODEL_ID = "Xenova/all-MiniLM-L6-v2".freeze
    DIMENSIONS = 384

    def self.instance = @instance ||= new

    def embed(texts)
      pipeline.(texts)
    end

    private

    def pipeline
      @pipeline ||= Informers.pipeline("embedding", MODEL_ID)
    end
  end
end
