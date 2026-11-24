require "rails_helper"

RSpec.describe Embeddings::Guard do
  it "reads the column's length from the database" do
    expect(described_class.column_dimensions).to eq(384)
  end

  it "accepts the app's real model without loading it" do
    expect { described_class.check_model!(Embeddings::LocalModel.instance) }.not_to raise_error
  end

  it "rejects vectors of the wrong length" do
    model = FakeEmbeddingModel.new

    expect { described_class.check_vectors!(model, [ Array.new(384, 0.0), Array.new(383, 0.0) ]) }
      .to raise_error(described_class::Mismatch, /returned a 383-number vector/)
  end
end
