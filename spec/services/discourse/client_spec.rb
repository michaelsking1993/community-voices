require "rails_helper"

RSpec.describe Discourse::Client do
  subject(:client) { instant_client }

  describe "#latest_posts" do
    it "returns the posts from /posts.json" do
      stub_posts_page([ discourse_post(id: 5, created_at: Time.current) ])
      expect(client.latest_posts.map { _1["id"] }).to eq([ 5 ])
    end

    it "pages backwards with before=" do
      stub_posts_page([], before: 5)
      expect(client.latest_posts(before: 5)).to eq([])
    end

    it "sends a descriptive User-Agent" do
      stub = stub_posts_page([]).with(headers: { "User-Agent" => described_class::USER_AGENT })
      client.latest_posts
      expect(stub).to have_been_requested
    end

    it "retries after a 429 and then succeeds" do
      stub_request(:get, "#{DiscourseHelpers::BASE}/posts.json")
        .to_return({ status: 429, headers: { "Retry-After" => "2" } }, json_response({ "latest_posts" => [] }))
      expect(client.latest_posts).to eq([])
    end

    it "raises on other errors" do
      stub_request(:get, "#{DiscourseHelpers::BASE}/posts.json").to_return(status: 500)
      expect { client.latest_posts }.to raise_error(Discourse::Client::Error, /HTTP 500/)
    end
  end

  describe "#category_names" do
    it "names subcategories as 'Parent › Child'" do
      stub_categories
      expect(client.category_names).to eq(21 => "Anki", 9 => "Anki › Help")
    end
  end
end
