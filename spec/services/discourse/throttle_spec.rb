require "rails_helper"

RSpec.describe Discourse::Throttle do
  let(:now) { [ 100.0 ] }
  let(:sleeps) { [] }
  let(:throttle) do
    described_class.new(interval: 1.0, clock: -> { now.first }, sleeper: ->(s) { sleeps << s; now[0] += s })
  end

  it "does not wait before the first request" do
    throttle.wait!
    expect(sleeps).to be_empty
  end

  it "waits out the rest of the interval between back-to-back requests" do
    throttle.wait!
    now[0] += 0.25
    throttle.wait!
    expect(sleeps).to eq([ 0.75 ])
  end

  it "does not wait when enough time has already passed" do
    throttle.wait!
    now[0] += 2
    throttle.wait!
    expect(sleeps).to be_empty
  end
end
