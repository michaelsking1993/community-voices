# Step 6: Find the week's themes

## What we built

`Themes::Finder` groups a week's forum threads into themes with k-means on their embeddings (about one theme per 12 threads, between 4 and 8), counts threads, posts and people per theme in SQL, and asks the LLM to name each one from a few titles and excerpts. Themes are stored in `themes` and `theme_topics`. This step also adds the `Llm` interface, the one place the app calls a language model (with an Anthropic adapter as the default provider), and `Week`, the Monday-to-Monday window everything is reported in.

## Why this way

- **Cluster threads, not posts.** A theme should be several threads about the same thing. Clustering posts would turn one 100-reply thread into its own "theme". Each thread gets the average of its chunk vectors from that week. (DECISIONS #23)
- **k-means, seeded, with k from the week's size.** Simple, explainable, and deterministic: the same week always gives the same themes. k is about one theme per 12 threads, between 4 and 8; see "Choosing k" below. HDBSCAN would pick k itself and leave outliers out, but has no Ruby implementation. (DECISIONS #24)
- **SQL counts, the model names.** Counting is exact in SQL and unreliable in a model. The model only turns a group of threads into a label, a one-line summary and a kind (problem, request, discussion, announcement, other). (DECISIONS #25)
- **One LLM call per week, structured output, low effort.** All clusters are named in one request with a JSON schema, so the answer is parsed, not scraped from prose. Naming is easy, so it runs at low effort. (DECISIONS #26)
- **Provider-neutral and injected.** Callers depend on a small `Llm` interface (`json(system:, prompt:, schema:)`), not on a vendor. `LLM_PROVIDER` picks the adapter; Anthropic is the only one so far. Specs pass `FakeLlm`, so no test calls an API or needs a key. Every response carries its tokens and cost, which the A/B step compares. (DECISIONS #26)

## How it works

```
Themes::Finder.call(week)
  SELECT topic_id, avg(chunks.embedding)          one vector per thread, that week only (SQL)
  Themes::KMeans(k: threads / 12, 4..8)           spherical k-means, k-means++ seeding, seed 42
  per cluster: 12 titles + 5 excerpts             closest threads to the centre first
  Llm.client.json(schema: themes[])               one call: label, summary, kind per cluster
  SQL: threads, posts, distinct authors           per theme
  INSERT themes + theme_topics                    re-running a week replaces it
```

`Llm.client` returns the adapter for `LLM_PROVIDER` (default `anthropic`). The Anthropic adapter (`Llm::Anthropic`) uses the official `anthropic` gem, the key and model from `LLM_API_KEY` and `LLM_MODEL` (the same names for every adapter), structured outputs, and server-side fallbacks (if a safety check declines, the API retries on another model instead of failing). Any adapter raises `Llm::NotConfigured` when the key is missing and `Llm::Failed` when the answer was cut off or declined. Adding a provider means one new adapter class and one line in `Llm::PROVIDERS`.

Try it: `bin/rails themes:find` (last complete week) or `bin/rails 'themes:find[2026-11-16]'`.

## Check: do the themes match the forum?

Week of 2026-11-16: 309 posts in 103 threads, 99 of them with enough text to embed. Clustered in about a second. The groups before naming, by their closest threads:

| # | Threads | Posts | Closest threads |
|---|---|---|---|
| 1 | 20 | 71 | AnkiMobile 26.10 beta and release, "Undo 26.10 update", cards flashing |
| 2 | 19 | 63 | Missing decks, cards deleted by sync, "restore deleted decks" |
| 3 | 12 | 44 | AI add-ons and resources, "migrating to a neural net" |
| 4 | 18 | 39 | "Anki keeps crashing", error messages (also a translation request: a mixed cluster) |
| 5 | 9 | 36 | Refunds for accidental purchases, AnkiHub feedback, search field |
| 6 | 12 | 33 | Deck overview counts, extra Browser columns |
| 7 | 8 | 14 | AnkiMobile 26.10 toolbars and colours ("bring back Liquid Glass") |
| 8 | 1 | 5 | One thread about a Mac shortcut |

That matches a skim of the forum that week: the AnkiMobile 26.10 release dominates (themes 1 and 7), followed by lost data and sync. Theme 4 shows k-means' weakness: every thread must join some group, so a few one-off threads make it mixed.

## Choosing k

I first picked 8 by judgment (about 100 threads a week, about 12 each), then measured k = 4 to 12 on three real weeks:

| Week (threads) | k | Cluster sizes | Clusters of 1-2 threads | Silhouette |
|---|---|---|---|---|
| Nov 16 (99) | 6 | 25, 25, 17, 14, 13, 5 | 0 | 0.10 |
| | **8** | 20, 19, 18, 12, 12, 9, 8, 1 | 1 | 0.10 |
| | 10 | 18, 17, 13, 12, 10, 8, 7, 7, 6, 1 | 1 | 0.09 |
| | 12 | 19, 16, 10, 9, 8, 8, 7, 6, 6, 5, 4, 1 | 1 | 0.07 |
| Nov 2 (56, quiet) | 4 | 20, 16, 10, 10 | 0 | 0.05 |
| | 6 | 17, 12, 10, 10, 6, 1 | 1 | 0.07 |
| | 8 | 18, 11, 9, 7, 7, 2, 1, 1 | **3** | 0.08 |
| | 12 | 16, 10, 6, 6, 5, 4, 2, 2, 2, 1, 1, 1 | **6** | 0.09 |

What this says:

- **There is no "natural" k.** Silhouette (how much closer a thread is to its own cluster than to the next one; 1 is perfect, 0 is no structure) stays between 0.05 and 0.12 for every k. That is normal for text: topics blend into each other. So k is a reporting choice, not a fact about the data.
- **A fixed 8 splinters quiet weeks.** On the 56-thread week, 3 of 8 "themes" had one or two threads.
- **So k scales with the week:** about one theme per 12 threads, between 4 and 8. A busy week (93-99 threads) gets 8, the quiet one gets 5. The report then covers every theme with at least 2 threads (it covered only the top 6 until 2026-11-24, DECISIONS #55).

## Key takeaways

Clustering finds structure nobody named; the LLM is only needed at the end, to turn each group into words. And k-means always returns k groups whether or not the data has k groups in it, so k has to be justified by what the reader needs, then sanity-checked on real weeks. Splitting the work this way keeps every number exact (SQL) and every label grounded in real excerpts. The choice of *what* a point is (a thread, not a post) matters as much as the algorithm.

## Possible next steps

- HDBSCAN, or merge and drop clusters by a similarity threshold, instead of choosing k.
- Track a theme across weeks by comparing centroids, for trend lines (step 8 uses retrieval for this instead).
- Show each theme's threads on the 2D map (step 9).
