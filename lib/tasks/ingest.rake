namespace :ingest do
  desc "Crawl, chunk and embed the last N full weeks of forum posts, plus this week so far (default 2). Example: bin/rails 'ingest:backfill[12]'"
  task :backfill, [ :weeks ] => :environment do |_, args|
    weeks = (args[:weeks] || ENV.fetch("BACKFILL_WEEKS", 2)).to_i
    next puts("Skipping backfill (0 weeks)") if weeks.zero?

    since = Ingest::Coverage.new.crawl_from(weeks)
    puts "Crawling forums.ankiweb.net from #{since.to_date} (#{weeks} full week(s) plus this one; already-stored days are skipped) at 1 request/second..."
    crawled = Ingest::ForumCrawler.new(logger: ActiveSupport::Logger.new($stdout)).call(since:)
    puts "Crawled #{crawled.pages} pages, saved #{crawled.posts_saved} posts."

    puts "Chunking and embedding (the first run downloads the ~90 MB model)..."
    transformed = Ingest::Transform.new.call(since:)
    puts "#{transformed.posts} posts -> #{transformed.chunks} chunks, #{transformed.embedded} newly embedded."
  end

  desc "Re-chunk and embed every stored post (no crawling)"
  task transform: :environment do
    puts Ingest::Transform.new.call(since: Time.zone.at(0)).to_h
  end

  desc "Posts and rough token counts per week, to compare with the forum's own stats"
  task stats: :environment do
    puts Ingest::WeeklyStats.new.call.map { |row| row.values.join("\t") }.unshift("week\ttopics\tposts\t~tokens")
  end

  desc "Spot-check: the 5 chunks nearest to a phrase. Example: bin/rails 'ingest:nearest[sync problems]'"
  task :nearest, [ :query ] => :environment do |_, args|
    Chunk.similar_to(args.fetch(:query)).each do |chunk|
      puts format("%.3f  %s\n       %s", chunk.neighbor_distance, chunk.post.url, chunk.content.split("\n\n", 2).last.truncate(140))
    end
  end
end
