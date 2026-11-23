require "rails_helper"

# Runs the real model (downloads ~90 MB on first run), so it is opt-in:
#   RUN_MODEL_SPECS=1 bundle exec rspec --tag model
RSpec.describe Embeddings::LocalModel, :model do
  around do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  let(:model) { described_class.instance }

  it "returns 384-dimension unit vectors" do
    vector = model.embed([ "hello" ]).first
    expect(vector.size).to eq(384)
    expect(vector.sum { _1 * _1 }).to be_within(1e-4).of(1.0)
  end

  it "puts texts with the same meaning but different words close together" do
    a, b, c = model.embed([ "my reviews vanished after syncing", "lost progress after AnkiWeb sync", "how do I change the card font" ])
    dot = ->(x, y) { x.zip(y).sum { _1 * _2 } }

    expect(dot.(a, b)).to be > dot.(a, c) + 0.2
  end
end
