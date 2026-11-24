# Community Voices

Every week, this app reads the [Anki forums](https://forums.ankiweb.net), works out what people talked about, and writes a cited "Community Voices" report: what happened last week and what is likely to come up next week. It uses retrieval-augmented generation (RAG) over a pgvector table in Postgres.

**See a run without installing anything:** [`docs/samples/`](docs/samples) has one week's report written three ways (RAG, paste the whole week, no context) and how they compared.

## Where each part of the challenge lives

| The challenge asks for | Where it is |
|---|---|
| An active online community | The [Anki forums](https://forums.ankiweb.net) (Discourse): ~310 posts in ~100 threads a week. Why: [DECISIONS #1](DECISIONS.md) |
| A Community Voices Document: last week and next week | The Reports page, or `bin/rails report:build`: themes, cited claims, word-for-word quotes, and checkable predictions. [Step 7](docs/steps/07-report.md), [step 8](docs/steps/08-predictions.md) |
| RAG, on a vector store | pgvector in Postgres, local embeddings, retrieval per theme with a date window, a distance cut-off and max 2 chunks per thread. [Step 4](docs/steps/04-chunk-and-embed.md), [step 5](docs/steps/05-retrieval.md) |
| A flattened view of the embeddings | Charts page: a PCA map of every thread. [Step 11](docs/steps/11-charts.md) |
| Stats on which embeddings are retrieved most | Charts page: every search is logged (`retrievals`, `retrieval_hits`). [Step 5](docs/steps/05-retrieval.md) |
| Automated ingest, and handling too much data | A polite crawler, a weekly job (Mondays 6am), incremental chunk-and-embed. [Step 3](docs/steps/03-ingest.md) |
| An A/B test: with and without RAG | Three arms (no context, paste the whole week, RAG), checked in code and by a blind judge: `bin/rails 'ab:run[1]'`, then the Charts page. [Step 10](docs/steps/10-ab-test.md) |
| (extra) Did the predictions come true? | A backtest against the week that followed: `bin/rails 'backtest:run[4]'`. [Step 9](docs/steps/09-backtest.md) |

**The A/B result, in short** (week of 2026-11-16, [details](docs/steps/10-ab-test.md)): pasting the whole week wrote the best report, at 2.7 times RAG's cost; RAG's cited sentences were as well supported, but it missed one big thread. With no posts the LLM can only guess. RAG is the cheaper way to most of the quality while a week fits in the prompt, and the only way once it does not.

## Quick start

You need Docker. To write reports you also need an LLM API key (Anthropic by default); everything else works without one.

```sh
git clone https://github.com/michaelsking1993/community-voices && cd community-voices
cp .env.example .env    # then set LLM_API_KEY in .env, before the next line
docker compose up
```

That starts Postgres (with pgvector), crawls and embeds the last 2 weeks of the forum (about a minute; the first run also downloads a ~90 MB model), and serves the app on http://localhost:3000. For the full demo (A/B test, backtest, trends) start with 12 weeks instead, about 5 minutes: `BACKFILL_WEEKS=12 docker compose up`.

- **Changed `.env`?** Run `docker compose up` again (not `restart`, which keeps the old settings).
- **Port 5432 already taken** by a local Postgres? `DB_PORT=5433 docker compose up`.
- **The forum is unreachable?** The app still starts with what is stored; retry with the ingest command below.

Prefer Ruby on your machine? Run only the database in Docker, then:

```sh
docker compose up -d db
bin/setup
```

### Things to try

With Docker, put `docker compose exec app` in front of each command (for example `docker compose exec app bin/rails report:build`).

| Command | What it does |
|---|---|
| `bin/rails 'ingest:backfill[12]'` | Crawl, chunk and embed 12 full weeks (re-runs only fetch what is new). `IngestWeekJob` also runs every Monday at 6am while the app is up |
| `bin/rails 'retrieval:search[sync problems]'` | Search the way the report does |
| `bin/rails retrieval:eval` | Score retrieval on 15 hand-labelled queries (needs 12 weeks) |
| `bin/rails report:build` | Write last week's report (needs `LLM_API_KEY`), or press "Write report" on the Reports page |
| `bin/rails 'ab:run[1]'` | A/B test last week: three reports, checks, a support judge and a blind ranking (about $0.65). Set `LLM_JUDGE_MODEL` to judge with a different model |
| `bin/rails 'backtest:run[4]'` | Score the last 4 weeks' predictions against what happened next |

The Charts page (http://localhost:3000/charts) draws the A/B test, the backtest, the embedding map and the retrieval stats from whatever is in the database.

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
| `judgements` | What a judge concluded about a report: prediction scores (backtest), support checks and blind rankings (A/B) |
| `retrievals`, `retrieval_hits` | Every search the app runs: the query, window and settings, and each chunk it returned with its rank and distance |

## Shape of the system, and why

_To do._

## Built vs deferred

_To do._

## What could go wrong

_To do._

## How this was built

Planned first, then built in small pull requests with tests and green CI. The step pages in [`docs/steps/`](docs/steps) are the build diary; [`docs/concepts/`](docs/concepts) explains the RAG and vector-database ideas the code relies on.
