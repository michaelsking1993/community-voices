require "rails_helper"

RSpec.describe Themes::KMeans do
  def unit(*v) = described_class.normalize(v)

  let(:vectors) do
    [ unit(1, 0.1, 0), unit(1, 0, 0.1), unit(0.9, 0.1, 0.1), # pointing along x
      unit(0, 1, 0.1), unit(0.1, 1, 0), unit(0, 0.9, 0.2) ]  # pointing along y
  end

  it "groups vectors that point the same way" do
    result = described_class.new(k: 2).call(vectors)

    expect(result.assignments.first(3).uniq.size).to eq(1)
    expect(result.assignments.last(3).uniq.size).to eq(1)
    expect(result.assignments.first).not_to eq(result.assignments.last)
  end

  it "returns unit-length centroids" do
    result = described_class.new(k: 2).call(vectors)

    expect(result.centroids.map { |c| described_class.dot(c, c) }).to all(be_within(1e-9).of(1.0))
  end

  it "is deterministic for a given seed" do
    expect(described_class.new(k: 3).call(vectors)).to eq(described_class.new(k: 3).call(vectors))
  end

  it "never asks for more clusters than there are vectors" do
    expect(described_class.new(k: 10).call(vectors.first(2)).centroids.size).to eq(2)
  end
end
