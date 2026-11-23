require "rails_helper"

RSpec.describe "A/B arms in Reports::Builder" do
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:answer) { { headline: "h", overview: "o", sections: [], predictions: [] } }
  let(:llm) { FakeLlm.new(answer) }

  before do
    Theme.create!(week_start: week.start, position: 1, label: "Sync", summary: "s", kind: "problem", centroid: [ 1.0 ] + [ 0.0 ] * 383,
                  topic_count: 2, post_count: 2, author_count: 2)
    [ [ 1, "2026-11-17 10:00", "first post about decks and sync in this week" ], [ 2, "2026-11-18 10:00", "second post about the toolbar in this week too" ],
      [ 3, "2026-11-05 10:00", "an older post from an earlier week that must be left out" ] ].each do |id, at, raw|
      topic = Topic.create!(discourse_id: id, title: "Thread #{id}", slug: "t-#{id}", category_name: "Anki")
      Chunking::Chunker.new.call(create_post(raw: raw + " " + words(15), topic:, posted_at: Time.zone.parse(at)))
    end
  end

  it "paste_all puts every post of the week in the prompt, with no search" do
    builder = Reports::Builder.new(llm:, arm: "paste_all", evidence_source: Reports::PasteAllEvidence.new)
    report = builder.call(week)
    prompt = llm.calls.last[:prompt]

    expect(report.arm).to eq("paste_all")
    expect(prompt).to include("# Every post from this week", "first post about decks", "second post about the toolbar", "find it in the posts listed below")
    expect(prompt).not_to include("earlier week that must be left out")
    expect(report.evidence.size).to eq(2)
    expect(Retrieval.count).to eq(0)
    expect(llm.calls.last[:system]).to include("Use only the evidence given")
  end

  it "none writes from the dates alone, with the plain system prompt" do
    builder = Reports::Builder.new(llm:, arm: "none", evidence_source: Reports::NoEvidence.new, grounded: false)
    report = builder.call(week)

    expect(llm.calls.last[:prompt]).to eq("Week: #{week}")
    expect(llm.calls.last[:system]).to include("You have not been given this week's posts")
    expect(report).to have_attributes(arm: "none", status: "done", evidence: {})
    expect(Theme.count).to eq(1) # no theme finding for this arm
  end
end
