module ReportsHelper
  # Turns [E3] citations into numbered links to the forum post.
  def with_citations(text, evidence)
    parts = h(text.to_s).gsub(Reports::Grounding::CITATION) do
      item = evidence[$1]
      item ? link_to("[#{$1.delete_prefix("E")}]", item.url, class: "cite", title: "#{item.title} (#{item.date})") : "[#{$1}?]"
    end
    parts.html_safe # rubocop:disable Rails/OutputSafety -- text is escaped above; only our links are added
  end

  ARM_LABELS = { "rag" => "Report", "paste_all" => "A/B: paste the whole week", "none" => "A/B: no context" }.freeze

  # "Report · Nov 24 14:02", or the A/B arm it came from.
  def report_label(report) = "#{ARM_LABELS.fetch(report.arm, report.arm)} · #{l(report.created_at, format: :short)}"
end
