require "rails_helper"

RSpec.describe Reports::Grounding do
  let(:evidence) do
    Reports::Evidence.new([
      Reports::Evidence::Item.new(id: "E1", chunk_id: 1, post_id: 1, url: "u1", title: "Sync", category: "Help",
                                  date: "2026-11-18", text: "My   deck vanished after the “sync” finished.", theme: 1, history: false)
    ])
  end

  it "counts valid and invalid citations, verbatim and altered quotes, and uncited sentences" do
    content = {
      "overview" => "Sync lost decks [E1].",
      "sections" => [ {
        "body" => "A deck vanished after syncing [E1]. Many people agree [E9]. Nobody knows why.",
        "quotes" => [ { "evidence" => "E1", "text" => "my deck vanished after the \"sync\" finished" },
                      { "evidence" => "E1", "text" => "deck disappeared after sync" } ]
      } ]
    }

    expect(described_class.new(evidence).call(content)).to include(
      "citations" => 3, "citations_valid" => 2, "bad_citations" => [ "E9" ],
      "quotes" => 2, "quotes_verbatim" => 1, "bad_quotes" => [ "deck disappeared after sync" ],
      "sentences" => 3, "sentences_uncited" => 1
    )
  end
end
