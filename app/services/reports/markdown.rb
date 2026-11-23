module Reports
  # Renders a report as Markdown: citations become numbered links to the
  # forum post, quotes become block quotes, and a sources list closes it.
  class Markdown
    def call(week, content, evidence)
      [ "# Community Voices: Anki forums, #{week}", "_#{content["headline"]}_", link(content["overview"], evidence),
        *content.fetch("sections", []).each_with_index.map { |s, i| section(s, i, content, evidence) },
        *predictions(content, evidence), *thin(content), sources(content, evidence) ]
        .compact_blank.join("\n\n") + "\n"
    end

    private

    def section(section, index, content, evidence)
      theme = content.fetch("themes", []).find { _1["position"] == section["theme"] }
      counts = theme && "_#{theme["topic_count"]} threads · #{theme["post_count"]} posts · #{theme["author_count"]} people_"
      quotes = section.fetch("quotes", []).map do |q|
        item = evidence[q["evidence"]]
        "> \"#{q["text"]}\"#{" ([#{item.title}](#{item.url}))" if item}"
      end
      [ "## #{index + 1}. #{section["title"]}", counts, link(section["body"], evidence), *quotes ].compact.join("\n\n")
    end

    def predictions(content, evidence)
      list = content.fetch("predictions", [])
      return [] if list.empty?

      [ "## Next week", list.map { |p| "- **#{p["claim"]}** (#{p["confidence"]} confidence) #{link(p["reasoning"], evidence)}" }.join("\n") ]
    end

    def thin(content)
      list = content.fetch("thin_themes", [])
      return [] if list.empty?

      [ "## Not enough evidence", list.map { "- #{_1["label"]} (#{_1["topic_count"]} threads): nothing close enough to cite." }.join("\n") ]
    end

    def sources(content, evidence)
      cited = content.to_json.scan(Grounding::CITATION).flatten.uniq
      lines = evidence.items.select { cited.include?(_1.id) }.map { "- [#{number(_1.id)}] [#{_1.title}](#{_1.url}), #{_1.date}" }
      lines.any? ? "## Sources\n\n#{lines.join("\n")}" : nil
    end

    def link(text, evidence)
      text.to_s.gsub(Grounding::CITATION) do
        item = evidence[$1]
        item ? "[[#{number($1)}]](#{item.url})" : "[#{$1}?]"
      end
    end

    def number(id) = id.delete_prefix("E")
  end
end
