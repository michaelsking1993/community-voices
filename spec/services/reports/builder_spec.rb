require "rails_helper"

RSpec.describe Reports::Builder do
  let(:model) { FakeEmbeddingModel.new }
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:retriever) { Search::Retriever.new(model:) }
  let(:sync_text) { "my deck vanished after sync and the ankiweb server shows an older copy of my whole collection" }

  let(:llm) do
    FakeLlm.new do |call|
      if call[:schema] == Themes::Finder::SCHEMA
        { themes: [ { cluster: 1, label: "Sync loses decks", summary: "Decks vanish after sync.", kind: "problem" } ] }
      else
        { headline: "Sync lost decks.", overview: "People lost decks after syncing [E1].",
          sections: [ { theme: 1, title: "Lost decks", body: "Decks vanished after sync [E1].",
                        quotes: [ { evidence: "E1", text: "my deck vanished after sync" } ] } ],
          predictions: [ { claim: "More lost-deck threads next week.", reasoning: "It keeps recurring [E3].",
                           basis: "recurring", confidence: "medium", theme: 1 } ] }
      end
    end
  end

  def builder = described_class.new(llm:, evidence_source: Reports::RagEvidence.new(retriever:),
                                     theme_finder: Themes::Finder.new(llm:, k: 1))

  def add_thread(id, raw, posted_at: Time.zone.parse("2026-11-18 10:00"))
    topic = Topic.create!(discourse_id: id, title: "Sync thread #{id}", slug: "sync-#{id}", category_name: "Anki › Syncing")
    Chunking::Chunker.new.call(create_post(raw:, topic:, posted_at:))
  end

  before { stub_const("Search::Retriever::MAX_DISTANCE", 0.95) }

  context "with evidence this week" do
    before do
      add_thread(1, sync_text)
      add_thread(2, "#{sync_text} again today")
      add_thread(3, "#{sync_text} last month", posted_at: Time.zone.parse("2026-10-20"))
      Embeddings::Embedder.new(model:).call
    end

    it "writes a cited report from numbered evidence and checks it" do
      report = builder.call(week)

      expect(report).to have_attributes(status: "done", arm: "rag", week_start: week.start, model: "fake-model")
      expect(report.sections.first["title"]).to eq("Lost decks")
      expect(report.grounding).to include("citations_valid" => 3, "quotes_verbatim" => 1)
      expect(report.predictions.first).to include("claim" => "More lost-deck threads next week.", "basis" => "recurring")
      expect(report.markdown).to include("## Next week", "**More lost-deck threads next week.** (medium confidence)")
      expect(report.evidence["E1"]).to include("url" => a_string_starting_with("https://forums.ankiweb.net/t/sync-"))
      expect(report.markdown).to include("# Community Voices: Anki forums, 2026-11-16 to 2026-11-22", "[[1]](https://forums.ankiweb.net")
      expect(report.content["themes"].first).to include("label" => "Sync loses decks", "topic_count" => 2)
    end

    it "gives the model this week's evidence, earlier look-alikes, exact counts and the rules" do
      builder.call(week)
      call = llm.calls.last

      expect(call[:system]).to include("Use only the evidence given", "word for word")
      expect(call[:prompt]).to include("2 posts in 2 threads by 2 people", "## Theme 1: Sync loses decks",
                                       "Evidence from this week:", "Similar posts from earlier weeks", "last month",
                                       "# Signals for next week (2026-11-23 to 2026-11-29)", "Theme 1 (Sync loses decks):")
      expect(call[:system]).to include("predict 3 to 5 things")
    end

    it "links its retrievals to the report, for the stats page" do
      report = builder.call(week)

      expect(report.retrievals.pluck(:purpose)).to contain_exactly("report", "report_history")
    end
  end

  it "says there is not enough evidence, without calling the model to write, when nothing is relevant" do
    add_thread(1, sync_text)
    add_thread(2, "#{sync_text} again today")
    Embeddings::Embedder.new(model:).call
    stub_const("Search::Retriever::MAX_DISTANCE", 0.0)

    report = builder.call(week)

    expect(report).to be_insufficient_evidence
    expect(report.markdown).to include("Not enough evidence this week")
    expect(llm.calls.map { _1[:schema] }).to eq([ Themes::Finder::SCHEMA ])
  end

  it "marks the report failed, with the reason, when the model call fails" do
    add_thread(1, sync_text)
    add_thread(2, "#{sync_text} again today")
    Embeddings::Embedder.new(model:).call
    Themes::Finder.new(llm:, k: 1).call(week)
    failing = FakeLlm.new { raise Llm::Client::Failed, "cut off" }

    expect { described_class.new(llm: failing, evidence_source: Reports::RagEvidence.new(retriever:)).call(week) }
      .to raise_error(Llm::Client::Failed)
    expect(Report.last).to have_attributes(status: "failed", error: "Llm::Client::Failed: cut off")
  end
end
