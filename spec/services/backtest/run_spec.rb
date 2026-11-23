require "rails_helper"

RSpec.describe Backtest::Run do
  let(:today) { Date.new(2026, 11, 23) }
  let(:builder) { instance_double(Reports::Builder) }
  let(:scorer) { instance_double(Backtest::Scorer) }
  let(:run) { described_class.new(builder:, scorer:, today:) }
  let(:week) { Week.new(start: Date.new(2026, 11, 9)) }

  def report(week_start, predictions: [ { "claim" => "c" } ])
    Report.create!(week_start:, status: "done", content: { "predictions" => predictions })
  end

  it "scores the most recent weeks whose following week is complete, oldest first" do
    expect(run.weeks(3).map(&:start)).to eq([ Date.new(2026, 10, 26), Date.new(2026, 11, 2), Date.new(2026, 11, 9) ])
  end

  it "reuses a stored report and builds one only when missing" do
    stored = report(week.start)
    built = nil
    allow(builder).to receive(:call).with(week.previous) { built = report(week.previous.start) }
    allow(scorer).to receive(:call) { |r| Judgement.create!(kind: "prediction", week_start: r.week_start, report: r) }

    judgements = run.call([ week.previous, week ])

    expect(judgements.map(&:report)).to eq([ built, stored ])
    expect(builder).to have_received(:call).once
  end

  it "does not pay to score a report twice" do
    report = report(week.start)
    Judgement.create!(kind: "prediction", week_start: week.start, report:)
    allow(scorer).to receive(:call)

    expect(run.call([ week ]).map(&:report)).to eq([ report ])
    expect(scorer).not_to have_received(:call)
  end

  it "skips reports that made no predictions" do
    report(week.start, predictions: [])
    expect(run.call([ week ])).to eq([])
  end
end
