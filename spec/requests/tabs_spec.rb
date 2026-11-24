require "rails_helper"

RSpec.describe "Tabs", type: :request do
  it "shows every tab and marks the current one" do
    get search_path

    expect(response.body).to include("Community report", "Search", "Charts", "Flashcards")
    expect(response.body).to match(%r{<a aria-current="page" href="/search">Search</a>})
  end

  it "keeps a single report under the Community report tab" do
    get root_path

    expect(response.body).to match(%r{<a aria-current="page" href="/">Community report</a>})
  end

  it "renders the flashcards placeholder" do
    get flashcards_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Coming soon")
  end
end
