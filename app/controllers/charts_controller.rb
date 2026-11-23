class ChartsController < ApplicationController
  def index
    @retrieval = Charts::RetrievalCharts.new
    @sections = [
      [ "A/B test: no context vs paste the whole week vs RAG", Charts::AbCharts.new.call, "No A/B results yet. Run bin/rails 'ab:run[1]'." ],
      [ "Backtest: did last week's predictions come true?", Charts::BacktestCharts.new.call, "No backtest yet. Run bin/rails 'backtest:run[4]'." ],
      [ "Embedding map", Rails.cache.fetch("embedding-map/#{Chunk.maximum(:id)}", expires_in: 1.day) { Charts::EmbeddingMap.new.call }, "No embeddings yet. Run bin/rails ingest:backfill." ],
      [ "Retrieval stats", @retrieval.call, "No retrievals logged yet. Write a report first." ]
    ]
  end
end
