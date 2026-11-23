module Reports
  # Writes one week's Community Voices report:
  #
  # 1. Themes     the week's themes (found now if not stored yet)
  # 2. Evidence   numbered chunks per theme, from an evidence source
  #               (RagEvidence here; the A/B step swaps in other arms)
  # 3. Write      one structured-output LLM call: headline, overview, a
  #               section per theme with cited claims and word-for-word
  #               quotes, and predictions for next week with cited reasons
  # 4. Check      Grounding verifies every citation and quote in code
  # 5. Save       a Report with content, evidence, checks, tokens and cost
  #
  # With no evidence at all, it makes no LLM call and says so.
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

      Then predict 3 to 5 things the forum will discuss next week. Each prediction:
      - claim: one sentence someone could check against next week's posts, e.g. "Threads about AnkiMobile toolbar changes will keep coming but fewer than this week."
      - reasoning: why, citing evidence ids, using the weekly trend counts, the earlier-weeks evidence, and any releases or betas listed.
      - basis: "trend" (the counts), "recurring" (it came up before), or "event" (a release, beta or announcement).
      - confidence: low, medium or high. Use high only when several signals agree.
      - theme: the theme number it is about, or 0 if none.
      Do not predict anything you have no signal for. If there is no signal for next week, return no predictions.
    PROMPT

    # The no-context arm: the same job with nothing attached, i.e. what you
    # get from just asking an LLM. Same JSON shape, so the same checks run.
    SYSTEM_PLAIN = <<~PROMPT.freeze
      You write "Community Voices", a weekly report on what people said in the Anki forums (forums.ankiweb.net), for the people who build Anki.

      You have not been given this week's posts. Write the best report you can from what you know, and say plainly when something is a guess.

      Write a headline (one sentence), an overview (2 to 3 sentences) and 3 to 6 sections, each with a short title and a body of 2 to 4 sentences. Use theme 0 for every section and leave quotes empty: you have no posts to quote.

      Then predict 3 to 5 things the forum will discuss next week. Each prediction: a claim someone could check against next week's posts, your reasoning in plain words (no citations: there is no evidence to cite), a basis (trend, recurring or event), a confidence (low, medium or high) and theme 0.
    PROMPT

    QUOTE = { type: "object", additionalProperties: false, required: %w[evidence text],
              properties: { evidence: { type: "string" }, text: { type: "string" } } }.freeze
    SECTION = { type: "object", additionalProperties: false, required: %w[theme title body quotes],
                properties: { theme: { type: "integer" }, title: { type: "string" }, body: { type: "string" },
                              quotes: { type: "array", items: QUOTE } } }.freeze
    PREDICTION = { type: "object", additionalProperties: false, required: %w[claim reasoning basis confidence theme],
                   properties: { claim: { type: "string" }, reasoning: { type: "string" },
                                 basis: { type: "string", enum: %w[trend recurring event] },
                                 confidence: { type: "string", enum: %w[low medium high] }, theme: { type: "integer" } } }.freeze
    SCHEMA = { type: "object", additionalProperties: false, required: %w[headline overview sections predictions],
               properties: { headline: { type: "string" }, overview: { type: "string" },
                             sections: { type: "array", items: SECTION }, predictions: { type: "array", items: PREDICTION } } }.freeze

    # grounded: false is the no-context arm: no themes, counts or evidence,
    # just the week's dates.
    def initialize(llm: Llm.client, evidence_source: RagEvidence.new, theme_finder: nil, arm: "rag", grounded: true)
      @llm = llm
      @evidence_source = evidence_source
      @theme_finder = theme_finder || Themes::Finder.new(llm:)
      @arm = arm
      @grounded = grounded
    end

    def call(week)
      report = Report.create!(week_start: week.start, arm: @arm)
      themes = @grounded ? themes_for(week) : []
      evidence = @evidence_source.call(week, themes)
      Retrieval.where(id: Array(@evidence_source.try(:retrievals)).map(&:id)).update_all(report_id: report.id)
      covered = themes.select { |t| evidence.whole_week.any? || evidence.for_theme(t.position).any? }

      content, response = @grounded && covered.empty? ? [ not_enough_evidence, nil ] : write(week, covered, evidence)
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
      response = @llm.json(system: @grounded ? SYSTEM : SYSTEM_PLAIN, prompt: prompt(week, themes, evidence), schema: SCHEMA)
      [ response.data, response ]
    end

    def prompt(week, themes, evidence)
      return "Week: #{week}" unless @grounded

      facts = WeekFacts.new
      [ "Week: #{week}", facts.to_prompt(facts.call(week)), "# Themes, biggest first",
        *themes.map { theme_block(_1, evidence) }, *whole_week_block(evidence), *signals_block(week, evidence) ].join("\n\n")
    end

    # The paste-all arm: every post of the week, unsorted, after the themes.
    def whole_week_block(evidence)
      posts = evidence.whole_week
      posts.any? ? [ "# Every post from this week, grouped by thread", *posts.map(&:to_prompt) ] : []
    end

    def signals_block(week, evidence)
      events = evidence.for_theme(0)
      lines = [ "# Signals for next week (#{week.next})" ]
      if evidence.signals.any?
        lines << "Posts per week close to each theme (approximate: a trend signal, not an exact count), oldest first, the last number is this week:\n#{evidence.signals.join("\n")}"
      end
      lines.push("Releases, betas and announcements active in the last two weeks:", *events.map(&:to_prompt)) if events.any?
      lines.size > 1 ? lines : []
    end

    def theme_block(theme, evidence)
      history = evidence.for_theme(theme.position, history: true)
      [ "## Theme #{theme.position}: #{theme.label} [#{theme.kind}] (#{theme.topic_count} threads, #{theme.post_count} posts, #{theme.author_count} people)",
        "What the clustering step saw: #{theme.summary}",
        *evidence_lines(theme, evidence),
        *([ "Similar posts from earlier weeks (context):", *history.map(&:to_prompt) ] if history.any?) ].join("\n\n")
    end

    def evidence_lines(theme, evidence)
      return [ "Evidence: find it in the posts listed below." ] if evidence.whole_week.any?

      [ "Evidence from this week:", *evidence.for_theme(theme.position).map(&:to_prompt) ]
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
