module Search
  # Finds the stored chunks closest in meaning to a query, then shapes the
  # result so it is useful evidence for a report:
  #
  # 1. Filter   only chunks whose post falls inside `window` (a time range),
  #             in the same SQL query as the vector search.
  # 2. Fetch    the CANDIDATES nearest chunks, more than we need.
  # 3. Cut off  anything farther than `max_distance`. If nothing is left,
  #             the result is empty and the caller says "not enough evidence".
  # 4. Spread   at most `per_topic` chunks from any one forum thread, so one
  #             long thread cannot fill every slot.
  # 5. Log      every call as a Retrieval with its hits, for the stats page.
  #
  # The embedding model is injected: specs pass a fake.
  class Retriever
    Hit = Data.define(:chunk, :distance, :rank)
    Result = Data.define(:retrieval, :hits) do
      def empty? = hits.empty?
      def chunks = hits.map(&:chunk)
    end

    K = 8              # chunks returned
    PER_TOPIC = 2      # most chunks from one forum thread
    MAX_DISTANCE = 0.6 # cosine distance; farther than this is "not about it"
    CANDIDATES = 100   # fetched before cutting and spreading
    EF_SEARCH = 200    # how hard HNSW searches; must be >= CANDIDATES

    def initialize(model: Embeddings::LocalModel.instance)
      @model = model
    end

    def call(query, window: nil, k: K, per_topic: PER_TOPIC, max_distance: MAX_DISTANCE, purpose: "adhoc")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      candidates = nearest(@model.embed([ query ]).first, window)
      hits = pick(candidates, k:, per_topic:, max_distance:)
      ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      Result.new(retrieval: log(query, window, hits, candidates.size, ms, k:, per_topic:, max_distance:, purpose:), hits:)
    end

    private

    # HNSW only looks at `ef_search` neighbours (default 40), and pgvector
    # 0.6/0.7 applies the WHERE clause after that. With a narrow date window
    # most of those 40 can be filtered out, so we raise ef_search.
    def nearest(vector, window)
      scope = Chunk.where.not(embedding: nil).joins(:post).preload(post: :topic)
      scope = scope.where(posts: { posted_at: window }) if window
      Chunk.with_ef_search(EF_SEARCH) do
        scope.nearest_neighbors(:embedding, vector, distance: "cosine").limit(CANDIDATES).to_a
      end
    end

    def pick(candidates, k:, per_topic:, max_distance:)
      per_thread = Hash.new(0)
      candidates
        .select { |chunk| chunk.neighbor_distance <= max_distance }
        .select { |chunk| per_topic.nil? || (per_thread[chunk.post.topic_id] += 1) <= per_topic }
        .first(k)
        .each_with_index.map { |chunk, i| Hit.new(chunk:, distance: chunk.neighbor_distance, rank: i + 1) }
    end

    def log(query, window, hits, candidates_count, duration_ms, k:, per_topic:, max_distance:, purpose:)
      retrieval = Retrieval.create!(
        query:, purpose:, window_start: window&.begin, window_end: window&.end,
        k:, per_topic: per_topic || 0, max_distance:, candidates_count:, hits_count: hits.size, duration_ms:
      )
      rows = hits.map { |hit| { retrieval_id: retrieval.id, chunk_id: hit.chunk.id, rank: hit.rank, distance: hit.distance } }
      RetrievalHit.insert_all(rows) if rows.any?
      retrieval
    end
  end
end
