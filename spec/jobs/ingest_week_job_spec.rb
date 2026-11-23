require "rails_helper"

RSpec.describe IngestWeekJob do
  it "crawls the last 8 days so consecutive weekly runs overlap" do
    crawler = instance_double(Ingest::ForumCrawler, call: Ingest::ForumCrawler::Result.new(pages: 1, posts_seen: 1, posts_saved: 1))
    allow(Ingest::ForumCrawler).to receive(:new).and_return(crawler)

    freeze_time do
      described_class.perform_now
      expect(crawler).to have_received(:call).with(since: 8.days.ago)
    end
  end

  it "is scheduled weekly in config/recurring.yml" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    expect(schedule.dig("production", "weekly_ingest")).to include("class" => "IngestWeekJob", "schedule" => "every monday at 6am")
  end
end
