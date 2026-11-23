module Ingest
  # Extract + load for the forum: pages backwards through /posts.json from
  # newest to oldest and upserts every post created at or after `since`.
  #
  # Idempotent: posts are keyed by their forum id, so re-running (or
  # overlapping two runs) updates rows instead of duplicating them.
  class ForumCrawler
    Result = Data.define(:pages, :posts_seen, :posts_saved)

    def initialize(client: Discourse::Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def call(since:)
      categories = @client.category_names
      pages = seen = saved = 0
      before = nil

      loop do
        batch = @client.latest_posts(before: before)
        break if batch.empty?

        pages += 1
        seen += batch.size
        in_window = batch.select { |p| Time.zone.parse(p["created_at"]) >= since }
        saved += save(in_window.select { |p| keep?(p) }, categories)
        @logger.info("[crawler] page #{pages}: #{batch.size} posts, oldest #{batch.last["created_at"]}")

        # Stop once a whole page is older than `since`. Not on the first old
        # post: ids are only roughly in date order (a post moved in from an
        # old topic can keep its old date), so one stray must not end the crawl.
        break if in_window.empty?
        before = batch.map { |p| p["id"] }.min
      end

      Result.new(pages:, posts_seen: seen, posts_saved: saved)
    end

    private

    # Regular posts only: no moderator actions, whispers, hidden or deleted posts.
    def keep?(post)
      post["post_type"] == 1 && !post["hidden"] && post["deleted_at"].nil? && post["raw"].present?
    end

    def save(posts, categories)
      return 0 if posts.empty?

      topic_ids = upsert_topics(posts, categories)
      rows = posts.map do |p|
        {
          topic_id: topic_ids.fetch(p["topic_id"]),
          discourse_id: p["id"],
          post_number: p["post_number"],
          reply_to_post_number: p["reply_to_post_number"],
          username: p["username"],
          raw: p["raw"],
          posted_at: p["created_at"]
        }
      end
      Post.upsert_all(rows, unique_by: :discourse_id)
      rows.size
    end

    # Returns { forum topic id => our topics.id }
    def upsert_topics(posts, categories)
      rows = posts.uniq { |p| p["topic_id"] }.map do |p|
        {
          discourse_id: p["topic_id"],
          title: p["topic_title"],
          slug: p["topic_slug"],
          category_id: p["category_id"],
          category_name: categories[p["category_id"]]
        }
      end
      Topic.upsert_all(rows, unique_by: :discourse_id)
      Topic.where(discourse_id: rows.pluck(:discourse_id)).pluck(:discourse_id, :id).to_h
    end
  end
end
