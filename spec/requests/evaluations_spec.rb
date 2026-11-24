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
end
