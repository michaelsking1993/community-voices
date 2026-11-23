module Ab
  # A blind comparison of one week's reports from every arm.
  #
  # The judge sees the reports as "Report A, B, C" in a shuffled order,
  # with citation ids removed, plus exact facts about the week: the counts
  # and the biggest threads. It scores each on four things (1 to 5) and
  # ranks them. The shuffle is seeded by the week, so a re-run is the same.
  #
  # Limit: the judge is an LLM, so its scores are a second opinion next to
  # the checks done in code, not a ground truth.
  class Ranker
    DIMENSIONS = %w[coverage accuracy specificity usefulness].freeze
    TOP_THREADS = 40

    SYSTEM = <<~PROMPT.freeze
      You compare reports about one week of the Anki forums (forums.ankiweb.net). Each was written for the people who build Anki. You do not know how they were made.

      Facts about the week are given: exact activity counts and the 40 biggest threads. Use only those facts to judge what is true; do not use your own knowledge of Anki.

      Score each report from 1 (poor) to 5 (excellent):
      - coverage: does it cover what the biggest threads were about?
      - accuracy: are its statements consistent with the facts? Penalise specifics the facts do not support.
      - specificity: concrete things (versions, features, numbers) rather than generalities.
      - usefulness: would a product team learn what its users need this week?
      Also count `invented`: statements that look specific but that the facts contradict or cannot support.

      Then list the labels from best to worst. Notes are one or two plain sentences.
    PROMPT

    SCHEMA = { type: "object", additionalProperties: false, required: %w[reports ranking],
               properties: { reports: { type: "array", items: {
                 type: "object", additionalProperties: false, required: %w[label invented note] + DIMENSIONS,
                 properties: { label: { type: "string" }, invented: { type: "integer" }, note: { type: "string" },
                               **DIMENSIONS.to_h { [ _1, { type: "integer" } ] } } } },
                              ranking: { type: "array", items: { type: "string" } } } }.freeze

    def initialize(llm: Llm.client) = @llm = llm

    # reports: { "rag" => Report, ... }, all for the same week
    def call(week, reports)
      labels = shuffled(week, reports.keys).each_with_index.to_h { |arm, i| [ arm, ("A".ord + i).chr ] }
      response = @llm.json(system: SYSTEM, prompt: prompt(week, reports, labels), schema: SCHEMA)
      Judgement.record(kind: "ranking", week_start: week.start, response:, data: by_arm(response.data, labels, reports))
    end

    private

    def shuffled(week, arms) = arms.shuffle(random: Random.new(week.start.jd))

    def prompt(week, reports, labels)
      facts = Reports::WeekFacts.new
      [ "Week: #{week}", facts.to_prompt(facts.call(week)), "Biggest threads (title, posts):\n#{threads(week)}",
        *labels.sort_by(&:last).map { |arm, label| "# Report #{label}\n#{text(reports.fetch(arm))}" } ].join("\n\n")
    end

    def threads(week)
      Topic.joins(:posts).where(posts: { posted_at: week.range }).group("topics.id", "topics.title")
           .order(Arel.sql("count(*) desc")).limit(TOP_THREADS).pluck("topics.title", Arel.sql("count(*)"))
           .map { |title, posts| "- #{title} (#{posts})" }.join("\n")
    end

    def text(report)
      content = report.content
      predictions = content.fetch("predictions", []).map { "- #{_1["claim"]}" }
      [ content["headline"], content["overview"], *content.fetch("sections", []).map { "## #{_1["title"]}\n#{_1["body"]}" },
        ("## Predictions\n#{predictions.join("\n")}" if predictions.any?) ].compact.join("\n\n").gsub(/\s*\[E\d+\]/, "")
    end

    def by_arm(data, labels, reports)
      arm_of = labels.invert
      scores = data["reports"].filter_map do |row|
        arm = arm_of[row["label"]]
        [ arm, row.except("label").merge("report_id" => reports[arm].id) ] if arm
      end.to_h
      { "labels" => labels, "scores" => scores, "ranking" => data["ranking"].filter_map { arm_of[_1] } }
    end
  end
end
