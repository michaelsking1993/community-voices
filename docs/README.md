# Docs

Read in this order. Each page is about one screen.

## Build diary (one page per step)

1. [Scaffold](steps/01-scaffold.md): Rails 8, Postgres + pgvector, Docker, CI
2. [Concepts lab](steps/02-concepts-lab.md): guess which sentences are similar, then measure
3. [Ingest the forum](steps/03-ingest.md): polite, idempotent weekly crawl
4. [Chunk and embed](steps/04-chunk-and-embed.md): headers, tiny-post skip, content hash, local model, HNSW
5. [Retrieval](steps/05-retrieval.md): date window, distance cut-off, max 2 per thread, logging, a 15-query eval
6. [Themes](steps/06-themes.md): k-means over threads, SQL counts, Claude names each cluster
7. [Write the report](steps/07-report.md): per-theme retrieval, numbered evidence, cite-or-omit, checks in code

## Concepts

- [RAG](concepts/rag.md): retrieve, augment, generate, and why not just paste everything
- [When a vector DB helps, and when it does not](concepts/vector-databases.md)
- [pgvector](concepts/pgvector.md): vectors inside Postgres
- [Embeddings and chunking](concepts/embeddings-and-chunking.md)
- [ETL and ingestion](concepts/etl-and-ingestion.md)
- [Retrieval](concepts/retrieval.md): top-k, cut-offs, filtered HNSW, diversity, hybrid search, measuring it
- [Clustering](concepts/clustering.md): k-means, its weaknesses, why threads not posts
- [Grounded prompting](concepts/grounded-prompting.md): numbered evidence, citations, quotes, checks in code

## Also

- [DECISIONS.md](../DECISIONS.md): every call, its options and trade-off
- [notes.md](notes.md): running notes for the README and interview
