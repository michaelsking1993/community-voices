class ReportsController < ApplicationController
  def index
    @weeks = Ingest::Status.new.rows.select { _1.state == "full" }
    @reports = Report.latest_first.limit(50).group_by(&:week_start)
    @writing = Report.where(status: "pending", created_at: 15.minutes.ago..).exists?
    @configured = Llm.client.configured?
  end

  def show
    @report = Report.find(params[:id])
    @evidence = Reports::Evidence.from_h(@report.evidence)
    respond_to do |format|
      format.html
      format.md { send_data @report.markdown, filename: "community-voices-#{@report.week_start}.md", type: :md }
    end
  end

  def create
    week = Week.containing(Date.iso8601(params.require(:week)))
    return redirect_to(reports_path, alert: "There are no complete, fully crawled posts for #{week}.") unless weeks_with_posts.include?(week)

    GenerateReportJob.perform_later(week.to_param)
    redirect_to reports_path, notice: "Writing the report for #{week}. This takes about a minute."
  rescue Date::Error
    redirect_to reports_path, alert: "#{params[:week].inspect} is not a date."
  end

  private

  # Complete weeks the database holds in full: not this week, and not a
  # partly crawled first week.
  def weeks_with_posts = Ingest::Status.new.full_weeks
end
