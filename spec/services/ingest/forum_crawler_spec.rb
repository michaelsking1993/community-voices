require "rails_helper"

RSpec.describe Ingest::ForumCrawler do
  subject(:crawler) { described_class.new(client: instant_client, logger: Logger.new(nil)) }

  let(:now) { Time.zone.parse("2026-11-23 12:00") }
  let(:since) { now - 7.days }

  before { stub_categories }

  it "pages backwards until a whole page is older than `since`, saving only posts inside the window" do
    stub_posts_page([ discourse_post(id: 30, created_at: now - 1.day), discourse_post(id: 20, created_at: now - 3.days) ])
    stub_posts_page([ discourse_post(id: 15, created_at: now - 6.days), discourse_post(id: 10, created_at: now - 9.days) ], before: 20)
    stub_posts_page([ discourse_post(id: 8, created_at: now - 10.days) ], before: 10)

    result = crawler.call(since:)

    expect(result.to_h).to eq(pages: 3, posts_seen: 5, posts_saved: 3)
    expect(Post.pluck(:discourse_id)).to contain_exactly(30, 20, 15)
    expect(a_request(:get, /before=8/)).not_to have_been_made
  end

  it "keeps going past a single out-of-order old post" do
    stub_posts_page([ discourse_post(id: 30, created_at: now - 1.day), discourse_post(id: 29, created_at: now - 1.year) ])
    stub_posts_page([ discourse_post(id: 25, created_at: now - 2.days) ], before: 29)
    stub_posts_page([], before: 25)

    crawler.call(since:)

    expect(Post.pluck(:discourse_id)).to contain_exactly(30, 25)
  end

  it "stores topics with their category name" do
    stub_posts_page([ discourse_post(id: 1, topic_id: 7, created_at: now) ])
    stub_posts_page([], before: 1)

    crawler.call(since:)

    expect(Topic.sole).to have_attributes(discourse_id: 7, title: "Topic 7", category_name: "Anki › Help")
  end

  it "is idempotent: a second run updates instead of duplicating" do
    stub_posts_page([ discourse_post(id: 1, created_at: now, raw: "first") ])
    stub_posts_page([], before: 1)
    crawler.call(since:)

    stub_posts_page([ discourse_post(id: 1, created_at: now, raw: "edited") ])
    crawler.call(since:)

    expect(Post.count).to eq(1)
    expect(Post.sole.raw).to eq("edited")
  end

  it "skips moderator actions, hidden and deleted posts" do
    stub_posts_page([
      discourse_post(id: 4, created_at: now),
      discourse_post(id: 3, created_at: now, post_type: 3),
      discourse_post(id: 2, created_at: now, hidden: true),
      discourse_post(id: 1, created_at: now, deleted_at: now.iso8601)
    ])
    stub_posts_page([], before: 1)

    crawler.call(since:)

    expect(Post.pluck(:discourse_id)).to eq([ 4 ])
  end
end
