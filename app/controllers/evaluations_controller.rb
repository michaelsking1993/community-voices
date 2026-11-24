# The Evaluate tab: buttons for the four long tasks, and what each last did.
class EvaluationsController < ApplicationController
  def show
    @kinds = JobRun::KINDS
    @configured = Llm.client.configured?
    @last = JobRun.latest_first.group_by(&:kind).transform_values(&:first)
    @pending = JobRun.exists?(status: %w[queued running])
  end

  def create
    kind = JobRun.kind(params[:kind])
    return redirect_to(evaluation_path, alert: "Unknown task.") unless kind
    return redirect_to(evaluation_path, alert: "Set LLM_API_KEY in .env first: #{kind.label} calls the LLM.") if kind.needs_llm && !Llm.client.configured?
    return redirect_to(evaluation_path, alert: "#{kind.label} is already running.") if JobRun.active?(kind.key)

    weeks = kind.weeks ? params[:weeks].to_i.clamp(kind.weeks.begin, kind.weeks.end) : nil
    run = JobRun.create!(kind: kind.key, weeks:)
    PipelineJob.perform_later(run.id)
    redirect_to evaluation_path, notice: "Started: #{kind.label}. Refresh in a moment to see the result."
  end
end
