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

The rest of this README is laid out like a system-design answer: the problem, the questions and assumptions, the entities, the shape of the system and why, what was built and what was deferred, and what could go wrong.

**Input.** One active online community: the Anki forums, a public Discourse site. A normal week is about 310 posts in about 100 threads by about 110 people, roughly 50,000 tokens of text.

**Output.** Every week, a Community Voices document: what the community talked about last week, and what it will probably talk about next week.

**What the challenge requires**

- Fill a vector store automatically with the community's posts, every week, without drowning in data.
- Use RAG to write the document.
- Show a flattened view of the embeddings, and keep stats on which embeddings are retrieved most.
- A/B test: the same document written with and without RAG, compared inside the app.

**What I added as requirements of my own**

- **Every claim can be traced to a post.** A report that sounds right but cannot be checked is worse than no report.
- **Numbers are exact.** Post and thread counts come from SQL, never from the model.
- **A reviewer can run it from `git clone`.** Docker, one optional API key, and everything except writing reports works without one.
- **Re-running is cheap.** Only new or changed text is ever fetched or embedded.

**What makes it interesting.** A week of posts *fits* in a modern context window. So RAG has to beat "paste the whole week into the prompt", not just "ask the model with nothing". And "next week" cannot be checked until it has happened, so predictions need a backtest to mean anything.

## Questions I asked, and the assumptions I made

Every call is in [`DECISIONS.md`](DECISIONS.md) (52 rows: the question, the options, the trade-off, the choice). The assumptions that shape everything else:

