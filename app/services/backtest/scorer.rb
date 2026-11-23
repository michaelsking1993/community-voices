module Backtest
  # Scores one report's predictions against the week they were about.
  #
  # The report was written using only data from before that week (the
  # builder and its signals never look past the report's own week), so
  # this is the first time the predictions meet the future:
  #
  # 1. Look     for each prediction, retrieve the closest posts of the
  #             following week (this is where we are allowed to peek)
  # 2. Judge    one LLM call: for each prediction, did it happen?
  # 3. Check    in code: a "happened" or "partly" verdict must cite real
  #             evidence, else it is downgraded to "no_evidence"
  # 4. Save     a Judgement of kind "prediction"
  class Scorer
    VERDICTS = %w[happened partly did_not_happen no_evidence].freeze
    CITATION_REQUIRED = %w[happened partly].freeze
    EVIDENCE_PER_PREDICTION = 5

    SYSTEM = <<~PROMPT.freeze
      You check last week's predictions about the Anki forums against what people actually posted the following week.

      For each prediction, pick a verdict:
      - happened: the posts show what the claim said, including any direction or size it gave.
      - partly: some of the claim holds and some does not.
      - did_not_happen: the posts show the opposite, or the posts you were given are about this topic but do not show it.
      - no_evidence: the posts you were given do not let you tell. Use this when no posts were found for the prediction.

      Rules:
      - Judge only from the numbered posts and the exact activity counts given. Do not use your own knowledge.
      - Cite the posts your verdict rests on as ids like "E2". A "happened" or "partly" verdict without a citation is invalid.
      - Do not be kind: score the claim as written, not what the author probably meant.
      - The rationale is one or two plain sentences.
    PROMPT

    SCHEMA = { type: "object", additionalProperties: false, required: %w[results],
               properties: { results: { type: "array", items: {
                 type: "object", additionalProperties: false, required: %w[prediction verdict rationale evidence],
                 properties: { prediction: { type: "integer" }, verdict: { type: "string", enum: VERDICTS },
                               rationale: { type: "string" }, evidence: { type: "array", items: { type: "string" } } } } } } }.freeze

    def initialize(llm: Llm.client, retriever: Search::Retriever.new)
      @llm = llm
      @retriever = retriever
    end

    def call(report)
      raise ArgumentError, "Report ##{report.id} has no predictions" if report.predictions.empty?

      week = report.week.next
      evidence = look(report.predictions, week)
      response = @llm.json(system: SYSTEM, prompt: prompt(report, week, evidence), schema: SCHEMA)
      Judgement.record(kind: "prediction", week_start: report.week_start, report:, response:,
                       data: checked(response.data, report.predictions, evidence).merge("scored_week" => week.start.iso8601))
    end

    private

    def look(predictions, week)
      Reports::Evidence.new.tap do |evidence|
        predictions.each_with_index do |prediction, i|
          found = @retriever.call(prediction["claim"], window: week.range, k: EVIDENCE_PER_PREDICTION, per_topic: 1, purpose: "backtest")
          found.chunks.each { evidence.add(_1, theme: i + 1) }
        end
      end
    end

    def prompt(report, week, evidence)
      facts = Reports::WeekFacts.new
      [ "Predictions were made about the week #{week}.", facts.to_prompt(facts.call(week)),
        *report.predictions.each_with_index.map { |p, i| block(p, i + 1, evidence) } ].join("\n\n")
    end

    def block(prediction, number, evidence)
      posts = evidence.for_theme(number).map(&:to_prompt)
      [ "## Prediction #{number}: #{prediction["claim"]}", "(basis: #{prediction["basis"]}, confidence: #{prediction["confidence"]})",
       posts.any? ? "Posts from that week closest to the claim:\n\n#{posts.join("\n\n")}" : "No posts that week were close to this claim." ].join("\n")
    end

    # Drops results for unknown predictions and demotes verdicts that cite nothing real.
    def checked(data, predictions, evidence)
      results = data["results"].filter_map do |result|
        next unless result["prediction"].between?(1, predictions.size)

        valid = result["evidence"].select { evidence[_1] }
        verdict = CITATION_REQUIRED.include?(result["verdict"]) && valid.empty? ? "no_evidence" : result["verdict"]
        prediction = predictions[result["prediction"] - 1]
        result.merge("verdict" => verdict, "evidence" => valid, "claim" => prediction["claim"],
                     "basis" => prediction["basis"], "confidence" => prediction["confidence"],
                     "urls" => valid.to_h { [ _1, evidence[_1].url ] })
      end
      { "results" => results }
    end
  end
end
