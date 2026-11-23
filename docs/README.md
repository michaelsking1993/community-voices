# Docs

Read in this order. Each page is about one screen.

## Build diary (one page per step)

1. [Scaffold](steps/01-scaffold.md): Rails 8, Postgres + pgvector, Docker, CI
2. [Concepts lab](steps/02-concepts-lab.md): guess which sentences are similar, then measure
3. [Ingest the forum](steps/03-ingest.md): polite, idempotent weekly crawl
4. [Chunk and embed](steps/04-chunk-and-embed.md): headers, tiny-post skip, content hash, local model, HNSW

## Concepts

- [RAG](concepts/rag.md): retrieve, augment, generate, and why not just paste everything
- [When a vector DB helps, and when it does not](concepts/vector-databases.md)
- [pgvector](concepts/pgvector.md): vectors inside Postgres
- [Embeddings and chunking](concepts/embeddings-and-chunking.md)
- [ETL and ingestion](concepts/etl-and-ingestion.md)

## Also

- [DECISIONS.md](../DECISIONS.md): every call, its options and trade-off
- [notes.md](notes.md): running notes for the README and interview
