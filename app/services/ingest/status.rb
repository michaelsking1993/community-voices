module Ingest
  # What the database holds right now, in the terms a person cares about:
  # how many complete weeks, how many posts, and when the newest post is.
  # Shown on every page (the status line under the tabs) and on the Data tab.
  class Status
    WeekRow = Data.define(:week, :threads, :posts, :chunks, :state) # state: full, partial, current

    def initialize(today: Time.zone.today)
      @today = today
      @coverage = Coverage.new
    end

    # Complete weeks the database holds in full, newest first: not this
    # week, and not a partly crawled first week.
    def full_weeks = rows.select { _1.state == "full" }.map(&:week)

    def posts = @posts ||= Post.count
    def chunks = @chunks ||= Chunk.where.not(embedding: nil).count
    def newest_post_at = @newest_post_at ||= Post.maximum(:posted_at)
    def empty? = posts.zero?

    def rows
      @rows ||= begin
        counts = Post.group(Arel.sql("date_trunc('week', posts.posted_at)::date"))
                     .pluck(Arel.sql("date_trunc('week', posts.posted_at)::date"), Arel.sql("count(DISTINCT posts.topic_id)"), Arel.sql("count(*)"))
        chunk_counts = Chunk.where.not(embedding: nil).joins(:post)
                            .group(Arel.sql("date_trunc('week', posts.posted_at)::date")).count
        current = Week.containing(@today)
        counts.sort_by(&:first).reverse.map do |start, threads, posts|
          week = Week.new(start:)
          state = if week == current then "current" elsif @coverage.full?(week) then "full" else "partial" end
          WeekRow.new(week:, threads:, posts:, chunks: chunk_counts.fetch(start, 0), state:)
        end
      end
    end
  end
end
