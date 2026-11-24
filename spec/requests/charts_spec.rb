require "rails_helper"

RSpec.describe "Charts page", type: :request do
  it "explains how to fill each section when there is no data yet" do
    get charts_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Run the A/B test on the Evaluate tab", "Run the backtest", "Crawl the forum on the Data tab", "Retrieval stats")
  end

  it "hands each figure to the Plotly Stimulus controller as JSON" do
    Judgement.create!(kind: "prediction", week_start: Date.new(2026, 11, 16),
                      data: { "scored_week" => "2026-11-16", "results" => [ { "verdict" => "happened", "confidence" => "high", "basis" => "trend" } ] })
    get charts_path

    expect(response.body).to include('data-controller="plot"', "backtest-confidence", "&quot;type&quot;:&quot;bar&quot;")
  end
end
