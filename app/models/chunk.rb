class Chunk < ApplicationRecord
  belongs_to :post
  has_neighbors :embedding, dimensions: Embeddings::LocalModel::DIMENSIONS

  # Chunks to (re-)embed with `model_id`: never embedded, or embedded by a
  # different model, whose vectors cannot be compared with this one's.
  scope :needs_embedding, ->(model_id) {
    where(embedding: nil).or(where(embedding_model: nil)).or(where.not(embedding_model: model_id))
  }

  # Chunks whose vectors can be compared with `model_id`'s.
  scope :embedded_by, ->(model_id) { where.not(embedding: nil).where(embedding_model: model_id) }

  # HNSW keeps only `hnsw.ef_search` candidates (default 40) and applies
  # WHERE clauses and row visibility after that. A date filter, or many
  # deleted rows still in the index, can then leave fewer results than
  # asked for. This raises the limit for one transaction (`true` = local).
  def self.with_ef_search(value = 200)
    transaction do
      connection.select_value(sanitize_sql_array([ "SELECT set_config('hnsw.ef_search', ?, true)", Integer(value).to_s ]))
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
