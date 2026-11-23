# Retrieval: getting the right evidence, not just the nearest

**In one line:** retrieval is the "R" in RAG. Embed the question, find the stored chunks nearest in meaning, then shape that list (filter, cut off, spread out) so the model gets good evidence instead of ten copies of the same thread.

## The knobs

| Knob | What it does | Ours | Too low | Too high |
|---|---|---|---|---|
| **top-k** | How many chunks come back | 8 | The model misses part of the story | Noise, cost, and the model skims |
| **Distance cut-off** | Drop chunks farther than this (cosine distance, 0 = same meaning) | 0.6 | Finds nothing for fair questions | "Nearest" junk gets in even when nothing is relevant |
| **Window** | A SQL date filter in the same query | the report's week | | |
| **Per-thread cap** | Most chunks from one forum thread | 2 | | One long thread fills every slot |

**Top-k always returns k things**, even when nothing is relevant: the nearest junk is still "nearest". The cut-off is what lets us say *"not enough evidence"* instead of handing the model unrelated posts and inviting it to make something up.

## Filtering and approximate search: a real gotcha

HNSW is *approximate*: it walks a graph and keeps the best `ef_search` candidates (40 by default). pgvector 0.6/0.7 applies the `WHERE posted_at ...` filter *after* that walk. With 12 weeks of data and a 1-week window, most of those 40 candidates are from other weeks and get thrown away, so you can get back 3 results when you asked for 8. Fixes:

| Fix | Trade-off |
|---|---|
| Raise `ef_search` for the query (ours: 200) | Slightly slower; works on any pgvector version |
| Exact scan (no index) for small windows | Exact and simple at this size; does not scale |
| pgvector 0.8 iterative scans (`hnsw.iterative_scan`) | Best fix, but needs 0.8+ |

## Diversity

Similarity alone rewards repetition. A 30-reply thread about one sync bug produces 30 nearly identical chunks, and they all rank next to each other. Two ways to spread results:

- **Per-thread cap (ours):** at most 2 chunks per thread. Easy to explain and directly fixes what we saw.
- **MMR (maximal marginal relevance):** pick each next chunk for being relevant *and* unlike the ones already picked. More general (also catches two threads that say the same thing), but has a weight to tune.

## Hybrid search (deferred)

Embeddings blur rare exact tokens: "25.09.2", "error 0x80070005", an add-on id. Postgres full-text search finds those exactly. *Hybrid* search runs both and merges the rankings. We deferred it: our questions are theme-shaped ("problems with sync"), not exact-string-shaped. The eval set below would tell us if that assumption breaks.

## How we know it works: a small eval set

`config/eval/retrieval.yml` has hand-written queries, each labelled with the forum threads a good answer should come from. `bin/rails retrieval:eval` reports, for plain top-k and for capped top-k:

- **hit rate:** share of queries where at least one right thread appears in the top k
- **recall:** share of the right threads that appear
- **threads:** how many different threads the top k covers

Measure before and after any change to chunking, the model, or these knobs. That is the habit that matters more than any particular number.

## Logging

Every call writes a `retrievals` row (query, purpose, window, settings, timing) and one `retrieval_hits` row per chunk. That answers "which posts does the report lean on most?" and "how often does a query come back empty?" with plain SQL, and feeds the stats page.
