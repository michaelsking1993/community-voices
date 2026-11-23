module Reports
  # Checks a report against its evidence, in code, not by asking a model:
  #
  #   citations   every [E3] in the text points at real evidence
  #   quotes      every quote appears word for word in the item it cites
  #   uncited     sentences in theme sections with no citation at all
  #
  # The A/B step compares arms on these numbers.
  class Grounding
    CITATION = /\[(E\d+)\]/

    def initialize(evidence) = @evidence = evidence

    def call(content)
      texts = [ content["overview"], *content.fetch("sections", []).map { _1["body"] },
                *content.fetch("predictions", []).map { _1["reasoning"] } ].compact
      cited = texts.flat_map { _1.scan(CITATION).flatten }
      quotes = content.fetch("sections", []).flat_map { _1.fetch("quotes", []) }
      {
        "citations" => cited.size,
        "citations_valid" => cited.count { @evidence[_1] },
        "quotes" => quotes.size,
        "quotes_verbatim" => quotes.count { verbatim?(_1) },
        "sentences" => sentences(content).size,
        "sentences_uncited" => sentences(content).count { _1 !~ CITATION },
        "bad_citations" => cited.reject { @evidence[_1] }.uniq,
        "bad_quotes" => quotes.reject { verbatim?(_1) }.map { _1["text"] }
      }
    end

    private

    def verbatim?(quote)
      item = @evidence[quote["evidence"]]
      item.present? && squish(item.text).include?(squish(quote["text"]))
    end

    def sentences(content)
      content.fetch("sections", []).flat_map { _1["body"].to_s.split(/(?<=[.!?])\s+(?=[A-Z])/) }.map(&:strip).reject(&:blank?)
    end

    # Ignore case, curly quotes and spacing; everything else must match.
    def squish(text) = text.to_s.tr("‘’“”", "''\"\"").downcase.gsub(/\s+/, " ").strip
  end
end
