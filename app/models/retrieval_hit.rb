# One chunk returned by a Retrieval, at a rank, with its cosine distance.
class RetrievalHit < ApplicationRecord
  belongs_to :retrieval
  belongs_to :chunk

  # The chunks retrieved most often, for the stats page.
  def self.most_retrieved(limit = 10)
    group(:chunk_id).order(Arel.sql("count(*) DESC")).limit(limit).count
  end
end
