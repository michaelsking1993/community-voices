require "rails_helper"

RSpec.describe Llm::Anthropic do
  let(:schema) { { type: "object", properties: { label: { type: "string" } }, required: [ "label" ], additionalProperties: false } }
  let(:client) { described_class.new(api_key: "test-key", model: "claude-opus-5-5") }

  def stub_messages(stop_reason: "end_turn", text: '{"label":"Sync errors"}')
    stub_request(:post, %r{api\.anthropic\.com/v1/messages}).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: { id: "msg_1", type: "message", role: "assistant", model: "claude-opus-5-5",
              content: [ { type: "text", text: } ], stop_reason:, stop_sequence: nil,
              usage: { input_tokens: 1_000, output_tokens: 200 } }.to_json
    )
  end

  it "sends the schema as a structured-output format and returns parsed JSON with usage and cost" do
    stub = stub_messages

    response = client.json(system: "You label themes.", prompt: "Posts...", schema:)

    expect(response.data).to eq("label" => "Sync errors")
    expect(response).to have_attributes(input_tokens: 1_000, output_tokens: 200, cost_usd: 0.008)
    expect(stub.with { |req|
      body = JSON.parse(req.body)
      body.dig("output_config", "format", "type") == "json_schema" && body.dig("output_config", "format", "schema") == schema.deep_stringify_keys &&
        body["fallbacks"] == "default" && body["system"] == "You label themes."
    }).to have_been_requested
  end

  it "fails loudly when the answer was cut off, instead of parsing half a JSON document" do
    stub_messages(stop_reason: "max_tokens", text: '{"lab')

    expect { client.json(system: "s", prompt: "p", schema:) }.to raise_error(Llm::Failed, /max_tokens/)
  end

  it "reads LLM_API_KEY, and falls back to ANTHROPIC_API_KEY" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LLM_API_KEY").and_return(nil)
    allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("vendor-key")

    expect(described_class.new).to be_configured
  end

  it "explains how to fix a missing key" do
    expect { described_class.new(api_key: nil).json(system: "s", prompt: "p", schema:) }
      .to raise_error(Llm::NotConfigured, /LLM_API_KEY/)
  end
end
