require "rails_helper"

RSpec.describe "Flashcards", type: :request do
  let(:cards) { Rails.application.config_for(:flashcards).fetch(:cards) }

  it "ships a complete deck" do
    expect(cards.size).to be >= 30
    expect(cards).to all(include(:term, :meaning, :where))
    expect(cards.map { |c| c[:term] }).to eq(cards.map { |c| c[:term] }.uniq)
  end

  it "renders every card with its back, and the study controls" do
    get flashcards_path

    expect(response).to have_http_status(:ok)
    expect(response.body.scan("data-flashcards-target=\"card\"").size).to eq(cards.size)
    expect(response.body).to include("Grounded", "Shuffle", "Reset", "What it means")
  end

  it "shows backticked text as code, escaped" do
    get flashcards_path

    expect(response.body).to include("<code>Reports::Grounding</code>")
    expect(response.body).not_to include("`")
  end
end
