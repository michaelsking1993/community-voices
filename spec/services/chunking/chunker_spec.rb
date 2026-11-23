require "rails_helper"

RSpec.describe Chunking::Chunker do
  subject(:chunker) { described_class.new }

  it "skips tiny posts like 'thanks, that worked!'" do
    post = create_post(raw: "Thanks, that worked!")
    expect(chunker.call(post)).to eq(0)
    expect(Chunk.count).to eq(0)
  end

  it "gives every chunk a header with the topic, category and date" do
    post = create_post(raw: words(20))
    chunker.call(post)

    expect(Chunk.sole.content).to start_with(
      "Topic: Sync keeps failing\nCategory: Anki › Syncing & AnkiWeb\nDate: 2026-11-20\n\nreview0 review1"
    )
  end

  it "splits long posts into overlapping windows" do
    post = create_post(raw: words(300))
    chunker.call(post)

    bodies = post.chunks.order(:position).map { _1.content.split("\n\n").last.split }
    expect(bodies.map(&:size)).to eq([ 150, 150, 60 ])
    expect(bodies[1].first).to eq("review120") # 30 words of overlap with chunk 0
    expect(bodies.last.last).to eq("review299")
  end

  it "stores a content hash and estimated token count" do
    chunker.call(create_post(raw: words(20)))
    chunk = Chunk.sole
    expect(chunk.content_hash).to eq(Digest::SHA256.hexdigest(chunk.content))
    expect(chunk.token_estimate).to eq(chunk.content.length / 4)
  end

  it "keeps the embedding when the text is unchanged" do
    post = create_post(raw: words(20))
    chunker.call(post)
    Chunk.sole.update!(embedding: Array.new(384, 0.1))

    chunker.call(post.reload)

    expect(Chunk.sole.embedding).to be_present
  end

  it "clears the embedding when the text changes, so only that chunk is re-embedded" do
    post = create_post(raw: words(20))
    chunker.call(post)
    Chunk.sole.update!(embedding: Array.new(384, 0.1))

    post.update!(raw: words(20, "edited"))
    chunker.call(post.reload)

    expect(Chunk.sole.embedding).to be_nil
    expect(Chunk.sole.content).to include("edited0")
  end

  it "removes chunks left over when a post gets shorter" do
    post = create_post(raw: words(300))
    chunker.call(post)
    post.update!(raw: words(20))
    chunker.call(post.reload)

    expect(post.chunks.count).to eq(1)
  end
end
