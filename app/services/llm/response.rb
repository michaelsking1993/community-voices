module Llm
  # What came back from one model call, with what it cost. Cost matters:
  # the A/B test compares arms on tokens and dollars, not only quality.
  class Response < Data.define(:data, :model, :input_tokens, :output_tokens, :duration_ms)
    # US dollars per million tokens (input, output), from Anthropic's pricing page, 2026-11.
    PRICES = {
      "claude-opus-5-5" => [ 4.0, 20.0 ],
      "claude-sonnet-5-5" => [ 2.0, 10.0 ],
      "claude-haiku-5-5" => [ 0.10, 0.50 ]
    }.freeze

    def cost_usd
      input, output = PRICES.find { |prefix, _| model.start_with?(prefix) }&.last
      return nil unless input

      ((input_tokens * input + output_tokens * output) / 1_000_000.0).round(4)
    end
  end
end
