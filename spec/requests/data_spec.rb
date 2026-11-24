require "rails_helper"

RSpec.describe "Data tab", type: :request do
  around { |ex| travel_to(Time.zone.parse("2026-11-24 12:00")) { ex.run } }

  it "says there is no data yet, everywhere" do
    get search_path

    expect(response.body).to include("No forum data yet")
  end

  it "shows what is stored per week and a crawl button defaulting to 12 weeks" do
    create_post(raw: "a Monday post", posted_at: Time.zone.parse("2026-11-16 01:00"))
    create_post(raw: "a post this week", posted_at: Time.zone.parse("2026-11-23 09:00"))
    get data_path

    expect(response.body).to include("2026-11-16 to 2026-11-22", "complete", "this week, still going", 'value="12"')
    expect(response.body).to include("Forum data: 1 full week (2026-11-16 to 2026-11-22) · 2 posts")
  end

  it "refreshes itself while a crawl runs, and goes back to the Data tab after starting one" do
    expect { post job_runs_path(kind: "ingest", weeks: 12) }.to have_enqueued_job(PipelineJob)
    expect(response).to redirect_to(data_path)

    get data_path
    expect(response.body).to include('http-equiv="refresh"', "Working on it")
  end
end
