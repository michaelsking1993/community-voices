require "rails_helper"

RSpec.describe PipelineJob do
  let(:run) { JobRun.create!(kind: "retrieval_eval") }

  it "stores what the task printed" do
    allow_any_instance_of(Pipeline::Runner).to receive(:call).with("retrieval_eval", weeks: nil).and_return("hit rate 0.9")
    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "done", summary: "hit rate 0.9")
    expect(run.finished_at).to be_present
  end

  it "stores the error instead of raising" do
    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "failed")
    expect(run.error).to include("Pipeline::Error")
  end
end
