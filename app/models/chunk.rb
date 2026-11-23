class Chunk < ApplicationRecord
  belongs_to :post
  has_neighbors :embedding, dimensions: Embeddings::LocalModel::DIMENSIONS

  scope :pending_embedding, -> { where(embedding: nil) }

  # HNSW keeps only `hnsw.ef_search` candidates (default 40) and applies
  # WHERE clauses and row visibility after that. A date filter, or many
  # deleted rows still in the index, can then leave fewer results than
  # asked for. This raises the limit for one transaction.
  def self.with_ef_search(value = 200)
    transaction do
      connection.execute("SET LOCAL hnsw.ef_search = #{Integer(value)}")
      yield
    end
  end

  # Nearest chunks to a piece of text, by cosine distance, with no
  # filtering. A console helper for spot checks; the app retrieves through
  # Search::Retriever (window, cut-off, max 2 per thread, logging).
  def self.similar_to(text, limit: 5, model: Embeddings::LocalModel.instance)
    vector = model.embed([ text ]).first
    with_ef_search do
      where.not(embedding: nil).nearest_neighbors(:embedding, vector, distance: "cosine")
                               .includes(post: :topic).first(limit)
    end
  end
end
