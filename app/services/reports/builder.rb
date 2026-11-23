module Reports
  # Writes one week's Community Voices report:
  #
  # 1. Themes     the week's themes (found now if not stored yet)
  # 2. Evidence   numbered chunks per theme, from an evidence source
  #               (RagEvidence here; the A/B step swaps in other arms)
  # 3. Write      one structured-output call: headline, overview, a section
  #               per theme with cited claims and word-for-word quotes
  # 4. Check      Grounding verifies every citation and quote in code
  # 5. Save       a Report with content, evidence, checks, tokens and cost
  #
  # With no evidence at all, it makes no model call and says so.
  class Builder
    THEMES = 6      # themes covered, biggest first
    MIN_THREADS = 2 # a "theme" of one thread is not a theme

    SYSTEM = <<~PROMPT.freeze
      You write "Community Voices", a weekly report on what people said in the Anki forums (forums.ankiweb.net), for the people who build Anki.

      Rules:
      - Use only the evidence given. Do not add facts from memory, even true ones.
      - After every claim, cite the evidence it rests on with ids in square brackets, e.g. "Several iPhone users lost the toolbar after 26.10 [E3][E5]."
      - Quotes: copy 1 or 2 quotes per section word for word from one evidence item, 5 to 30 words each. Do not fix spelling or translate.
      - Numbers: use only the counts given. Do not estimate, add up or invent percentages.
      - Say how widespread something is from the counts and the evidence ("one person", "several threads"). If the evidence is thin or mixed, say so.
      - Evidence from earlier weeks is context: use it to say whether something is new or recurring, and cite it when you do.
      - Plain, specific language. No marketing tone and no advice to forum users.

      Write a headline (one sentence), an overview (2 to 3 sentences on the week as a whole), and one section per theme, in the order given. Each section has a short title, a body of 2 to 4 sentences, and its quotes.
    PROMPT

    QUOTE = { type: "object", additionalProperties: false, required: %w[evidence text],
              properties: { evidence: { type: "string" }, text: { type: "string" } } }.freeze
    SECTION = { type: "object", additionalProperties: false, required: %w[theme title body quotes],
                properties: { theme: { type: "integer" }, title: { type: "string" }, body: { type: "string" },
                              quotes: { type: "array", items: QUOTE } } }.freeze
    SCHEMA = { type: "object", additionalProperties: false, required: %w[headline overview sections],
               properties: { headline: { type: "string" }, overview: { type: "string" },
                             sections: { type: "array", items: SECTION } } }.freeze

    def initialize(llm: Llm::Client.new, evidence_source: RagEvidence.new, theme_finder: nil, arm: "rag")
      @llm = llm
      @evidence_source = evidence_source
      @theme_finder = theme_finder || Themes::Finder.new(llm:)
      @arm = arm
    end

    def call(week)
      report = Report.create!(week_start: week.start, arm: @arm)
      themes = themes_for(week)
      evidence = @evidence_source.call(week, themes)
      Retrieval.where(id: Array(@evidence_source.try(:retrievals)).map(&:id)).update_all(report_id: report.id)
      covered = themes.select { |t| evidence.for_theme(t.position).any? }

      content, response = covered.empty? ? [ not_enough_evidence, nil ] : write(week, covered, evidence)
      content = content.merge("themes" => covered.map { snapshot(_1) },
                              "thin_themes" => (themes - covered).map { snapshot(_1) })
      save(report, content, evidence, response)
    rescue StandardError => e
      report&.update!(status: "failed", error: "#{e.class}: #{e.message}")
      raise
    end

    private

    def themes_for(week)
      themes = Theme.for_week(week).to_a
      themes = @theme_finder.call(week) if themes.empty?
      themes.select { _1.topic_count >= MIN_THREADS }.first(THEMES)
    end

    def write(week, themes, evidence)
      response = @llm.json(system: SYSTEM, prompt: prompt(week, themes, evidence), schema: SCHEMA)
      [ response.data, response ]
    end

    def prompt(week, themes, evidence)
      facts = WeekFacts.new
      [ "Week: #{week}", facts.to_prompt(facts.call(week)), "# Themes, biggest first",
        *themes.map { theme_block(_1, evidence) } ].join("\n\n")
    end

    def theme_block(theme, evidence)
      history = evidence.for_theme(theme.position, history: true)
      [ "## Theme #{theme.position}: #{theme.label} [#{theme.kind}] (#{theme.topic_count} threads, #{theme.post_count} posts, #{theme.author_count} people)",
        "What the clustering step saw: #{theme.summary}",
        "Evidence from this week:", *evidence.for_theme(theme.position).map(&:to_prompt),
        *([ "Similar posts from earlier weeks (context):", *history.map(&:to_prompt) ] if history.any?) ].join("\n\n")
    end

    def not_enough_evidence
      { "headline" => "Not enough evidence this week to write a report.", "overview" => "", "sections" => [],
        "insufficient_evidence" => true }
    end

    def snapshot(theme) = theme.slice(:position, :label, :kind, :summary, :topic_count, :post_count, :author_count)

    def save(report, content, evidence, response)
      report.update!(
        status: "done", content:, evidence: evidence.to_h, grounding: Grounding.new(evidence).call(content),
        markdown: Markdown.new.call(report.week, content, evidence),
        model: response&.model, input_tokens: response&.input_tokens, output_tokens: response&.output_tokens,
        cost_usd: response&.cost_usd, duration_ms: response&.duration_ms
      )
      report
    end
  end
end
