require "rails_helper"

RSpec.describe Ingest::Coverage do
  let(:monday) { Week.new(start: Date.new(2026, 11, 9)) }

  it "starts a backfill on the Monday N full weeks back" do
    expect(described_class.backfill_start(2, Date.new(2026, 11, 26))).to eq(Time.zone.parse("2026-11-09 00:00"))
  end

  it "counts the oldest week as full when its posts start early on Monday" do
    coverage = described_class.new(oldest_post_at: Time.zone.parse("2026-11-09 01:30"))

    expect(coverage.first_full_week).to eq(monday)
    expect(coverage.full?(monday)).to be(true)
  end

  it "skips the oldest week when the crawl started part-way through it" do
    coverage = described_class.new(oldest_post_at: Time.zone.parse("2026-11-12 05:00"))

    expect(coverage.first_full_week).to eq(monday.next)
    expect(coverage.full?(monday)).to be(false)
  end

  it "crawls from the Monday when the data does not reach back that far" do
    coverage = described_class.new(oldest_post_at: Time.zone.parse("2026-11-16 00:10"))

    expect(coverage.crawl_from(2, Date.new(2026, 11, 26), newest_post_at: Time.zone.parse("2026-11-26 08:00")))
      .to eq(Time.zone.parse("2026-11-09 00:00"))
  end

  it "crawls only the last day when the data already covers the backfill" do
    coverage = described_class.new(oldest_post_at: Time.zone.parse("2026-11-09 00:10"))

    expect(coverage.crawl_from(2, Date.new(2026, 11, 26), newest_post_at: Time.zone.parse("2026-11-26 08:00")))
      .to eq(Time.zone.parse("2026-11-25 08:00"))
  end

  it "covers nothing when there are no posts" do
    expect(described_class.new.full?(monday)).to be(false)
  end
end
