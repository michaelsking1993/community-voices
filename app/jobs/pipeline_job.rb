# Runs one JobRun in the background and records what it printed or why it failed.
class PipelineJob < ApplicationJob
  queue_as :default

  def perform(job_run_id)
    run = JobRun.find(job_run_id)
    run.update!(status: "running", started_at: Time.current)
    runner = Pipeline::Runner.new
    summary = runner.call(run.kind, weeks: run.weeks)
    run.update!(status: "done", summary:, data: runner.data, finished_at: Time.current)
  rescue StandardError => e
    run&.update!(status: "failed", error: "#{e.class}: #{e.message}", finished_at: Time.current)
  end
end
