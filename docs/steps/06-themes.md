# Step 6: Find the week's themes

## What we built

`Themes::Finder` groups a week's forum threads into 8 themes with k-means on their embeddings, counts threads, posts and people per theme in SQL, and asks Claude to name each one from a few titles and excerpts. Themes are stored in `themes` and `theme_topics`. This step also adds `Llm::Client`, the one place the app calls Claude, and `Week`, the Monday-to-Monday window everything is reported in.

## Why this way

- **Cluster threads, not posts.** A theme should be several threads about the same thing. Clustering posts would turn one 100-reply thread into its own "theme". Each thread gets the average of its chunk vectors from that week. (DECISIONS #23)
- **k-means with k = 8, seeded.** Simple, explainable, and deterministic: the same week always gives the same themes. HDBSCAN would pick k itself and leave outliers out, but has no Ruby implementation. (DECISIONS #24)
- **SQL counts, the model names.** Counting is exact in SQL and unreliable in a model. The model only turns a group of threads into a label, a one-line summary and a kind (problem, request, discussion, announcement, other). (DECISIONS #25)
- **One model call per week, structured output, low effort.** All clusters are named in one request with a JSON schema, so the answer is parsed, not scraped from prose. Naming is easy, so it runs at low effort. (DECISIONS #26)
- **The client is injected.** Specs pass `FakeLlm`, so no test calls the API or needs a key. Every response carries its tokens and cost, which the A/B step compares.

## How it works

```
Themes::Finder.call(week)
  SELECT topic_id, avg(chunks.embedding)          one vector per thread, that week only (SQL)
  Themes::KMeans(k: 8)                            spherical k-means, k-means++ seeding, seed 42
  per cluster: 12 titles + 5 excerpts             closest threads to the centre first
  Llm::Client#json(schema: themes[])              one call: label, summary, kind per cluster
  SQL: threads, posts, distinct authors           per theme
  INSERT themes + theme_topics                    re-running a week replaces it
```

`Llm::Client` uses the official `anthropic` gem, the model from `ANTHROPIC_MODEL` (default `claude-opus-5-5`), structured outputs, and server-side fallbacks (if a safety check declines, the API retries on another model instead of failing). It raises a clear error when the key is missing or the answer was cut off.

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

## What I learned

Clustering finds structure nobody named; the model is only needed at the end, to turn each group into words. Splitting the work this way keeps every number exact (SQL) and every label grounded in real excerpts. The choice of *what* a point is (a thread, not a post) matters as much as the algorithm.

## What I would do next

- HDBSCAN, or merge and drop clusters by a similarity threshold, instead of a fixed k.
- Track a theme across weeks by comparing centroids, for trend lines (step 8 uses retrieval for this instead).
- Show each theme's threads on the 2D map (step 9).
