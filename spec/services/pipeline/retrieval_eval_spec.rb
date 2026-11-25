require "rails_helper"

RSpec.describe Pipeline::RetrievalEval do
  let(:rows) do
    [ Search::Evaluation::Row.new(query: "sync problems", config: "plain top-k", hit: true, recall: 0.5, threads: 3),
      Search::Evaluation::Row.new(query: "sync problems", config: "max 2 per thread", hit: true, recall: 1.0, threads: 6) ]
  end
  let(:summary) do
    [ Search::Evaluation::Summary.new(config: "plain top-k", queries: 1, hit_rate: 1.0, recall: 0.5, threads: 3.0),
      Search::Evaluation::Summary.new(config: "max 2 per thread", queries: 1, hit_rate: 1.0, recall: 1.0, threads: 6.0) ]
  end
  let(:evaluation) { instance_double(Search::Evaluation, call: rows, summarize: summary, off_topic_empty_rate: 0.75) }
  let(:off_topic_queries) { Search::Evaluation.off_topic.size }

  subject(:result) { described_class.new(evaluation:).call }

  it "prints each query, a summary per config, and the off-topic rate" do
    expect(result.text.lines.map(&:rstrip)).to include(
      "sync problems",
      "  plain top-k        hit=true  recall=0.50 threads=3",
      "max 2 per thread          1      1.00    1.00      6.0",
      "Off-topic queries that correctly found nothing: 75% of #{off_topic_queries}"
    )
  end

  it "returns the same numbers as data for the Evaluate tab" do
    expect(result.data).to eq(
      "configs" => summary.map { _1.to_h.transform_keys(&:to_s) },
      "off_topic_empty_rate" => 0.75,
      "off_topic_queries" => off_topic_queries
    )
  end

  it "deletes the eval's own searches so they stay out of the retrieval stats" do
    logged = { k: 8, per_topic: 2, max_distance: 0.6, candidates_count: 1, hits_count: 1, duration_ms: 1 }
    Retrieval.create!(query: "eval query", purpose: "eval", **logged)
    Retrieval.create!(query: "report query", purpose: "report", **logged)

    result
    expect(Retrieval.pluck(:purpose)).to eq([ "report" ])
  end

  it "says what to do when none of the labelled threads are loaded" do
    allow(evaluation).to receive(:call).and_return([])

    expect { result }.to raise_error(Pipeline::Error, /Crawl 12 weeks first/)
  end
end
