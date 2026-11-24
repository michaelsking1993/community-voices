# The Evaluate tab: buttons for the three evaluations, and what each last did.
class EvaluationsController < ApplicationController
  def show
    @kinds = JobRun::KINDS.reject { _1.key == "ingest" }
    @configured = Llm.client.configured?
    @full_weeks = Ingest::Status.new.full_weeks.size
    @last = JobRun.latest_first.group_by(&:kind).transform_values(&:first)
    @ab = Ab::Comparison.new.then { _1.weeks.any? ? _1 : nil }
    predictions = Judgement.of_kind("prediction")
    @backtest = Backtest::Summary.new(predictions) if predictions.exists?
    @retrieval = @last["retrieval_eval"]&.data
  end
end
