# Community Voices

Every week, this app reads the [Anki forums](https://forums.ankiweb.net), works out what people talked about, and writes a cited "Community Voices" report: what happened last week and what is likely to come up next week. It uses retrieval-augmented generation (RAG) over a pgvector table in Postgres.

> Status: being built in small steps. Each step has a one-page write-up in [`docs/steps/`](docs/steps), and every design call is logged in [`DECISIONS.md`](DECISIONS.md).

## Quick start

You need Docker. Then:

```sh
git clone https://github.com/michaelsking1993/community-voices && cd community-voices
docker compose up
```

That starts Postgres (with pgvector), sets up the app, and serves it on http://localhost:3000.

Prefer Ruby on your machine? Run only the database in Docker:

```sh
docker compose up -d db
bin/setup
```

`bin/setup` crawls the last 2 weeks of the forum (about 20 seconds), then chunks and embeds them locally (about a minute; the first run downloads a ~90 MB model). For the full 12 weeks of history: `bin/rails 'ingest:backfill[12]'` (about 2 minutes to crawl and 5 to embed; set `BACKFILL_WEEKS=12` with Docker). After that, `IngestWeekJob` runs every Monday at 6am.

Spot-check the embeddings: `bin/rails 'ingest:nearest[sync problems]'`. Search the way the report does: `bin/rails 'retrieval:search[sync problems]'`. Score retrieval on the labelled queries: `bin/rails retrieval:eval`. Write last week's report: `bin/rails report:build` (needs `ANTHROPIC_API_KEY`), or open http://localhost:3000 and press "Write report".

Run the tests with `bundle exec rspec` (add `RUN_MODEL_SPECS=1` and `--tag model` to also run the real embedding model).

## The problem, restated

<!-- Filled in as the steps land; this README follows a system-design answer: problem, questions, entities, shape and why, built vs deferred, what could go wrong. -->

_To do in step 10._

## Questions I asked, and the assumptions I made

See [`DECISIONS.md`](DECISIONS.md) for the full log.

## Entities

| Table | What it holds |
|---|---|
| `topics` | One row per forum thread: title, slug, category ("Anki › FSRS") |
| `posts` | One row per forum post: author, raw text, date. Keyed on the forum's own id |
| `chunks` | Up to 150 words of one post, with a topic/category/date header, a content hash, and a 384-number embedding (HNSW index) |
| `themes`, `theme_topics` | A week's themes: a label, summary and kind written by the LLM, counts from SQL, and the threads in each |
| `reports` | A generated report: the model's structured answer, the numbered evidence it cited, the citation and quote checks, tokens and cost. Outputs only, never searched |
| `retrievals`, `retrieval_hits` | Every search the app runs: the query, window and settings, and each chunk it returned with its rank and distance |

## Shape of the system, and why

_To do._

## Built vs deferred

_To do._

## What could go wrong

_To do._

## How this was built

Planned first, then built in small pull requests with tests and green CI. The step pages in [`docs/steps/`](docs/steps) are the build diary; [`docs/concepts/`](docs/concepts) explains the RAG and vector-database ideas the code relies on.
