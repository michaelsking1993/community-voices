# The weekly ETL run, scheduled in config/recurring.yml:
# crawl the forum, then chunk and embed what is new.
#
# Looks back 8 days rather than 7 so a late or failed run leaves no gap;
# upserts and content hashes make the overlap harmless.
class IngestWeekJob < ApplicationJob
  queue_as :default

  def perform(days: 8)
    since = days.days.ago
    crawled = Ingest::ForumCrawler.new.call(since:)
    transformed = Ingest::Transform.new.call(since:)
    Rails.logger.info("[IngestWeekJob] crawled=#{crawled.to_h} transformed=#{transformed.to_h}")
  end
end
