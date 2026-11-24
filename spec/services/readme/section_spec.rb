require "rails_helper"

RSpec.describe Readme::Section do
  let(:readme) do
    Tempfile.new(%w[README .md]).tap do |file|
      file.write(<<~MD)
        # Title

        ## First

        Not this one.

        ## How I built it

        I read the [plan](docs/plan.md), the [rules](#first) and [the forum](https://forums.ankiweb.net).

        ### A step

        | Beat | What |
        |---|---|
        | Learn | **explain** it |

        <script>alert("x")</script>

        ## Next section

        Not this either.
      MD
      file.flush
    end
  end
  let(:section) { described_class.new(path: readme.path).call("How I built it") }

  it "renders only the named section, up to the next ## heading" do
    expect(section.title).to eq("How I built it")
    expect(section.html).to include("<h3", "A step", "<table>", "<strong>explain</strong>")
    expect(section.html).not_to include("Not this one", "Next section", "Not this either")
  end

  it "points repo-relative links and anchors at GitHub, and leaves full URLs alone" do
    expect(section.html).to include(%(href="#{described_class::REPO_URL}/blob/main/docs/plan.md"))
    expect(section.html).to include(%(href="#{described_class::REPO_URL}#first"))
    expect(section.html).to include(%(href="https://forums.ankiweb.net"))
  end

  it "drops raw HTML" do
    expect(section.html).not_to include("<script>")
  end

  it "fails loudly when the heading is missing" do
    expect { described_class.new(path: readme.path).call("Renamed") }.to raise_error(KeyError, /Renamed/)
  end
end
