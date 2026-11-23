# A judge's verdict on a report: see the migration for the kinds. `data`
# is the judge's structured answer after code has checked its citations.
# `response` is nil when no model call was needed.
class Judgement < ApplicationRecord
  KINDS = %w[prediction support ranking].freeze

  belongs_to :report, optional: true

  validates :kind, inclusion: { in: KINDS }

  scope :of_kind, ->(kind) { where(kind:) }

  def self.record(kind:, week_start:, response:, report: nil, data: nil)
    create!(kind:, week_start:, report:, data: data || response.data, model: response&.model,
            input_tokens: response&.input_tokens, output_tokens: response&.output_tokens,
            cost_usd: response&.cost_usd, duration_ms: response&.duration_ms)
  end
end