- **"A week" is Monday to Monday** (#27), so "last week" and "next week" are unambiguous, and partly crawled weeks are left out of counts and trends (#51).
- **The community is its public posts.** Private messages and staff-only posts are not in the public API, so our post counts are lower than the forum's own (topic counts match within 2; [step 3](docs/steps/03-ingest.md)).
- **The scale is thousands of chunks, not millions** (12 weeks is about 3,400 chunks), so the vectors live in Postgres, next to the posts they came from (#2).
- **The model writes words; SQL counts** (#25). The model labels themes and writes the report; it never produces a number.
- **Reports are outputs, never sources** (#31). The model never retrieves its own earlier claims.

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

```
 INGEST (weekly job, Mondays 6am, Solid Queue)
   forums.ankiweb.net ─► Crawler ─► topics, posts ─► Chunker ─► local embedder ─► chunks
                         1 req/s,                    150 words,  MiniLM, 384 dims   vector(384),
                         upsert by id                header, hash                   HNSW index

 WRITE A REPORT (for one week)
   Themes      k-means over thread vectors; SQL counts threads, posts, people; the LLM names each
   Retrieve    per theme: Retriever(label + summary), week window, cut-off 0.6, max 2 per thread,
               a chunk budget shared by theme size, plus each theme's 2 busiest threads
               + 3 look-alikes from earlier weeks, trend counts, beta and release threads
   Generate    one structured LLM call: report + predictions, citing numbered evidence [E1]..
   Check       code: citations point at real posts, quotes are word for word, uncited sentences

 EVALUATE
   A/B         the same builder with three evidence sources: none, paste the whole week, RAG
               + a support judge and a blind ranker
   Backtest    score past predictions against the week that followed
   Charts      A/B, backtest, PCA map of every thread, retrieval stats from the retrieval log
```

Why this shape:

- **One Postgres does everything.** Posts, vectors, jobs and the retrieval log share one database, so a date filter and a vector search are one SQL query, and a reviewer runs one service. A dedicated vector database earns its keep at hundreds of millions of vectors, not 3,400. (#2, #6; [when a vector DB helps](docs/concepts/vector-databases.md))
- **Find the themes first, then retrieve per theme.** "What did people talk about?" is not one search query. Clustering the week's threads gives the questions, and one retrieval per theme gives each section its own evidence, so a quiet theme is not drowned by a loud one. (#23, #28)
- **Retrieval is more than "nearest".** Nearest *and* close enough (a cut-off, so "not enough evidence" is possible) *and* not all one thread *and* in the right week. Each knob was set by measuring on a hand-labelled eval set. And because "what sounds like this theme?" is not "what was big this week?", SQL also picks each theme's busiest threads and vectors pick their best chunk. (#18, #19, #20, #53; [step 5](docs/steps/05-retrieval.md))
- **Grounding is designed in, then checked in code.** Numbered evidence, cite-or-omit, word-for-word quotes, SQL numbers, and no model call at all when nothing relevant is found. (#29, #30; [grounded prompting](docs/concepts/grounded-prompting.md))
- **The LLM sits behind an injected interface.** Specs use a fake; the provider is a setting (`LLM_PROVIDER`), and every call records tokens and cost, which the A/B needs. (#26)
- **Embeddings are local.** No second key, no cost per embedding, and the model is the same in tests, the concepts lab and production. (#16)
- **Too much data is handled at both ends.** Ingest is incremental (upserts, a content hash, only the last 8 days re-fetched), and retrieval keeps the prompt at about 17,000 tokens however much history is stored. Pasting grows with the data; retrieval grows with the question. (#8, #15)
- **Evaluation lives in the app.** The A/B test, the judges and the backtest are rake tasks that write to tables the Charts page reads, so anyone can re-run them. (#43, #39)

## Built vs deferred

Everything the challenge asks for is built (see the table at the top). These were cut on purpose while planning, before any code, so the time went into evaluation instead.

| Deferred | What it is | Why not now | When it would be worth it |
|---|---|---|---|
| **Tree RAG** | Summarise clusters, then summaries of summaries, and retrieve at the level a question needs (vanilla RAG retrieves raw chunks only) | A week is about 50,000 tokens, and the themes already act as a one-level tree: cluster the threads, then retrieve within each cluster | When a report covers months: 12 weeks would be about 750,000 tokens |
| **Hybrid search** | Postgres full-text search alongside the vectors, merged by rank | Report queries are about themes, not exact strings. Vector-only found a right thread for every one of the 15 eval queries (#21) | For version numbers ("26.09.2") and error messages; the eval set is the tripwire |
| **A second forum** | Ingest another community, e.g. a subreddit or another Discourse site | One source proves the pipeline. A second adds a client and a source column, not a new idea, and Reddit's API is gated (#1) | When the product is "any community"; the crawler is already behind one client class |
| **PDF export** | A printable file | The challenge accepts a web page. Reports render in the app and download as Markdown | When readers want a file to send around |
| **Automatic theme counting** | Let the data choose the number of themes (HDBSCAN, or agglomerative clustering with a distance threshold) | I measured k = 4 to 12 on three weeks: silhouette stays at 0.05 to 0.12, so there is no natural number to find. HDBSCAN has no Ruby library. k = threads / 12, kept between 4 and 8, avoids one-thread themes (#24) | If mixed themes (one-off threads forced into a group) start hurting reports |

Smaller items are listed under "What I would do next" on each [step page](docs/README.md): MMR instead of the per-thread cap, a token-exact chunk splitter, tracking post edits, pgvector 0.8 iterative scans, and more A/B weeks.

## What could go wrong

| Risk | Seen? | What is in place | What is left |
|---|---|---|---|
| **Retrieval misses a big thread.** No theme's query lands near it, so the model never sees it | Yes: the first A/B run missed the week's second-biggest thread, which paste-all covered ([step 10](docs/steps/10-ab-test.md)) | A chunk budget shared by theme size, and each theme's 2 busiest threads always included (#53). On the rerun the judge's coverage score went from 3 to 5 | Checked on one week only. A big thread in a theme outside the top 6 can still be missed |
| **The model invents details** | The blind judge counts several "invented" specifics in both grounded reports; for RAG some are trend counts and earlier-week references its facts cannot confirm either way | Cite-or-omit, code checks on every citation and quote, SQL-only numbers, no call without evidence, a support judge | Specifics in prose can still slip through; the support judge is a model too |
| **The judge is biased or noisy** | One week, one judge, one shuffled order | A different judge model (`LLM_JUDGE_MODEL`), reports shuffled and stripped of citation ids | More weeks, each ranked in two orders |
| **Themes are mixed** | Yes: k-means puts every thread in some group, so one-off threads join the nearest theme | Only themes with 2 or more threads are written up; the LLM sees titles and excerpts when naming | Threshold or density clustering (deferred above) |
| **Confidence means little** | High-confidence predictions scored 0.25 against 0.50 for low, on only 2 scored high ones | The backtest measures it ([step 9](docs/steps/09-backtest.md)) | Score more weeks; tell the model how often each level has been right |
| **A report peeks at the future** | Not seen | Every query is bounded by the report's week; a spec plants a future post and checks it never reaches the prompt | Posts edited or threads renamed after the fact can still leak a little |
| **The forum is slow, down or changes** | Not in a live run; guarded anyway | Retries on 429, 5xx and timeouts; the app starts with stored data if the crawl fails (#52) | A change to the API's shape would only show on a live run, since specs use fixtures |
| **A filtered vector search comes back short** | Yes: a flaky spec and a short 1-week window ([step 5](docs/steps/05-retrieval.md)) | `hnsw.ef_search` raised to 200 for every search | pgvector 0.8 iterative scans |
| **Growth** | 12 weeks is about 3,400 chunks and about 15 minutes to embed on CPU the first time | Incremental embedding (content hash), retrieval keeps the prompt small | A hosted or GPU embedder for a much larger forum |

## How I built it: a learner's approach

I know Rails and Postgres well. I did not know RAG or vector databases beyond the buzzwords. This challenge was a chance to learn both properly, so I set up the work so that I understood each piece before it was merged, not after. The [step pages](docs/README.md) are the diary of that.

### Plan before code

Before any code, I wrote a plan with an AI assistant: which community, which stack, the shape of the pipeline, how the A/B test would be fair, and what to cut. Nothing was built until I had made every open decision in it. The deferred list above was decided then, not when time ran out.

### One loop for every step

The build is 11 steps. Each one went through the same five beats:

| Beat | What happened |
|---|---|
| **Learn** | The idea explained before any code, and I predicted the result or explained it back |
| **Decide** | The options and the trade-off, written down as a [DECISIONS.md](DECISIONS.md) row |
| **Build** | One small pull request with tests and green CI |
| **Check** | Run on real forum data and measured, not just "it runs" |
| **Document** | One page in [`docs/steps/`](docs/steps): what we built, why, how it works, what I learned, what next |

### Guess, then measure

The [concepts lab](docs/steps/02-concepts-lab.md) came before any app code. I guessed which of six forum-style sentences were most alike, then we embedded them with the model the app uses. My ranking was right ("make the card text bigger" and "change the font size" closest; "font size" and "network error" furthest), but I guessed 0.8 for the pair about losing data on sync, and it measured 0.37.

That miss set a rule for the whole project: never pick a threshold by feel. The retrieval cut-off (0.6), the number of themes and the trend distance (0.35) were each chosen from a sweep on real data, and the sweeps are on the step pages.

### Questions to check myself

The later step pages end with "Check yourself" questions, such as "Paste-all scored a bit higher than RAG. Why is RAG still the right design for this app?" They are there so I can explain each step, not just run it. The [concepts](docs/concepts) pages are the short explanations I wanted when I started.

### Small, tested pull requests, and decisions in writing

The work landed as about a dozen small pull requests, each reviewed and merged before the next one built on it. CI runs a security scan, lint, the RSpec suite against a real pgvector Postgres, and a `docker compose` build, so the reviewer's path is tested too. The embedding model and the LLM are injected, so specs use fakes and never touch the network. [DECISIONS.md](DECISIONS.md) records every call with its trade-off, and when a later finding overturned one, the new row says what it supersedes (#49 supersedes part of #41).

### Reviews and real data caught real problems

Pull requests were reviewed by a fresh AI session that had not written them, and then by me: tests first, code second. Some of what that, and running on real data, caught:

- **The A/B test was unfair to the rival.** The paste-all arm pasted overlapping chunks, which inflated its cost by about 40%, and it was handed our themes, which leaked the RAG pipeline into it. I rebuilt it as "each post once, no themes" and re-ran it (#49). RAG's cost advantage shrank from 3.1 times to 2.7 times, and the write-up says so.
- **The judge was marking its own homework.** The judges defaulted to the model that wrote the reports. `LLM_JUDGE_MODEL` now lets a different model judge, and the published run uses one (#44, #50).
- **RAG missed the week's second-biggest thread.** The blind judge spotted it. The thread was in the right theme, but every theme got 6 chunks however big it was, and a query built from a theme's centre cannot see a big thread at its edge. Sharing the budget by theme size and always including each theme's busiest threads took the judge's coverage score from 3 to 5, nearly level with paste-all at about a third of the cost (#53). Step 10 keeps both runs side by side.
- **My own answer key was wrong.** One retrieval eval query "failed" because the retriever found a relevant thread I had not labelled. Hand labels are a starting point, not ground truth.
- **Real data broke assumptions.** Forum post ids are only roughly in date order, so the first crawler stopped early. A half-crawled oldest week made activity look like it was rising. Both have specs now.

### Openly AI-assisted

I built this with an AI coding assistant, which wrote most of the code. I owned the decisions: the plan, every row in DECISIONS.md, and every merge, after reading the specs and the diff. [`docs/notes.md`](docs/notes.md) are my running notes in my own words; the assistant drafted an entry after each step and I edited it. The honest summary is that the assistant made me faster, and the loop above made sure I still understand what was built and why.
