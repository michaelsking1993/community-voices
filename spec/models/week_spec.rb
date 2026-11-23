require "rails_helper"

RSpec.describe Week do
  it "starts on Monday and covers seven days" do
    week = described_class.containing(Time.zone.parse("2026-11-19 15:00")) # a Thursday

    expect(week.start).to eq(Date.new(2026, 11, 16))
    expect(week.range).to cover(Time.zone.parse("2026-11-22 23:59"))
    expect(week.range).not_to cover(Time.zone.parse("2026-11-23 00:00"))
    expect(week.to_s).to eq("2026-11-16 to 2026-11-22")
  end

  it "knows the last complete week and its neighbours" do
    week = described_class.last_complete(Date.new(2026, 11, 23))

    expect(week.start).to eq(Date.new(2026, 11, 16))
    expect(week.previous(2).start).to eq(Date.new(2026, 11, 2))
    expect(week.next.start).to eq(Date.new(2026, 11, 23))
  end
end
