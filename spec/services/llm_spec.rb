require "rails_helper"

RSpec.describe Llm do
  it "builds the configured provider's adapter, Anthropic by default" do
    expect(described_class.client(api_key: "k")).to be_a(Llm::Anthropic)
  end

  it "names the known providers when LLM_PROVIDER is wrong" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LLM_PROVIDER").and_return("nope")

    expect { described_class.client }.to raise_error(Llm::NotConfigured, /known: anthropic/)
  end
end
