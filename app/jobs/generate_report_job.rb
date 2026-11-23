# Writes a week's report in the background, so the "Write report" button
# returns at once. Failures are saved on the report itself.
class GenerateReportJob < ApplicationJob
  queue_as :default
  discard_on Llm::NotConfigured

  def perform(week_start)
    Reports::Builder.new.call(Week.containing(Date.parse(week_start)))
  end
end
