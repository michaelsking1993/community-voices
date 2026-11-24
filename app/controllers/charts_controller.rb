class ChartsController < ApplicationController
  Section = Data.define(:title, :charts, :empty)

  def index
    @retrieval = Charts::RetrievalCharts.new
    @sections = [
      Section.new("A/B test: no context vs paste the whole week vs RAG", Charts::AbCharts.new.call,
                  "No A/B results yet. Run the A/B test on the Evaluate tab, or read docs/samples/ for a stored run."),
      Section.new("Backtest: did last week's predictions come true?", Charts::BacktestCharts.new.call,
                  "No backtest yet. Run the backtest on the Evaluate tab (it needs at least 6 full weeks of data)."),
      Section.new("Embedding map", embedding_map, "No embeddings yet. Crawl the forum on the Data tab."),
      Section.new("Retrieval stats", @retrieval.call, "No retrievals logged yet. Write a report or run a search first.")
    ]
  end

  private

  # PCA over hundreds of threads takes a second or two, so it is cached
  # until a new chunk arrives.
  def embedding_map
    Rails.cache.fetch("embedding-map/#{Chunk.maximum(:id)}", expires_in: 1.day) { Charts::EmbeddingMap.new.call }
  end
end
