# A forum thread. "Topic" is Discourse's name for a thread, and we kept it
# so the table maps one to one onto the forum's API: forums.ankiweb.net
# runs Discourse, and its URLs are /t/<slug>/<id>, where "t" is for topic.
#
# A topic has a title, a slug and a category, and holds many posts.
# `discourse_id` is the forum's own topic id, the upsert key.
#
# Not to be confused with a Theme: topics come from the forum, themes are
# what we compute (a week's threads grouped by meaning).
class Topic < ApplicationRecord
  has_many :posts, dependent: :destroy

  validates :discourse_id, :title, :slug, presence: true

  def url(base = Discourse::Client::BASE_URL) = "#{base}/t/#{slug}/#{discourse_id}"
end
