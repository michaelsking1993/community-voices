require "rails_helper"

RSpec.describe Ab::SupportJudge do
  let(:evidence) do
    { "E1" => { chunk_id: 1, post_id: 1, url: "https://x/1", title: "T1", category: "c", date: "2026-11-16", text: "decks vanished after sync", theme: 1, history: false },
      "E2" => { chunk_id: 2, post_id: 2, url: "https://x/2", title: "T2", category: "c", date: "2026-11-16", text: "toolbar is gone", theme: 1, history: false } }
  end
  let(:content) do
    { "overview" => "Decks vanished [E1]. Nothing cited here.",
      "sections" => [ { "body" => "Users lost the toolbar [E2]. They also love it [E9]." } ],
      "predictions" => [ { "reasoning" => "Sync keeps failing [E1][E2]." } ] }
  end
  let(:report) { Report.create!(week_start: Date.new(2026, 11, 16), arm: "rag", status: "done", content:, evidence:) }

  it "asks about each cited sentence, marks sentences citing nothing real as unsupported without asking" do
    llm = FakeLlm.new(claims: [ { claim: 1, verdict: "supported", note: "ok" }, { claim: 2, verdict: "partly", note: "sort of" },
                                { claim: 3, verdict: "unsupported", note: "no" } ])
    judgement = described_class.new(llm:).call(report)

    prompt = llm.calls.last[:prompt]
    expect(prompt).to include("Sentence 3", "Sync keeps failing", "toolbar is gone")
    expect(prompt).not_to include("love it", "Nothing cited here")
    expect(judgement.data["counts"]).to eq("supported" => 1, "partly" => 1, "unsupported" => 2)
    expect(judgement.data["claims"].last).to include("note" => "cites nothing that exists")
    expect(judgement.data["support_rate"]).to eq(0.38)
  end

  it "makes no model call for a report with no citations" do
    report.update!(content: { "overview" => "Just words.", "sections" => [] })
    llm = FakeLlm.new
    judgement = described_class.new(llm:).call(report)

    expect(llm.calls).to be_empty
    expect(judgement.data).to include("claims" => [], "support_rate" => nil, "cited_sentences" => 0)
  end
end
