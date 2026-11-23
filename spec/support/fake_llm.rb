# Stands in for any Llm adapter in specs: no network, no key, no cost.
# Give it the JSON to return (or a block that builds it from the prompt),
# then inspect #calls to see exactly what the app sent.
class FakeLlm
  attr_reader :calls

  def initialize(response = {}, &block)
    @response = block || ->(_call) { response }
    @calls = []
  end

  def model = "fake-model"
  def configured? = true

  def json(system:, prompt:, schema:, max_tokens: nil)
    call = { system:, prompt:, schema: }
    @calls << call
    Llm::Response.new(data: @response.call(call).deep_stringify_keys, model:, input_tokens: prompt.length / 4,
                      output_tokens: 100, duration_ms: 1)
  end
end
