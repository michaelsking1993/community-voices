# Decisions

One row per call: the question, the options, the trade-off, and what we chose. Newest at the bottom.

| # | Date | Question | Options | Trade-off | Choice |
|---|---|---|---|---|---|
| 1 | 2026-11-23 | Which community? | Anki forums, a subreddit, Hacker News | Anki's Discourse has a public JSON API, steady volume (~60 topics, ~370 posts a week), and clear categories. Reddit's API is gated; HN is too broad for "themes". | Anki forums |
| 2 | 2026-11-23 | Where do vectors live? | Dedicated vector DB (Pinecone, Qdrant), Postgres + pgvector | A dedicated store scales to hundreds of millions of vectors but is one more service, and you lose joins/date filters next to the vectors. We have tens of thousands of chunks. | Postgres + pgvector |
| 3 | 2026-11-23 | Stack | Rails 8, Python | Rails is where I can explain every line. pgvector has first-class Rails support via the `neighbor` gem. | Rails 8.1 + Hotwire, no React |
| 4 | 2026-11-23 | How do reviewers run it? | Docker for everything, Docker for Postgres only, no Docker | Full Docker means no Ruby needed; DB-only Docker is faster for Rails devs. Supporting both costs one compose file. | Both: `docker compose up`, or `docker compose up -d db` + `bin/setup` |
| 5 | 2026-11-23 | Ruby version | 3.3.6, 3.3.14 | Brakeman flags a critical CVE in 3.3.6. CI and Docker use 3.3.14. | 3.3.14 |
| 6 | 2026-11-23 | Background jobs | Sidekiq + Redis, Solid Queue | Solid Queue is Rails 8's default and stores jobs in Postgres: no Redis to run. It also has recurring schedules built in. | Solid Queue (also in development) |
| 7 | 2026-11-23 | How to crawl Discourse | Walk every topic (`/t/{id}.json`), page `/posts.json` | `/posts.json` includes raw text and costs ~7 requests a week. Walking topics costs 60+ requests and handles long threads with extra pages. | `/posts.json?before=` |
| 8 | 2026-11-23 | Avoid duplicates on re-runs | Delete-and-reload, upsert by forum id | Upserts make every run safe to repeat and let weekly windows overlap by a day. | Upsert on `discourse_id` |
| 9 | 2026-11-23 | How polite to be | No limit, 1 req/s, cached responses | 1 req/s means a 12-week backfill takes ~2 minutes, which is fine. Disk caching deferred. | 1 req/s, User-Agent, back off on 429 |
| 10 | 2026-11-23 | Backfill depth | 2, 12, 52 weeks | 12 weeks gives history for predictions and "look-alike" retrieval; 2 weeks keeps reviewer setup to ~20 seconds. | 12 for the demo, 2 by default in `bin/setup` |
| 11 | 2026-11-23 | What to drop at ingest | Nothing, non-regular posts, tiny posts too | Dropping tiny posts here would make our counts disagree with the forum's. | Drop moderator actions, hidden, deleted; skip tiny posts later, at chunking |
| 12 | 2026-11-23 | Chunk size | Whole post, ~150 words, one sentence | The model reads ~256 word-pieces; 150 words + header fits. Smaller loses context; bigger blurs ideas and truncates. | 150 words, 30-word overlap |
| 13 | 2026-11-23 | Give chunks context | Nothing, header line, store separately | A three-line header (topic, category, date) costs ~20 tokens and makes each chunk understandable alone, for both the vector and the model. | Header on every chunk |
| 14 | 2026-11-23 | Minimum post length | 0, 5, 12, 25 words | 12 words drops "thanks, that worked!" (~10% of posts) but keeps short real answers. | 12 words |
| 15 | 2026-11-23 | Avoid re-embedding | Re-embed everything, compare text, store a hash | A SHA-256 per chunk is cheap to compare and makes every run incremental. | Content hash |
| 16 | 2026-11-23 | Embedding model | Hosted (OpenAI, Voyage), local MiniLM | Local needs no key and no cost; reviewers only need one key (Anthropic). Lower quality than large hosted models, fine for forum posts. | all-MiniLM-L6-v2 via `informers`, 384 dims |
| 17 | 2026-11-23 | Vector index | None (exact scan), IVFFlat, HNSW | An exact scan is fine at 5k chunks but does not scale; IVFFlat needs data before it is built. HNSW is fast, accurate and can be built on an empty table. | HNSW, cosine |
