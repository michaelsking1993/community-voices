class ChartsController < ApplicationController
  Section = Data.define(:title, :charts, :empty)

  def index
    @retrieval = Charts::RetrievalCharts.new
    @sections = [
      Section.new("A/B test: no context vs paste the whole week vs RAG", Charts::AbCharts.new.call,
                  "No A/B results yet. Run bin/rails 'ab:run[1]', or read docs/samples/ for a stored run."),
      Section.new("Backtest: did last week's predictions come true?", Charts::BacktestCharts.new.call,
                  "No backtest yet. Run bin/rails 'backtest:run[4]' (needs at least 6 full weeks: BACKFILL_WEEKS=12)."),
      Section.new("Embedding map", embedding_map, "No embeddings yet. Run bin/rails ingest:backfill."),
      Section.new("Retrieval stats", @retrieval.call, "No retrievals logged yet. Write a report first.")
    ]
  end

  private

  # PCA over hundreds of threads takes a second or two, so it is cached
  # until a new chunk arrives.
  def embedding_map
    Rails.cache.fetch("embedding-map/#{Chunk.maximum(:id)}", expires_in: 1.day) { Charts::EmbeddingMap.new.call }
  end
end
