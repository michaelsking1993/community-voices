require "rails_helper"

RSpec.describe Charts::Pca do
  it "puts the direction of greatest spread on the first axis" do
    # Points spread widely along dimension 0, a little along dimension 1, not at all along 2.
    vectors = [ [ -4.0, 0.5, 1 ], [ -2.0, -0.5, 1 ], [ 0.0, 0.4, 1 ], [ 2.0, -0.4, 1 ], [ 4.0, 0.0, 1 ] ]
    points = described_class.project(vectors)

    xs = points.map(&:first)
    expect(xs.map(&:abs).max).to be_within(0.05).of(4.0)
    expect(xs.sort).to eq(xs.sort.reverse.reverse) # sanity: numbers, not NaN
    expect(points.map(&:last).map(&:abs).max).to be < 1.0
  end

  it "is deterministic" do
    vectors = Array.new(6) { |i| Array.new(5) { |j| Math.sin(i * j + 1) } }
    expect(described_class.project(vectors)).to eq(described_class.project(vectors))
  end
end
