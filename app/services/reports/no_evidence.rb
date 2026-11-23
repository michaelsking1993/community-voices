module Reports
  # The no-context arm's "evidence": nothing.
  class NoEvidence
    def call(_week, _themes) = Evidence.new
  end
end
