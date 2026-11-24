# One message in a forum thread. "Post" is Discourse's name for any
# message, and we kept it to match the forum's API (/posts.json).
#
# Discourse has no separate "comment": the opening message is post 1 of
# its topic, and every reply is another post (2, 3, ...). `post_number` is
# that position, `reply_to_post_number` the post it answers, if any, and
# `discourse_id` the forum's own post id, the upsert key.
class Post < ApplicationRecord
  belongs_to :topic
  has_many :chunks, dependent: :destroy

  validates :discourse_id, :post_number, :username, :raw, :posted_at, presence: true

  scope :posted_between, ->(from, to) { where(posted_at: from...to) }

  def url = "#{topic.url}/#{post_number}"
end
