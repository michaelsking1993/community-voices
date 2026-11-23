# The weekly ETL run, scheduled in config/recurring.yml.
# Looks back 8 days rather than 7 so a late or failed run leaves no gap;
# the upsert makes the overlap harmless.
class IngestWeekJob < ApplicationJob
  queue_as :default

  def perform(days: 8)
    result = Ingest::ForumCrawler.new.call(since: days.days.ago)
    Rails.logger.info("[IngestWeekJob] #{result.to_h}")
    result
  end
end
