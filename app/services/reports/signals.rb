module Reports
  # What the RAG arm knows about next week, beyond this week's posts:
  #
  #   trends   for each theme, posts per week over the last 6 weeks whose
  #            chunks sit close to the theme's centre (vectors + SQL)
  #   events   betas, releases and announcements active in the last two
  #            weeks, added to the evidence so predictions can cite them
  #
  # Only data from before the end of `week` is used, so the backtest can
  # pretend it is an earlier date.
  class Signals
    TREND_WEEKS = 6
    TREND_DISTANCE = 0.35 # a post counts toward a theme if a chunk is this close to its centre
    EVENT_DAYS = 14
    EVENT_CATEGORIES = /Beta Testing|Announcements/
    EVENT_TITLES = /\b(release|released|beta)\b/i # not "update": too many "broke after update" help threads

    def call(week, themes, evidence)
      evidence.signals = themes.map { trend_line(week, _1) }
      events(week).each { |chunk| evidence.add(chunk, theme: 0) }
      evidence
    end

    def trend_line(week, theme)
      counts = (TREND_WEEKS - 1).downto(0).map { |back| close_posts(week.previous(back), theme.centroid) }
      "Theme #{theme.position} (#{theme.label}): #{counts.join(", ")}"
    end

    private

    def close_posts(week, centroid)
      Chunk.joins(:post).where(posts: { posted_at: week.range })
           .where("(chunks.embedding <=> ?::vector) < ?", centroid.to_s, TREND_DISTANCE)
           .distinct.count("posts.id")
    end

    # The newest chunk of each release/beta thread active in the window.
    def events(week)
      window = (week.finish - EVENT_DAYS).in_time_zone...week.range.end
      topics = Topic.joins(:posts).where(posts: { posted_at: window }).distinct
                    .select { _1.category_name.to_s.match?(EVENT_CATEGORIES) || _1.title.match?(EVENT_TITLES) }
      topics.filter_map do |topic|
        Chunk.joins(:post).where(posts: { topic_id: topic.id, posted_at: window }).preload(post: :topic)
             .order("posts.posted_at DESC", :position).first
      end
    end
  end
end
