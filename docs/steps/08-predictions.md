# Step 8: Predict next week

## What we built

The report now ends with 3 to 5 predictions for next week, each with a claim someone could check, a reason with citations, a basis (trend, recurring, or event) and a confidence. They come from three signals that `Reports::Signals` adds to the RAG arm's evidence: weekly trend counts per theme, look-alike posts from earlier weeks (step 7), and the betas and releases active in the last two weeks.

## Why this way

- **Trends from vectors plus SQL.** For each theme, count the posts per week, over 6 weeks, that have a chunk within cosine distance 0.35 of the theme's centre. The theme was found this week, but this asks "how much did people talk about *this* in earlier weeks?" (DECISIONS #33)
- **Known events as citable evidence.** Beta and release threads (by category or title) from the last 14 days are added as numbered evidence, so a prediction like "26.11 will ship" can cite the beta thread. (DECISIONS #34)
- **Checkable claims, stated confidence.** The prompt asks for claims that can be checked against next week's posts, and for "high" only when several signals agree. That is what makes the backtest in step 9 possible. (DECISIONS #35)
- **Nothing from the future.** Every signal uses only data from before the end of the report's week. Run the builder for an older week and it cannot see what happened next. A spec checks a future beta does not leak in.
- **Same call as the report.** One LLM call writes both halves, so each A/B arm has one cost and one set of checks. Grounding also checks the citations in each prediction's reasoning.

## How it works

```
RagEvidence.call(week, themes)
  ...per-theme evidence (step 7)...
  Signals.call(week, themes, evidence)
    trends   for each of the last 6 weeks:
               SELECT count(DISTINCT posts.id) WHERE posted_at in that week
                 AND (chunks.embedding <=> theme.centroid) < 0.35
             "Theme 1 (AnkiMobile 26.10 ...): 4, 4, 3, 3, 38, 25"
    events   threads in Beta Testing / Announcements, or titled release/beta,
             with posts in the last 14 days: newest chunk added as [E55]..

Builder prompt:  "# Signals for next week (2026-11-23 to 2026-11-29)" + trends + events
Schema:          predictions[{claim, reasoning, basis, confidence, theme}]
```

## Check: are the signals real?

For the week of 2026-11-16, the trend lines read:

| Theme (closest thread) | 6 weeks of posts, last = this week |
|---|---|
| AnkiMobile 26.10 beta and release | 4, 4, 3, 3, **38, 25** |
| Missing decks after sync | 28, 17, 25, 12, 36, 41 |
| AI add-ons | 8, 8, 14, 3, 22, 16 |
| Crashes and error messages | 16, 21, 14, 3, 26, 30 |
| AnkiMobile feedback and refunds | 12, 12, 6, 3, 36, 27 |
| Deck overview counts | 6, 1, 3, 3, 6, 13 |

The AnkiMobile 26.10 release (2026-11-09) shows as a jump from about 4 posts a week to 38, then 25: exactly the kind of decay a prediction should talk about. Lost decks are a steady background of 12 to 41 a week. The events found were the AnkiMobile 26.10.1 release, the 26.10.x beta thread (already mentioning 26.10.2), the Anki 26.11 Beta 1, and the experimental editor test.

**Choosing 0.35.** At 0.45 every theme counted 25 to 140 posts a week, because all chunks share the "Topic / Category / Date" header and sit fairly close to every centre. At 0.35 the counts are small and the 26.10 spike stands out clearly. The numbers are a rough signal for the LLM, not exact topic counts, and the prompt says so.

_Live predictions: to do once the API key is set; the backtest in step 9 scores them._

## What I learned

Predicting "what people will talk about" is mostly reading signals that already exist: a spike decaying after a release, a steady background problem, a beta that will become a release. Retrieval's job here is to find those signals in history; the LLM's job is to weigh them and say how sure it is. Making predictions checkable and forbidding future data is what turns them from a guess into something you can score.

## What I would do next

- Track themes across weeks by matching centroids, so trends are per theme rather than "posts near this week's centre".
- Use Discourse's own "latest" ordering and the release calendar (GitHub tags) as extra event signals.
- Calibrate confidence against backtest results: if "high" is right only half the time, say so.
