namespace :ingest do
  desc "Crawl the last N weeks of forum posts (default 2). Example: bin/rails 'ingest:backfill[12]'"
  task :backfill, [ :weeks ] => :environment do |_, args|
    weeks = (args[:weeks] || ENV.fetch("BACKFILL_WEEKS", 2)).to_i
    next puts("Skipping backfill (0 weeks)") if weeks.zero?

    puts "Crawling #{weeks} week(s) of forums.ankiweb.net at 1 request/second..."
    Rails.logger = ActiveSupport::Logger.new($stdout)
    result = Ingest::ForumCrawler.new.call(since: weeks.weeks.ago)
    puts "Done: #{result.pages} pages, #{result.posts_saved} posts saved."
  end

  desc "Posts and rough token counts per week, to compare with the forum's own stats"
  task stats: :environment do
    puts Ingest::WeeklyStats.new.call.map { |row| row.values.join("\t") }.unshift("week\ttopics\tposts\t~tokens")
  end
end
