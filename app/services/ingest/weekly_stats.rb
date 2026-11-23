module Ingest
  # How much text is one week, really? Tokens are estimated at ~4
  # characters each, which is close enough to size a prompt.
  class WeeklyStats
    CHARS_PER_TOKEN = 4

    def call
      Post.group("date_trunc('week', posts.posted_at)").order("1")
          .pluck(Arel.sql("date_trunc('week', posts.posted_at)"),
                 Arel.sql("count(DISTINCT topic_id)"), Arel.sql("count(*)"), Arel.sql("sum(length(raw))"))
          .map do |week, topics, posts, chars|
            { week: week.to_date, topics:, posts:, tokens: chars / CHARS_PER_TOKEN }
          end
    end
  end
end
