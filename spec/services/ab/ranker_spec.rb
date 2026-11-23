require "rails_helper"

RSpec.describe Ab::Ranker do
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:reports) do
    %w[rag paste_all none].index_with do |arm|
      Report.create!(week_start: week.start, arm:, status: "done",
                     content: { "headline" => "Head #{arm.length}", "overview" => "About it [E1].", "sections" => [], "predictions" => [] })
    end
  end

  before { create_post(raw: words(20), posted_at: Time.zone.parse("2026-11-18 10:00")) }

  def scores(llm_call) = ("A".."C").map { |l| { label: l, coverage: 3, accuracy: 4, specificity: 2, usefulness: 3, invented: 0, note: "n" } }

  it "shows the judge shuffled, anonymous reports without citation ids, and maps the answer back to arms" do
    llm = FakeLlm.new { |call| { reports: scores(call), ranking: %w[B A C] } }
    judgement = described_class.new(llm:).call(week, reports)

    prompt = llm.calls.last[:prompt]
    expect(prompt).to include("# Report A", "# Report B", "# Report C", "Sync keeps failing")
    expect(prompt).not_to match(/\[E1\]|\brag\b|paste_all/)
    labels = judgement.data["labels"]
    expect(labels.values.sort).to eq(%w[A B C])
    expect(judgement.data["ranking"]).to eq([ labels.key("B"), labels.key("A"), labels.key("C") ])
    expect(judgement.data["scores"][labels.key("A")]).to include("accuracy" => 4, "report_id" => reports[labels.key("A")].id)
  end

  it "shuffles the same way for the same week" do
    llm = FakeLlm.new { |call| { reports: scores(call), ranking: %w[A B C] } }
    first = described_class.new(llm:).call(week, reports).data["labels"]
    Judgement.delete_all
    expect(described_class.new(llm:).call(week, reports).data["labels"]).to eq(first)
  end
end
