require "rails_helper"

RSpec.describe Reports::WeekFacts do
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }

  before do
    create_post(raw: "a post from a partly crawled week", posted_at: Time.zone.parse("2026-11-13 10:00"))
    3.times { |i| create_post(raw: "a post from the report's week #{i}", posted_at: Time.zone.parse("2026-11-17 10:00")) }
  end

  it "counts the week exactly" do
    expect(described_class.new.call(week)[:week]).to have_attributes(posts: 3, threads: 1, people: 3)
  end

  it "leaves a partly crawled week out of the baseline" do
    facts = described_class.new.call(week)

    expect(facts[:baseline]).to be_nil
    expect(described_class.new.to_prompt(facts)).not_to include("Average")
  end

  it "averages the earlier weeks the database holds in full" do
    coverage = Ingest::Coverage.new(oldest_post_at: Time.zone.parse("2026-11-09 00:10"))
    facts = described_class.new(coverage:).call(week)

    expect(facts).to include(baseline_weeks: 1, baseline: have_attributes(posts: 1))
  end
end
