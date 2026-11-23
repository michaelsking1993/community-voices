class Chunk < ApplicationRecord
  belongs_to :post
  has_neighbors :embedding, dimensions: Embeddings::LocalModel::DIMENSIONS

  scope :pending_embedding, -> { where(embedding: nil) }

  # Nearest chunks to a piece of text, by cosine distance. A console
  # helper for spot checks; the real retriever arrives in step 5.
  def self.similar_to(text, limit: 5, model: Embeddings::LocalModel.instance)
    where.not(embedding: nil)
         .nearest_neighbors(:embedding, model.embed([ text ]).first, distance: "cosine")
         .includes(post: :topic)
         .first(limit)
  end
end
