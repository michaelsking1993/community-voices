module Discourse
  # Thin wrapper over the public Discourse JSON API (no login needed).
  #
  #   /posts.json?before=ID  -> the 50 newest posts with id < ID, raw text included
  #   /categories.json       -> category names, including subcategories
  class Client
    BASE_URL = "https://forums.ankiweb.net".freeze
    USER_AGENT = "CommunityVoices/0.1 (weekly research crawler; 1 req/s)".freeze
    MAX_RETRIES = 3

    class Error < StandardError; end

    def initialize(base_url: BASE_URL, throttle: Throttle.new, sleeper: ->(s) { sleep(s) })
      @throttle = throttle
      @sleeper = sleeper
      @http = Faraday.new(url: base_url, headers: { "User-Agent" => USER_AGENT, "Accept" => "application/json" }) do |f|
        f.response :json
        f.options.timeout = 30
      end
    end

    # Newest posts first. Pass `before:` (a post id) to page backwards.
    def latest_posts(before: nil)
      params = before ? { before: before } : {}
      get("/posts.json", params).fetch("latest_posts", [])
    end

    # { category_id => "Parent › Child" }
    def category_names
      body = get("/categories.json", { include_subcategories: true })
      body.dig("category_list", "categories").each_with_object({}) do |cat, names|
        names[cat["id"]] = cat["name"]
        Array(cat["subcategory_list"]).each { |sub| names[sub["id"]] = "#{cat["name"]} › #{sub["name"]}" }
      end
    end

    private

    # Retries rate limits (waiting as long as the server asks), server errors
    # and network failures, with growing waits. Anything else raises.
    def get(path, params, attempt: 1)
      @throttle.wait!
      response = @http.get(path, params)
      return response.body if response.success?
      raise Error, "GET #{path} failed with HTTP #{response.status}" unless retryable?(response.status) && attempt <= MAX_RETRIES

      @sleeper.call(response.status == 429 ? response.headers["Retry-After"].to_i.clamp(1, 60) : 2**attempt)
      get(path, params, attempt: attempt + 1)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Error, "GET #{path} failed: #{e.message}" if attempt > MAX_RETRIES

      @sleeper.call(2**attempt)
      get(path, params, attempt: attempt + 1)
    end

    def retryable?(status) = status == 429 || status >= 500
  end
end
