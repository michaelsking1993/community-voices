# The app talks to a large language model through one small interface:
#
#   client.json(system:, prompt:, schema:) -> Llm::Response (parsed JSON, tokens, cost)
#   client.configured?                     -> is there a key?
#
# Callers take the client as an argument (dependency injection), so specs
# pass FakeLlm and the provider is a setting, not a code change. Each
# provider is an adapter in app/services/llm/. Today there is one.
module Llm
  class NotConfigured < StandardError; end
  class Failed < StandardError; end

  PROVIDERS = { "anthropic" => "Llm::Anthropic" }.freeze

  # The configured provider's client. LLM_PROVIDER picks it (default: anthropic).
  def self.client(**options)
    name = ENV["LLM_PROVIDER"].presence || "anthropic"
    adapter = PROVIDERS.fetch(name) { raise NotConfigured, "Unknown LLM_PROVIDER #{name.inspect}; known: #{PROVIDERS.keys.join(", ")}" }
    adapter.constantize.new(**options)
  end
end
