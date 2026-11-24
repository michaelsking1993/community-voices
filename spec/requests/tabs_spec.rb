require "rails_helper"

RSpec.describe "Tabs", type: :request do
  it "shows every tab and marks the current one" do
    get search_path

    expect(response.body).to include("Community report", "Search", "Charts", "Flashcards")
    expect(response.body).to match(%r{<a aria-current="page" href="/search">Search</a>})
  end

  it "puts Data right after Community report" do
    get root_path

    labels = Nokogiri::HTML(response.body).css("nav.tabs a").map(&:text)
    expect(labels.first(3)).to eq([ "Community report", "Data", "Search" ])
  end

  it "keeps a single report under the Community report tab" do
    get root_path

    expect(response.body).to match(%r{<a aria-current="page" href="/">Community report</a>})
  end
end
