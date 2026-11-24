# A long task started from the Data or Evaluate tab. Status moves queued ->
# running -> done or failed; summary holds the same text the rake task prints.
class JobRun < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  # key, button label, what it does, what it costs, whether it calls the LLM,
  # the weeks the form allows (nil: no weeks box), and how many full weeks
  # of data it needs before it is worth running.
  Kind = Data.define(:key, :label, :blurb, :cost, :needs_llm, :weeks, :min_full_weeks) do
    def default_weeks = { "ingest" => 12, "ab" => 1, "backtest" => 4 }[key]
  end
  KINDS = [
    Kind.new("ingest", "Crawl the forum",
             "Fetch posts from forums.ankiweb.net (one request a second), split them into chunks and embed them on this machine. Days already stored are skipped, so crawling 12 weeks after 2 only fetches the 10 missing ones.",
             "Free. About 5 minutes for 12 weeks; the first run also downloads a ~90 MB model.", false, 1..12, 0),
    Kind.new("ab", "Run A/B test",
             "Write last week's report three ways (no context, paste the whole week, RAG), check each in code, then have a judge score and rank them without knowing which is which. Answers: is RAG worth it?",
             "About $0.65 per week. Takes a few minutes.", true, 1..3, 1),
    Kind.new("backtest", "Run backtest",
             "Rewrite past weeks' reports using only data from before each week, then have a judge check whether their predictions came true. Answers: are the predictions any good?",
             "Roughly $0.10 per week.", true, 2..6, 6),
    Kind.new("retrieval_eval", "Run retrieval eval",
             "Ask 15 questions whose right answers (forum threads) were labelled by hand, and score how often the retriever finds them. Answers: does search find the right posts?",
             "Free, runs on this machine.", false, nil, 12)
  ].freeze

  validates :kind, inclusion: { in: KINDS.map(&:key) }
  validates :status, inclusion: { in: STATUSES }

  scope :latest_first, -> { order(created_at: :desc) }

  def self.kind(key) = KINDS.find { _1.key == key }
  def self.active?(key = nil)
    scope = where(status: %w[queued running]).where(created_at: 2.hours.ago..)
    (key ? scope.where(kind: key) : scope).exists?
  end

  def definition = self.class.kind(kind)
  def active? = status.in?(%w[queued running])
end
