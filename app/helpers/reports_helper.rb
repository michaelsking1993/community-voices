module ReportsHelper
  # Turns [E3] citations into numbered links to the forum post.
  def with_citations(text, evidence)
    parts = h(text.to_s).gsub(Reports::Grounding::CITATION) do
      item = evidence[$1]
      item ? link_to("[#{$1.delete_prefix("E")}]", item.url, class: "cite", title: "#{item.title} (#{item.date})") : "[#{$1}?]"
    end
    parts.html_safe # rubocop:disable Rails/OutputSafety -- text is escaped above; only our links are added
  end
end
