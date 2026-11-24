# Step 5: Retrieval

## What we built

`Search::Retriever` turns a question into evidence: it embeds the query, finds the nearest chunks inside a date window, drops anything too far away to count, keeps at most 2 chunks per forum thread, and logs every call to `retrievals` and `retrieval_hits`. A hand-labelled set of 15 queries (`config/eval/retrieval.yml`) and `bin/rails retrieval:eval` measure how well it works.

## Why this way

- **A distance cut-off, not just top-k.** Top-k always returns k chunks, even for "chocolate cake recipe". The cut-off (cosine distance 0.6) is what lets the report say "not enough evidence" instead of handing the model junk. (DECISIONS #19)
- **At most 2 chunks per thread.** Step 4 showed one long thread filling 4 of the top 5. A per-thread cap is simple to explain and fixes exactly that. MMR is the more general tool but needs a weight tuned. (DECISIONS #18)
- **The date filter runs in the same SQL query as the vector search.** That is the reason vectors live in Postgres (DECISIONS #2). One catch: HNSW only looks at 40 candidates by default and the filter is applied after, so a 1-week window over 12 weeks of data can come back short. We raise `hnsw.ef_search` to 200 for the query. (DECISIONS #20)
- **Vector-only, not hybrid.** Our queries are about themes, not exact strings like version numbers. Deferred, with the eval set as the tripwire. (DECISIONS #21)
- **Log every retrieval.** One row per query and one per hit. It feeds the "most retrieved" stats and lets the A/B page show exactly what each arm saw. (DECISIONS #22)

## How it works

```
Search::Retriever.call("sync problems", window: week.range)
  embed the query                         LocalModel (or a fake in specs)
  SET LOCAL hnsw.ef_search = 200
  SELECT chunks nearest by <=>            WHERE posts.posted_at IN window  LIMIT 100
  drop distance > 0.6                     nothing left? empty result = "not enough evidence"
  keep <= 2 per topic, take 8
  INSERT retrievals + retrieval_hits
```

Try it: `bin/rails 'retrieval:search[sync problems]'` (add `,7` to limit it to the last 7 days).

## Check: does it find the right threads?

On 12 weeks of real data (3,398 chunks), 15 queries worded differently from the thread titles:

| | Hit rate | Recall | Threads in top 8 |
|---|---|---|---|
| Plain top-8 | 1.00 | 0.52 | 3.9 |
| Max 2 per thread | 1.00 | 0.54 | **5.5** |

Off-topic queries ("chocolate cake recipe", "stock market predictions") all came back empty.

- **Hit rate** is the share of queries where at least one right thread made the top 8. Every query did.
- **Threads covered** went from 3.9 to 5.5: same relevance, much less repetition. That is what the report needs.
- **Recall** barely moved. Most queries have 4 to 8 right threads and only 8 slots, so the cap mainly swaps duplicates for neighbours.

**Choosing the cut-off.** Relevant chunks sat at distance 0.27 to 0.65; the nearest chunk for an off-topic query was never closer than 0.71. A sweep:

| Cut-off | 0.50 | 0.55 | **0.60** | 0.65 | 0.70 |
|---|---|---|---|---|---|
| Hit rate | 0.80 | 0.93 | **1.00** | 1.00 | 1.00 |
| Off-topic empty | 4/4 | 4/4 | **4/4** | 4/4 | 4/4 |

0.6 is the lowest value that finds every query, leaving a margin below the off-topic floor.

**The eval set had a mistake too.** "Use a machine learning model to schedule reviews" first scored a miss. The retriever's top hit was a feature request for "AI-assisted" scheduling that I had not labelled. It was right and my answer key was wrong, so I added that thread. Hand labels are a starting point, not ground truth.

**A flaky test found the same gotcha again.** `Chunk.similar_to` sometimes returned 1 result instead of 2 in the test suite. Each spec rolls back its rows, but HNSW keeps the dead entries in the index, and they used up the 40 default candidates. `Chunk.with_ef_search` now raises the limit for both the console helper and the retriever.

## Key takeaways

Retrieval quality is not "the nearest chunks". It is nearest *and* close enough *and* not all from one place *and* in the right time window. Each of those is a knob, and the only honest way to set a knob is a small labelled test set you re-run after every change. A cut-off is what turns "always say something" into "say nothing when there is nothing to say", which is the base of a report that does not invent.

## Possible next steps

- Hybrid search (Postgres full-text plus vectors, merged by rank) for exact strings like "26.09.2" or error messages.
- MMR instead of a per-thread cap, to also skip two different threads that say the same thing.
- Upgrade to pgvector 0.8 iterative scans and drop the `ef_search` workaround.
- A larger, independently labelled eval set; 15 queries labelled by one person is a smoke test, not a benchmark.
