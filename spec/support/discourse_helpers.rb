# Builds small, made-up Discourse API payloads. We never commit real
# forum data, so every fixture here is synthetic.
module DiscourseHelpers
  BASE = Discourse::Client::BASE_URL

  def discourse_post(id:, created_at:, topic_id: 1, **overrides)
    {
      "id" => id, "topic_id" => topic_id, "topic_title" => "Topic #{topic_id}",
      "topic_slug" => "topic-#{topic_id}", "category_id" => 9, "post_number" => 1,
      "reply_to_post_number" => nil, "username" => "user#{id}", "post_type" => 1,
      "hidden" => false, "deleted_at" => nil, "created_at" => created_at.iso8601,
      "raw" => "Post #{id} about syncing my deck."
    }.merge(overrides.transform_keys(&:to_s))
  end

  def stub_categories
    body = { "category_list" => { "categories" => [
      { "id" => 21, "name" => "Anki", "subcategory_list" => [ { "id" => 9, "name" => "Help" } ] }
    ] } }
    stub_request(:get, "#{BASE}/categories.json?include_subcategories=true").to_return(json_response(body))
  end

  def stub_posts_page(posts, before: nil)
    url = before ? "#{BASE}/posts.json?before=#{before}" : "#{BASE}/posts.json"
    stub_request(:get, url).to_return(json_response({ "latest_posts" => posts }))
  end

  def json_response(body, status: 200)
    { status:, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  # A client that never sleeps, for fast specs.
  def instant_client
    Discourse::Client.new(throttle: Discourse::Throttle.new(sleeper: ->(_) { }), sleeper: ->(_) { })
  end
end

RSpec.configure { |c| c.include DiscourseHelpers }
