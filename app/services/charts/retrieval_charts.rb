module Charts
  # What the retriever has been doing, from the retrievals it logged.
  class RetrievalCharts
    BIN = 0.025

    def call
      return [] if RetrievalHit.none?

      [ most_retrieved, distances ]
    end

    # One row per purpose: how many searches, how many found nothing, how fast.
    def purposes
      Retrieval.group(:purpose).pluck(:purpose, Arel.sql("count(*)"), Arel.sql("sum(case when hits_count = 0 then 1 else 0 end)"),
                                      Arel.sql("round(avg(duration_ms))"), Arel.sql("round(avg(hits_count), 1)"))
               .map { |purpose, n, empty, ms, hits| { purpose:, searches: n, empty: empty.to_i, ms: ms.to_i, hits: hits.to_f } }
    end

    private

    def most_retrieved
      counts = RetrievalHit.group(:chunk_id).order(Arel.sql("count(*) desc")).limit(15).count
      chunks = Chunk.where(id: counts.keys).preload(post: :topic).index_by(&:id)
      rows = counts.map { |id, n| [ chunks[id].post.topic.title.truncate(55), n ] }.reverse
      Chart.build(id: "retrieval-top", title: "Which chunks get retrieved most?",
                  caption: "The 15 chunks that appeared in the most search results, by the title of the thread they come from. A few very popular chunks can mean the searches overlap; here the cut-off and per-thread cap keep it spread.",
                  traces: [ { type: "bar", orientation: "h", y: rows.map(&:first), x: rows.map(&:last), marker: { color: Palette::ARM_COLORS["rag"] }, showlegend: false } ],
                  layout: { margin: { l: 330 }, xaxis: { title: "times retrieved" } })
    end

    def distances
      bins = RetrievalHit.pluck(:distance).group_by { (_1 / BIN).floor }.transform_values(&:size).sort
      Chart.build(id: "retrieval-distances", title: "How close are retrieved chunks?",
                  caption: "Cosine distance of every returned chunk to its query (smaller is closer). Nothing beyond the #{Search::Retriever::MAX_DISTANCE} cut-off is ever returned.",
                  traces: [ { type: "bar", x: bins.map { (_1.first * BIN).round(3) }, y: bins.map(&:last), marker: { color: Palette::ARM_COLORS["rag"] }, showlegend: false } ],
                  layout: { xaxis: { title: "cosine distance" }, yaxis: { title: "chunks returned" } })
    end
  end
end
