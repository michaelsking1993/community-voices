# Starts one of the long tasks (crawl, retrieval eval, A/B test, backtest)
# in the background, then sends you back to the tab the button was on.
class JobRunsController < ApplicationController
  def create
    kind = JobRun.kind(params[:kind])
    return redirect_to(evaluation_path, alert: "Unknown task.") unless kind

    back = kind.key == "ingest" ? data_path : evaluation_path
    return redirect_to(back, alert: "Set LLM_API_KEY in .env first: #{kind.label} calls the LLM.") if kind.needs_llm && !Llm.client.configured?
    return redirect_to(back, alert: "#{kind.label} is already running.") if JobRun.active?(kind.key)

    weeks = kind.weeks ? params[:weeks].to_i.clamp(kind.weeks.begin, kind.weeks.end) : nil
    run = JobRun.create!(kind: kind.key, weeks:)
    PipelineJob.perform_later(run.id)
    redirect_to back, notice: "Started: #{kind.label}. This page refreshes itself until it is done."
  end
end
