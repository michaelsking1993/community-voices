module Themes
  # k-means for unit vectors ("spherical k-means"): similarity is the dot
  # product, and each centroid is re-normalised after averaging. Plain Ruby;
  # a week is ~60 threads, so this takes milliseconds.
  #
  # Seeded with k-means++ (spread the starting centroids out) and a fixed
  # random seed, so the same week always gives the same themes.
  class KMeans
    Result = Data.define(:assignments, :centroids)

    def initialize(k:, iterations: 50, seed: 42)
      @k = k
      @iterations = iterations
      @seed = seed
    end

    def call(vectors)
      k = [ @k, vectors.size ].min
      centroids = seed_centroids(vectors, k, Random.new(@seed))
      assignments = nil
      @iterations.times do
        updated = vectors.map { |v| nearest(v, centroids) }
        break if updated == assignments

        assignments = updated
        centroids = centroids.each_index.map { |c| recentre(vectors, assignments, c) || centroids[c] }
      end
      Result.new(assignments:, centroids:)
    end

    def self.dot(a, b) = a.each_index.sum { |i| a[i] * b[i] }

    def self.normalize(v)
      norm = Math.sqrt(v.sum { _1 * _1 })
      norm.zero? ? v : v.map { _1 / norm }
    end

    private

    def nearest(vector, centroids) = centroids.each_index.max_by { |c| self.class.dot(vector, centroids[c]) }

    def recentre(vectors, assignments, cluster)
      members = vectors.select.with_index { |_, i| assignments[i] == cluster }
      return nil if members.empty?

      self.class.normalize(members.transpose.map(&:sum))
    end

    # k-means++: each next seed is picked with probability proportional to
    # its squared distance from the nearest seed so far.
    def seed_centroids(vectors, k, rng)
      centroids = [ vectors[rng.rand(vectors.size)] ]
      while centroids.size < k
        weights = vectors.map { |v| (1 - centroids.map { |c| self.class.dot(v, c) }.max).clamp(0, 2)**2 }
        total = weights.sum
        break if total.zero?

        target = rng.rand * total
        centroids << vectors[weights.each_index.find { |i| (target -= weights[i]) <= 0 } || vectors.size - 1]
      end
      centroids
    end
  end
end
