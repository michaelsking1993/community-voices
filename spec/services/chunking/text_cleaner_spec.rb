require "rails_helper"

RSpec.describe Chunking::TextCleaner do
  it "removes quoted replies, which belong to another post" do
    raw = "[quote=\"bob, post:2, topic:9\"]\nmy deck is gone\n[/quote]\nTry a full sync."
    expect(described_class.call(raw)).to eq("Try a full sync.")
  end

  it "keeps link text, drops images, code and HTML, and squashes whitespace" do
    raw = "See [the manual](https://docs.ankiweb.net)\n\n![shot](upload://a.png)\n```\ncode\n```\n<br>done"
    expect(described_class.call(raw)).to eq("See the manual [code] done")
  end
end
