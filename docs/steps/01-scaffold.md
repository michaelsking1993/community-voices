# Step 1: Scaffold the app

## What we built

A Rails 8.1 app on Postgres with the pgvector extension enabled, RSpec, and CI on GitHub Actions. It runs two ways: `docker compose up` for everything, or Postgres in Docker with Rails on your machine. A smoke spec proves Postgres can store vectors and measure distances between them.

## Why this way

- **pgvector instead of a separate vector database.** Our posts already live in Postgres, and we will want to filter by date and category in the same query that finds similar text. A separate store would mean syncing two systems for a corpus of tens of thousands of chunks, which Postgres handles easily. (DECISIONS #2)
- **Solid Queue instead of Sidekiq.** The weekly ingest is a background job. Solid Queue keeps jobs in Postgres, so reviewers run one database and nothing else. (DECISIONS #6)
- **CI from the first commit.** Four jobs: security scan, lint, RSpec against a real pgvector Postgres, and a `docker compose` build that proves the reviewer path works.

## How it works

```
docker compose up
  ├─ db   pgvector/pgvector:pg16   (Postgres 16 + the vector extension)
  └─ app  bin/setup → db:prepare → bin/dev (Puma + Solid Queue in one process)
```

1. `db/migrate/…_enable_pgvector.rb` runs `enable_extension "vector"`. That adds a `vector(n)` column type and distance operators such as `<=>` (cosine distance).
2. The `neighbor` gem teaches ActiveRecord about that column type, so a model can say `has_neighbors :embedding` and query `nearest_neighbors(...)` (used in step 4).
3. In development, Solid Queue uses its own database (`community_voices_development_queue`), and `bin/dev` runs it inside Puma, so the weekly schedule fires locally too.
4. `spec/db/pgvector_spec.rb` checks the extension is on and that cosine distance behaves: same direction = 0, unrelated = 1.

## Key takeaways

pgvector is a Postgres extension that adds one column type (a fixed-length list of floats) and a few operators to compare them, plus index types (HNSW, IVFFlat) that make "find the nearest vectors" fast. Everything else stays normal Postgres: joins, `WHERE` clauses, transactions, backups.

## Possible next steps

Nothing deferred here. Next is step 3: crawl the forum into `topics` and `posts`.
