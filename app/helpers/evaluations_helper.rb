module EvaluationsHelper
  ARM_NAMES = { "rag" => "RAG (this app)", "paste_all" => "Paste the whole week", "none" => "No context" }.freeze

  def arm_name(arm) = ARM_NAMES.fetch(arm, arm)
  def percent(value) = value.nil? ? "–" : number_to_percentage(value * 100, precision: 0)
  def dollars(value) = value.nil? ? "–" : number_to_currency(value, precision: 2)
  def score(value) = value.nil? ? "–" : "#{value} / 5"

  # One sentence a reviewer can read without the table.
  def ab_verdict(rows, weeks)
    by = rows.index_by(&:arm)
    rag, paste = by["rag"], by["paste_all"]
    parts = []
    if rag&.cost_usd && paste&.cost_usd&.positive? && rag.cost_usd.positive?
      parts << "RAG cost #{dollars(rag.cost_usd)} per report against #{dollars(paste.cost_usd)} for pasting the whole week " \
               "(#{(paste.cost_usd / rag.cost_usd).round(1)}x cheaper, #{percent(rag.input_tokens.to_f / paste.input_tokens)} of the tokens)."
    end
    wins = rows.map { "#{arm_name(_1.arm)} #{_1.wins}" }.join(", ")
    parts << "Times ranked best by the blind judge over #{pluralize(weeks, "week")}: #{wins}."
    parts.join(" ")
  end
end
