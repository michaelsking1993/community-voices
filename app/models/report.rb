# A Community Voices report for one week. Content is the model's
# structured answer; evidence maps each [E-number] to the post it came
# from; grounding holds the checks code ran on the citations and quotes.
class Report < ApplicationRecord
  STATUSES = %w[pending done failed].freeze

  has_many :retrievals, dependent: :nullify

  validates :status, inclusion: { in: STATUSES }

  scope :done, -> { where(status: "done") }
  scope :latest_first, -> { order(created_at: :desc) }

  def week = Week.new(start: week_start)
  def sections = content.fetch("sections", [])
  def predictions = content.fetch("predictions", [])
  def insufficient_evidence? = content["insufficient_evidence"].present?
end
