class ReportsController < ApplicationController
  def index
    @weeks = weeks_with_posts
    @reports = Report.latest_first.limit(50).group_by(&:week_start)
    @configured = Llm::Client.new.configured?
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
    week = Week.containing(Date.parse(params.require(:week)))
    GenerateReportJob.perform_later(week.to_param)
    redirect_to reports_path, notice: "Writing the report for #{week}. This takes about a minute; refresh to see it."
  end

  private

  def weeks_with_posts
    Post.where(posted_at: ..Week.last_complete.finish.in_time_zone).distinct
        .pluck(Arel.sql("date_trunc('week', posted_at)::date")).sort.reverse.map { Week.new(start: _1) }
  end
end
