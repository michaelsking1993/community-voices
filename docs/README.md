# Docs

Read in this order. Each page is about one screen.

## Build diary (one page per step)

1. [Scaffold](steps/01-scaffold.md): Rails 8, Postgres + pgvector, Docker, CI
2. [Concepts lab](steps/02-concepts-lab.md): guess which sentences are similar, then measure
3. [Ingest the forum](steps/03-ingest.md): polite, idempotent weekly crawl
4. [Chunk and embed](steps/04-chunk-and-embed.md): headers, tiny-post skip, content hash, local model, HNSW
5. [Retrieval](steps/05-retrieval.md): date window, distance cut-off, max 2 per thread, logging, a 15-query eval
6. [Themes](steps/06-themes.md): k-means over threads, choosing k, SQL counts, the LLM names each cluster
7. [Write the report](steps/07-report.md): per-theme retrieval, numbered evidence, cite-or-omit, checks in code
8. [Predict next week](steps/08-predictions.md): trend counts, earlier look-alikes, betas and releases, checkable claims
9. [Backtest](steps/09-backtest.md): score past predictions against the week that followed, with no peeking
10. [A/B test](steps/10-ab-test.md): no context vs paste the whole week vs RAG, judged three ways
11. [Charts](steps/11-charts.md): Plotly through Stimulus, embedding map, retrieval stats

## Concepts

- [RAG](concepts/rag.md): retrieve, augment, generate, and why not just paste everything
- [When a vector DB helps, and when it does not](concepts/vector-databases.md)
- [pgvector](concepts/pgvector.md): vectors inside Postgres
- [Embeddings and chunking](concepts/embeddings-and-chunking.md)
- [ETL and ingestion](concepts/etl-and-ingestion.md)
- [Retrieval](concepts/retrieval.md): top-k, cut-offs, filtered HNSW, diversity, hybrid search, measuring it
- [Clustering](concepts/clustering.md): k-means, its weaknesses, why threads not posts
- [Evaluating RAG](concepts/evaluating-rag.md): checks in code, judges, baselines, backtests
- [Grounded prompting](concepts/grounded-prompting.md): numbered evidence, citations, quotes, checks in code

## Also

- [samples/](samples): one week's report written three ways, and how they compared

- [DECISIONS.md](../DECISIONS.md): every call, its options and trade-off
- [notes.md](notes.md): running notes for the README and interview
