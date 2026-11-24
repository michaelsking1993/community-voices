module Ingest
  # Which weeks the database holds in full. The oldest week of a crawl can
  # be partial: a backfill that started on a Thursday has no Monday to
  # Wednesday posts. Counting that week as real would make activity look
  # like it grew, and trend lines would start with fake zeros.
  #
  # The data cannot say when a crawl began, so this infers it: the forum
  # posts every hour or so, so if the oldest post is within the first hours
  # of its Monday, the crawl started on the Monday and that week is whole.
  # `ingest:backfill` always starts on a Monday.
  class Coverage
    GRACE = 6.hours

    # Where a backfill of `weeks` full weeks starts: a Monday at midnight,
    # so the oldest week is whole (plus the current week so far).
    def self.backfill_start(weeks, today = Time.zone.today) = Week.containing(today).previous(weeks).start.in_time_zone

    # The oldest post is looked up on first use, not when this is built.
    def initialize(oldest_post_at: nil) = @oldest_post_at = oldest_post_at

    # The oldest week with all its posts, or nil if there are none.
    def first_full_week
      return @first_full_week if defined?(@first_full_week)

      oldest = @oldest_post_at || Post.minimum(:posted_at)
      week = oldest && Week.containing(oldest)
      @first_full_week = week && (oldest < week.start.in_time_zone + GRACE ? week : week.next)
    end

    # Where a backfill of `weeks` needs to crawl from. When the database
    # already holds everything since that Monday, only the last day before
    # the newest post is crawled again, so restarting the app is quick.
    def crawl_from(weeks, today = Time.zone.today, newest_post_at: Post.maximum(:posted_at))
      start = self.class.backfill_start(weeks, today)
      return start unless newest_post_at && first_full_week && first_full_week.start <= start.to_date

      [ start, newest_post_at - 1.day ].max
    end

    def full?(week) = first_full_week.present? && week.start >= first_full_week.start
  end
end
