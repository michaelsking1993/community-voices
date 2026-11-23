class Post < ApplicationRecord
  belongs_to :topic

  validates :discourse_id, :post_number, :username, :raw, :posted_at, presence: true

  scope :posted_between, ->(from, to) { where(posted_at: from...to) }

  def url = "#{topic.url}/#{post_number}"
end
