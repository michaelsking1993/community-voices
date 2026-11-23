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
