module Charts
  # Names and colours shared by every figure, so an arm or a verdict looks
  # the same everywhere.
  module Palette
    ARM_LABELS = { "none" => "No context", "paste_all" => "Paste the whole week", "rag" => "RAG" }.freeze
    ARM_COLORS = { "none" => "#8e8e93", "paste_all" => "#d98f00", "rag" => "#2f5fd0" }.freeze
    VERDICT_COLORS = { "happened" => "#2f9e5b", "partly" => "#d9b300", "did_not_happen" => "#d1453b", "no_evidence" => "#8e8e93" }.freeze
  end
end
