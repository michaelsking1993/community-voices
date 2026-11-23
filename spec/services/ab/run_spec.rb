require "rails_helper"

RSpec.describe Ab::Run do
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:support) { instance_double(Ab::SupportJudge) }
  let(:ranker) { instance_double(Ab::Ranker) }
  let(:built) { [] }
  let(:builders) do
    Ab::Run::ARMS.index_with do |arm|
      ->(w) { built << arm; Report.create!(week_start: w.start, arm:, status: "done") }
    end.transform_values { |fn| Struct.new(:fn) { def call(w) = fn.call(w) }.new(fn) }
  end

  before do
    allow(Ab::SupportJudge).to receive(:new).and_return(support)
    allow(Ab::Ranker).to receive(:new).and_return(ranker)
    allow(support).to receive(:call) { |r| Judgement.create!(kind: "support", week_start: r.week_start, report: r) }
    allow(ranker).to receive(:call) { |w, _| Judgement.create!(kind: "ranking", week_start: w.start) }
  end

  it "writes all three arms, judges support for each and ranks them once" do
    reports = described_class.new(llm: nil, builders:).call(week)

    expect(reports.keys).to eq(%w[rag paste_all none])
    expect(built).to eq(%w[rag paste_all none])
    expect(support).to have_received(:call).exactly(3).times
    expect(ranker).to have_received(:call).once
  end

  it "reuses stored reports and judgements" do
    described_class.new(llm: nil, builders:).call(week)
    built.clear
    described_class.new(llm: nil, builders:).call(week)

    expect(built).to be_empty
    expect(support).to have_received(:call).exactly(3).times
    expect(ranker).to have_received(:call).once
  end
end
