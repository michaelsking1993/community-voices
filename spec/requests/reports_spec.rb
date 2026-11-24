require "rails_helper"

RSpec.describe "Reports", type: :request do
  let!(:post_record) { create_post(raw: "a post so the week shows up", posted_at: Time.zone.parse("2026-11-16 01:00")) }
  let(:report) do
    Report.create!(
      week_start: Date.new(2026, 11, 16), status: "done", markdown: "# Community Voices\n",
      content: { "headline" => "Sync lost decks.", "overview" => "Decks vanished [E1].",
                 "sections" => [ { "theme" => 1, "title" => "Lost decks", "body" => "Gone after sync [E1] <script>x</script>.",
                                   "quotes" => [ { "evidence" => "E1", "text" => "my deck vanished" } ] } ],
                 "themes" => [ { "position" => 1, "topic_count" => 3, "post_count" => 9, "author_count" => 4 } ] },
      evidence: { "E1" => { "chunk_id" => 1, "post_id" => 1, "url" => "https://forums.ankiweb.net/t/x/1/1", "title" => "Sync",
                            "category" => "Help", "date" => "2026-11-18", "text" => "my deck vanished", "theme" => 1, "history" => false } },
      grounding: { "citations" => 2, "citations_valid" => 2, "quotes" => 1, "quotes_verbatim" => 1 }
    )
  end

  around { |ex| travel_to(Time.zone.parse("2026-11-24 12:00")) { ex.run } }

  it "lists weeks with their reports" do
    report
    get reports_path

    expect(response.body).to include("2026-11-16 to 2026-11-22", report_path(report))
  end

  it "explains what to do and shows weeks without a report" do
    get reports_path

    expect(response.body).to include("press <strong>Write report</strong>", "None yet")
  end

  it "labels A/B reports and refreshes while one is being written" do
    Report.create!(week_start: Date.new(2026, 11, 16), arm: "none", status: "done", content: {})
    Report.create!(week_start: Date.new(2026, 11, 16), arm: "rag", status: "pending")
    get reports_path

    expect(response.body).to include("A/B: no context", "Report · ", "writing…", 'http-equiv="refresh"')
  end

  it "shows a report with citations linked to the forum and model text escaped" do
    get report_path(report)

    expect(response.body).to include("Lost decks", 'href="https://forums.ankiweb.net/t/x/1/1"', "3 threads · 9 posts · 4 people", "2 of 2")
    expect(response.body).not_to include("<script>x</script>")
  end

  it "downloads the Markdown" do
    get report_path(report, format: :md)

    expect(response.body).to eq("# Community Voices\n")
  end

  it "queues a report for a week and says so" do
    expect { post reports_path(week: "2026-11-18") }.to have_enqueued_job(GenerateReportJob).with("2026-11-16")
    expect(response).to redirect_to(reports_path)
    expect(follow_redirect!).to eq(200)
    expect(response.body).to include("Writing the report for 2026-11-16 to 2026-11-22")
  end

  it "lists only weeks the database holds in full" do
    create_post(raw: "the first crawled post, on a Thursday", posted_at: Time.zone.parse("2026-11-12 10:00"))
    get reports_path

    expect(response.body).to include("2026-11-16 to 2026-11-22")
    expect(response.body).not_to include("2026-11-09 to 2026-11-15")
  end

  it "refuses a week that is not a date, or has no complete posts" do
    expect { post reports_path(week: "next tuesday") }.not_to have_enqueued_job
    expect(flash[:alert]).to include("is not a date")

    expect { post reports_path(week: "2026-11-25") }.not_to have_enqueued_job
    expect(flash[:alert]).to include("no complete, fully crawled posts")
  end
end
