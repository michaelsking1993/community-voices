module Charts
  # The first two principal components of a list of vectors, by power
  # iteration: repeatedly multiply a guess by the covariance of the data
  # until it points along the direction of greatest spread. Plain Ruby,
  # fine for the hundreds of threads the map shows.
  module Pca
    ITERATIONS = 30

    # -> [[x, y], ...] one pair per input vector
    def self.project(vectors)
      mean = vectors.transpose.map { _1.sum / vectors.size }
      centred = vectors.map { |v| v.each_index.map { |i| v[i] - mean[i] } }
      first = component(centred)
      deflated = centred.map { |v| scale = dot(v, first); v.each_index.map { |i| v[i] - (scale * first[i]) } }
      second = component(deflated)
      centred.map { [ dot(_1, first), dot(_1, second) ] }
    end

    def self.component(centred)
      vector = Array.new(centred.first.size) { |i| Math.sin(i + 1) } # fixed start: same map every time
      ITERATIONS.times do
        scores = centred.map { dot(_1, vector) }
        next_vector = centred.each_with_index.each_with_object(Array.new(vector.size, 0.0)) do |(row, r), sum|
          row.each_index { |i| sum[i] += row[i] * scores[r] }
        end
        vector = Themes::KMeans.normalize(next_vector)
      end
      vector
    end

    def self.dot(a, b) = Themes::KMeans.dot(a, b)
  end
end
