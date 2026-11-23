module Llm
  # The Anthropic adapter for the Llm interface. Uses the official
  # `anthropic` gem and structured outputs, so the answer always matches
  # the JSON schema the caller passes.
  #
  # Configured by LLM_API_KEY and LLM_MODEL, the same names any adapter reads.
  class Anthropic
    DEFAULT_MODEL = "claude-opus-5-5".freeze
    MAX_TOKENS = 16_000

    def initialize(api_key: ENV["LLM_API_KEY"], model: ENV["LLM_MODEL"], effort: :medium)
      @api_key = api_key
      @model = model.presence || DEFAULT_MODEL
      @effort = effort
    end

    attr_reader :model

    def configured? = @api_key.present?

    def json(system:, prompt:, schema:, max_tokens: MAX_TOKENS)
      raise NotConfigured, "Set LLM_API_KEY in .env to generate reports." unless configured?

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      message = create(system:, prompt:, schema:, max_tokens:)
      check!(message)
      Response.new(
        data: JSON.parse(message.content.find { _1.type == :text }.text),
        model: message.model.to_s,
        input_tokens: message.usage.input_tokens,
        output_tokens: message.usage.output_tokens,
        duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
    end

    private

    # Beta endpoint only for `fallbacks: :default`: if a safety classifier
    # declines, the API retries on a suitable model instead of failing.
    def create(system:, prompt:, schema:, max_tokens:)
      sdk.beta.messages.create(
        model: @model,
        max_tokens:,
        system_: system,
        messages: [ { role: "user", content: prompt } ],
        output_config: { effort: @effort, format_: { type: :json_schema, schema: } },
        fallbacks: :default,
        betas: [ "server-side-fallback-2026-07-01" ]
      )
    end

    def check!(message)
      case message.stop_reason
      when :refusal then raise Failed, "The model declined: #{message.stop_details&.explanation}"
      when :max_tokens then raise Failed, "The response hit max_tokens and was cut off."
      end
    end

    def sdk = @sdk ||= ::Anthropic::Client.new(api_key: @api_key)
  end
end
