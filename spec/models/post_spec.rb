require "rails_helper"

RSpec.describe Post do
  it "links back to the post on the forum" do
    topic = Topic.new(discourse_id: 42, slug: "sync-broke", title: "Sync broke")
    post = described_class.new(topic:, post_number: 3)
    expect(post.url).to eq("https://forums.ankiweb.net/t/sync-broke/42/3")
  end
end
