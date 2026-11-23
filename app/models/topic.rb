class Topic < ApplicationRecord
  has_many :posts, dependent: :destroy

  validates :discourse_id, :title, :slug, presence: true

  def url(base = Discourse::Client::BASE_URL) = "#{base}/t/#{slug}/#{discourse_id}"
end
