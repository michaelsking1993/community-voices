require "rails_helper"

RSpec.describe Themes::Finder do
  let(:model) { FakeEmbeddingModel.new }
  let(:week) { Week.new(start: Date.new(2026, 11, 16)) }
  let(:llm) do
    FakeLlm.new do |call|
      clusters = call[:prompt].scan(/## Cluster (\d+)/).flatten.map(&:to_i)
      { themes: clusters.map { |n| { cluster: n, label: "Theme #{n}", summary: "People discuss #{n}.", kind: "problem" } } }
    end
  end

  def thread(id, title, posts, posted_at: Time.zone.parse("2026-11-18 10:00"))
    topic = Topic.create!(discourse_id: id, title:, slug: title.parameterize, category_name: "Anki › Help")
    posts.each_with_index do |raw, i|
      Chunking::Chunker.new.call(create_post(raw:, topic:, posted_at: posted_at + i.hours))
    end
  end

  before do
    sync = "sync fails with a network error when syncing my collection to ankiweb server again today"
    font = "the font size on the back of my cards looks wrong in the card template editor window"
    thread(1, "Sync error", [ sync, sync ])
    thread(2, "Sync fails again", [ sync ])
    thread(3, "Font too small", [ font, font, font ])
    thread(4, "Old sync thread", [ sync ], posted_at: Time.zone.parse("2026-10-01"))
    Embeddings::Embedder.new(model:).call
  end

  subject(:themes) { described_class.new(llm:, k: 2).call(week) }

  it "groups the week's threads into themes, biggest first, with counts from SQL" do
    expect(themes.map(&:label)).to eq([ "Theme 1", "Theme 2" ]).or eq([ "Theme 2", "Theme 1" ])
    expect(themes.map { _1.topics.map(&:discourse_id).sort }).to contain_exactly([ 1, 2 ], [ 3 ])
    sync_theme = themes.find { _1.topics.map(&:discourse_id).include?(1) }
    expect(sync_theme).to have_attributes(topic_count: 2, post_count: 3, author_count: 3, kind: "problem")
    expect(themes.map(&:position)).to eq([ 1, 2 ])
  end

  it "only uses posts from that week" do
    expect(themes.flat_map(&:topics).map(&:discourse_id)).not_to include(4)
  end

  it "asks the model to name clusters from titles and excerpts, not to count" do
    themes
    prompt = llm.calls.last[:prompt]

    expect(prompt).to include("Week: 2026-11-16 to 2026-11-22", "Font too small", "font size on the back")
    expect(llm.calls.last[:schema][:required]).to eq([ "themes" ])
  end

  it "replaces a week's themes when run again" do
    themes
    described_class.new(llm:, k: 2).call(week)

    expect(Theme.for_week(week).count).to eq(2)
  end

  it "falls back to the closest thread's title if the model skips a cluster" do
    silent = FakeLlm.new(themes: [])
    labels = described_class.new(llm: silent, k: 2).call(week).map(&:label)

    expect(labels).to all(be_in([ "Sync error", "Sync fails again", "Font too small" ]))
  end

  it "returns no themes for an empty week" do
    expect(described_class.new(llm:).call(week.next)).to eq([])
    expect(llm.calls).to be_empty
  end
end
