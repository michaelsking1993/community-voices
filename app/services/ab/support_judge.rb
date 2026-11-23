module Ab
  # Does each cited sentence follow from the posts it cites?
  #
  # Code already checks that citations point at real posts and quotes are
  # word for word (Reports::Grounding). It cannot check that a sentence
  # means what its source says. That is this judge's one job: for each
  # sentence with a citation, read the cited posts and say supported,
  # partly or unsupported.
  #
  # Sentences whose citations are all invalid are "unsupported" without
  # asking. A report with no citations at all costs no model call.
  class SupportJudge
    MAX_SENTENCES = 30
    VERDICTS = %w[supported partly unsupported].freeze
    SENTENCE_END = /(?<=[.!?])\s+(?=[A-Z])/

    SYSTEM = <<~PROMPT.freeze
      You check whether sentences from a report follow from the forum posts they cite.

      For each sentence, read only the cited posts, then answer:
      - supported: the posts say or clearly show what the sentence says, including any number or comparison in it.
      - partly: the posts support part of the sentence, or the sentence says more than they show.
      - unsupported: the posts do not say it, or say something different.

      Judge from the cited posts only, never from your own knowledge. The note is one short sentence.
    PROMPT

    SCHEMA = { type: "object", additionalProperties: false, required: %w[claims],
               properties: { claims: { type: "array", items: {
                 type: "object", additionalProperties: false, required: %w[claim verdict note],
                 properties: { claim: { type: "integer" }, verdict: { type: "string", enum: VERDICTS }, note: { type: "string" } } } } } }.freeze

    def initialize(llm: Llm.client) = @llm = llm

    def call(report)
      evidence = Reports::Evidence.from_h(report.evidence)
      sentences = cited_sentences(report.content)
      askable, orphans = sentences.partition { |s| s[:ids].any? { evidence[_1] } }
      response = askable.any? ? @llm.json(system: SYSTEM, prompt: prompt(askable, evidence), schema: SCHEMA) : nil
      Judgement.record(kind: "support", week_start: report.week_start, report:, response:,
                       data: summarise(askable, orphans, response&.data, sentences.size))
    end

    private

    def cited_sentences(content)
      texts = [ content["overview"], *content.fetch("sections", []).map { _1["body"] }, *content.fetch("predictions", []).map { _1["reasoning"] } ]
      all = texts.compact.flat_map { _1.split(SENTENCE_END) }.select { _1.match?(Reports::Grounding::CITATION) }
      step = (all.size.to_f / MAX_SENTENCES).ceil
      all = all.each_slice(step).map(&:first) if step > 1
      all.map { |text| { text:, ids: text.scan(Reports::Grounding::CITATION).flatten.uniq } }
    end

    def prompt(sentences, evidence)
      sentences.each_with_index.map do |sentence, i|
        posts = sentence[:ids].filter_map { evidence[_1]&.to_prompt }
        "## Sentence #{i + 1}\n#{sentence[:text]}\n\nCited posts:\n#{posts.join("\n\n")}"
      end.join("\n\n")
    end

    def summarise(askable, orphans, data, total_cited)
      judged = askable.each_with_index.map do |sentence, i|
        verdict = data["claims"].find { _1["claim"] == i + 1 }
        { "sentence" => sentence[:text], "verdict" => verdict&.fetch("verdict") || "unsupported", "note" => verdict&.fetch("note") }
      end
      judged += orphans.map { { "sentence" => _1[:text], "verdict" => "unsupported", "note" => "cites nothing that exists" } }
      counts = VERDICTS.index_with { |v| judged.count { _1["verdict"] == v } }
      { "claims" => judged, "counts" => counts, "cited_sentences" => total_cited,
        "support_rate" => judged.empty? ? nil : ((counts["supported"] + (0.5 * counts["partly"])) / judged.size).round(2) }
    end
  end
end
