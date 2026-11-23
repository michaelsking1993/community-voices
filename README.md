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

Run the tests with `bundle exec rspec`.

## The problem, restated

<!-- Filled in as the steps land; this README follows a system-design answer: problem, questions, entities, shape and why, built vs deferred, what could go wrong. -->

_To do in step 10._

## Questions I asked, and the assumptions I made

See [`DECISIONS.md`](DECISIONS.md) for the full log.

## Entities

| Table | What it holds |
|---|---|
| _(added per step)_ | |

## Shape of the system, and why

_To do._

## Built vs deferred

_To do._

## What could go wrong

_To do._

## How this was built

Planned first, then built in small pull requests with tests and green CI. The step pages in [`docs/steps/`](docs/steps) are the build diary; [`docs/concepts/`](docs/concepts) explains the RAG and vector-database ideas the code relies on.
