require "rails_helper"

RSpec.describe Ingest::WeeklyStats do
  it "counts topics, posts and approximate tokens per week" do
    topic = Topic.create!(discourse_id: 1, title: "t", slug: "t")
    monday = Time.zone.parse("2026-11-16 10:00")
    Post.create!(topic:, discourse_id: 1, post_number: 1, username: "a", raw: "x" * 400, posted_at: monday)
    Post.create!(topic:, discourse_id: 2, post_number: 2, username: "b", raw: "x" * 400, posted_at: monday + 1.day)

    expect(described_class.new.call).to eq([ { week: monday.to_date, topics: 1, posts: 2, tokens: 200 } ])
  end
end
