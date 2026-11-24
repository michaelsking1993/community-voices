# The Evaluate tab: buttons for the three evaluations, and what each last did.
class EvaluationsController < ApplicationController
  def show
    @kinds = JobRun::KINDS.reject { _1.key == "ingest" }
    @configured = Llm.client.configured?
    @full_weeks = Ingest::Status.new.full_weeks.size
    @last = JobRun.latest_first.group_by(&:kind).transform_values(&:first)
  end
end
