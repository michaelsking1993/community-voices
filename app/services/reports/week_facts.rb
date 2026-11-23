module Reports
  # Exact numbers about a week, from SQL. The model is told to use these
  # as given and never to estimate its own.
  class WeekFacts
    Counts = Data.define(:posts, :threads, :people)

    def call(week, baseline_weeks: 4)
      current = counts(week)
      earlier = (1..baseline_weeks).map { counts(week.previous(_1)) }.reject { _1.posts.zero? }
      { week: current, baseline: average(earlier), baseline_weeks: earlier.size }
    end

    def to_prompt(facts)
      now = facts[:week]
      line = "Forum activity this week (exact, from the database): #{now.posts} posts in #{now.threads} threads by #{now.people} people."
      return line unless facts[:baseline]

      before = facts[:baseline]
      "#{line}\nAverage of the #{facts[:baseline_weeks]} weeks before: #{before.posts} posts in #{before.threads} threads by #{before.people} people."
    end

    private

    def counts(week)
      posts = Post.posted_between(week.range.begin, week.range.end)
      Counts.new(posts: posts.count, threads: posts.distinct.count(:topic_id), people: posts.distinct.count(:username))
    end

    def average(list)
      return nil if list.empty?

      Counts.new(**%i[posts threads people].to_h { |field| [ field, (list.sum(&field).to_f / list.size).round ] })
    end
  end
end
