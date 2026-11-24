require "rails_helper"

RSpec.describe "Evaluate tab", type: :request do
  let(:configured) { instance_double(Llm::Anthropic, configured?: true) }

  it "shows a button for every task" do
    get evaluation_path

    expect(response.body).to include("Retrieval eval", "A/B test", "Backtest")
    expect(response.body).not_to include(%(value="Crawl the forum"))
  end

  it "queues a crawl and records it" do
    expect { post job_runs_path(kind: "ingest", weeks: 99) }.to have_enqueued_job(PipelineJob)

    expect(JobRun.last).to have_attributes(kind: "ingest", weeks: 12, status: "queued")
    expect(flash[:notice]).to include("Started")
  end

  it "refuses an LLM task without a key" do
    allow(Llm).to receive(:client).and_return(instance_double(Llm::Anthropic, configured?: false))

    expect { post job_runs_path(kind: "ab", weeks: 1) }.not_to have_enqueued_job
    expect(flash[:alert]).to include("LLM_API_KEY")
  end

  it "queues an LLM task when a key is set" do
    allow(Llm).to receive(:client).and_return(configured)

    expect { post job_runs_path(kind: "backtest", weeks: 1) }.to have_enqueued_job(PipelineJob)
    expect(JobRun.last.weeks).to eq(2)
  end

  it "does not start a task that is already running" do
    JobRun.create!(kind: "ingest", weeks: 2, status: "running")

    expect { post job_runs_path(kind: "ingest", weeks: 2) }.not_to have_enqueued_job
    expect(flash[:alert]).to include("already running")
  end

  it "rejects an unknown task" do
    expect { post job_runs_path(kind: "rm_rf") }.not_to have_enqueued_job
    expect(flash[:alert]).to eq("Unknown task.")
  end

  it "disables a task until there is enough data, and says why" do
    allow(Llm).to receive(:client).and_return(configured)
    get evaluation_path

    expect(response.body).to include("Needs 6 full weeks of data; you have 0", "Needs 12 full weeks of data; you have 0")
  end

  it "shows the last result" do
    JobRun.create!(kind: "retrieval_eval", status: "done", summary: "hit rate 0.93")
    get evaluation_path

    expect(response.body).to include("hit rate 0.93")
  end

  it "shows A/B results as a table with a verdict and the judge's notes" do
    week = Date.new(2026, 11, 16)
    reports = { "rag" => [ 0.18, 20_000 ], "paste_all" => [ 0.36, 62_000 ], "none" => [ 0.03, 1_000 ] }.to_h do |arm, (cost, tokens)|
      [ arm, Report.create!(week_start: week, arm:, status: "done", content: {}, cost_usd: cost, input_tokens: tokens,
                            grounding: { "citations" => 10, "citations_valid" => 10, "sentences" => 10, "sentences_uncited" => 2 }) ]
    end
    scores = reports.to_h { |arm, r| [ arm, { "coverage" => 4, "accuracy" => 3, "specificity" => 4, "usefulness" => 3, "invented" => 0, "note" => "#{arm} note", "report_id" => r.id } ] }
    Judgement.create!(kind: "ranking", week_start: week, data: { "scores" => scores, "ranking" => %w[paste_all rag none] })
    get evaluation_path

    expect(response.body).to include("RAG cost $0.18 per report against $0.36", "2.0x cheaper", "Paste the whole week 1",
                                     "Cited claims the post really supports", "rag note", "3.0 / 5")
  end

  it "shows backtest and retrieval eval results as tables" do
    Judgement.create!(kind: "prediction", week_start: Date.new(2026, 11, 16),
                      data: { "results" => [ { "verdict" => "happened", "confidence" => "high", "basis" => "trend" },
                                             { "verdict" => "did_not_happen", "confidence" => "low", "basis" => "event" } ] })
    JobRun.create!(kind: "retrieval_eval", status: "done", summary: "raw",
                   data: { "configs" => [ { "config" => "max 2 per thread", "queries" => 15, "hit_rate" => 0.93, "recall" => 0.61, "threads" => 6.2 } ],
                           "off_topic_empty_rate" => 1.0, "off_topic_queries" => 4 })
    get evaluation_path

    expect(response.body).to include("1 of 2 predictions came true", "By the confidence the report claimed",
                                     "Found at least one right thread", "93%", "100% of 4 off-topic questions")
  end
end
