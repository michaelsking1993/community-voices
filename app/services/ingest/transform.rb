module Ingest
  # The "T" in ETL: chunk the posts in a window, then embed whatever is new.
  class Transform
    Result = Data.define(:posts, :chunks, :embedded)

    def initialize(chunker: Chunking::Chunker.new, embedder: Embeddings::Embedder.new)
      @chunker = chunker
      @embedder = embedder
    end

    def call(since:)
      posts = Post.where(posted_at: since..).includes(:topic, :chunks)
      chunks = posts.sum { |post| @chunker.call(post) }
      Result.new(posts: posts.size, chunks:, embedded: @embedder.call)
    end
  end
end
