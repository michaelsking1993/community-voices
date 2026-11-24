module Charts
  # The A/B test as three figures: do the checks pass, what does it cost,
  # and what did the blind judge think.
  class AbCharts
    CHECKS = {
      "Citations point at real posts" => :citations_valid,
      "Quotes found word for word" => :quotes_verbatim,
      "Sentences that cite a source" => ->(row) { row.sentences_uncited && (1 - row.sentences_uncited).round(2) },
      "Support score of cited sentences" => :support_rate
    }.freeze

    def call
      comparison = Ab::Comparison.new
      return [] if comparison.weeks.empty?

      rows = comparison.rows
      [ checks(rows, comparison.weeks.size), cost(rows), judge(rows) ]
    end

    private

    def checks(rows, weeks)
      traces = rows.map do |row|
        values = CHECKS.values.map { |m| (m.respond_to?(:call) ? m.call(row) : row.public_send(m))&.then { _1 * 100 } }
        bar(row.arm, CHECKS.keys, values, text: values.map { _1 ? "#{_1.round}%" : "n/a" })
      end
      Chart.build(id: "ab-checks", title: "Does the report stand on its sources?",
                  caption: "Checks run in code (the first three) and by a judge (the fourth: supported counts 1, partly ½), pooled over #{weeks} week(s). \"n/a\" means the arm had nothing to check: with no posts in the prompt there is nothing to cite or quote.",
                  traces:, layout: { yaxis: { title: "%", range: [ 0, 115 ] }, barmode: "group" })
    end

    def cost(rows)
      traces = rows.map do |row|
        bar(row.arm, [ "Cost per report ($)" ], [ row.cost_usd ], text: [ "$#{row.cost_usd}  ·  #{number(row.input_tokens)} tokens in  ·  #{row.seconds}s" ])
      end
      Chart.build(id: "ab-cost", title: "What does each report cost?",
                  caption: "Average per report at the model's list price. Pasting the whole week sends every post every time; RAG sends the few that matter.",
                  traces:, layout: { yaxis: { title: "US dollars", range: [ 0, (rows.filter_map(&:cost_usd).max.to_f * 1.3).round(3) ] }, barmode: "group" })
    end

    def judge(rows)
      traces = rows.map do |row|
        values = Ab::Ranker::DIMENSIONS.map { row.scores[_1] }
        bar(row.arm, Ab::Ranker::DIMENSIONS.map(&:capitalize), values, text: values.map { _1 || "" })
      end
      wins = rows.map { "#{Palette::ARM_LABELS[_1.arm]} #{_1.wins}" }.join(", ")
      Chart.build(id: "ab-judge", title: "How did a blind judge score them?",
                  caption: "Scores from 1 to 5, averaged over weeks. The judge saw the reports shuffled and unlabelled, with exact facts about the week. First place: #{wins}. An LLM judge is a second opinion, not ground truth.",
                  traces:, layout: { yaxis: { title: "score (1-5)", range: [ 0, 5.3 ] }, barmode: "group" })
    end

    def bar(arm, x, y, text:)
      { type: "bar", name: Palette::ARM_LABELS.fetch(arm), x:, y:, text:, textposition: "outside", marker: { color: Palette::ARM_COLORS.fetch(arm) } }
    end

    def number(value) = value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
  end
end
