# A long task started from the Evaluate tab. Status moves queued -> running ->
# done or failed; summary holds the same text the rake task prints.
class JobRun < ApplicationRecord
  STATUSES = %w[queued running done failed].freeze

  # kind => label, what it spends, default weeks and the range the form allows.
  Kind = Data.define(:key, :label, :blurb, :cost, :needs_llm, :weeks)
  KINDS = [
    Kind.new("ingest", "Crawl the forum", "Fetch new posts from forums.ankiweb.net, chunk them and embed them locally (1 request a second; the first run downloads a ~90 MB model).",
             "Free. Takes about 5 minutes for 12 weeks.", false, 1..12),
    Kind.new("retrieval_eval", "Retrieval eval", "Run 15 hand-labelled questions through the retriever and score hit rate and recall for several settings.",
             "Free, runs locally. Needs 12 weeks crawled.", false, nil),
    Kind.new("ab", "A/B test", "Write three reports for each week (no context, paste the whole week, RAG), check them in code, then have a judge score and rank them blind.",
             "About $0.65 per week.", true, 1..3),
    Kind.new("backtest", "Backtest", "Write each week's report using only earlier data, then have a judge score its predictions against what happened next.",
             "Roughly $0.10 per week. Needs at least 6 full weeks crawled.", true, 2..6)
  ].freeze

  validates :kind, inclusion: { in: KINDS.map(&:key) }
  validates :status, inclusion: { in: STATUSES }

  scope :latest_first, -> { order(created_at: :desc) }

  def self.kind(key) = KINDS.find { _1.key == key }
  def self.active?(key) = where(kind: key, status: %w[queued running]).where(created_at: 2.hours.ago..).exists?

  def definition = self.class.kind(kind)
  def active? = status.in?(%w[queued running])
end
