# One logged search: the query, its settings, and the chunks it returned.
class Retrieval < ApplicationRecord
  has_many :hits, -> { order(:rank) }, class_name: "RetrievalHit", dependent: :delete_all
end
