module ApplicationHelper
  REFRESH_SECONDS = 5

  # While something runs in the background, reload the page every few
  # seconds so the result appears without anyone pressing refresh.
  def refresh_while(running)
    return unless running

    content_for(:head, tag.meta("http-equiv": "refresh", content: REFRESH_SECONDS))
    tag.p("Working on it. This page refreshes itself every #{REFRESH_SECONDS} seconds until it is done.", class: "notice", role: "status")
  end

  # "2 full weeks (2026-11-09 to 2026-11-22)"
  def weeks_summary(weeks)
    return "no full weeks yet" if weeks.empty?

    range = "#{weeks.last.start.iso8601} to #{(weeks.first.finish - 1).iso8601}"
    "#{pluralize(weeks.size, "full week")} (#{range})"
  end
end
