require "rails_helper"

RSpec.describe "Search", type: :request do
  before do
    # The controller builds Search::Retriever with its default model; swap in the fake.
    allow(Embeddings::LocalModel).to receive(:instance).and_return(FakeEmbeddingModel.new)
    post = create_post(raw: "sync fails with a network error every time I open the app on my phone today")
    Chunking::Chunker.new.call(post)
    Embeddings::Embedder.new(model: FakeEmbeddingModel.new).call
  end

  it "shows the search box and works without an LLM key" do
    get search_path

    expect(response.body).to include("Search by meaning", 'name="q"')
  end

  it "lists hits with title, category, date, distance and a forum link" do
    get search_path(q: "sync network error phone")

    expect(response.body).to include("Sync keeps failing", "Syncing &amp; AnkiWeb", "distance", "https://forums.ankiweb.net/t/sync-keeps-failing/1/")
    expect(Retrieval.last.purpose).to eq("search")
  end

  it "says so when nothing is close enough" do
    get search_path(q: "zebra quantum pancake")

    expect(response.body).to include("Nothing within distance")
  end

  it "ignores a blank query" do
    expect { get search_path(q: "  ") }.not_to change(Retrieval, :count)
    expect(response).to have_http_status(:ok)
  end
end
