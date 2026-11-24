# Step 9: Backtest the predictions

## What we built

A way to ask "were last month's predictions any good?" without waiting a month. For each past week whose following week is complete, `Backtest::Run` takes (or writes) the RAG report for that week, then `Backtest::Scorer` scores each of its predictions against the posts of the week they were about. `Backtest::Summary` turns the verdicts into hit rates by confidence and by basis. Run it with `bin/rails 'backtest:run[4]'`.

## Why this way

- **Honest by construction.** Every query behind a report (themes, retrieval, trend counts, releases) is bounded by the end of the report's own week, so a report for an old week cannot see what came next. A spec plants a post in the following week and checks it never reaches the prompt or the saved evidence. Only the scorer looks forward. (DECISIONS #39)
- **Judge shown evidence, not asked to remember.** For each prediction the scorer retrieves the closest posts from the following week and an LLM says happened, partly, did_not_happen or no_evidence. A verdict that cites nothing real is demoted to no_evidence in code. (#36, #37)
- **A scale that admits "can't tell".** happened = 1, partly = 0.5, did_not_happen = 0. no_evidence is counted but left out of the rate, so quiet topics do not look like failures. (#38)
- **Reuse what is stored.** A stored report for week W was already written from pre-W data, so the backtest only pays for what is missing. (#40)

## How it works

```
Backtest::Run.call(weeks)
  report   latest stored RAG report for the week, else Reports::Builder.call(week)
  Scorer   for each prediction: Retriever(claim, window: the FOLLOWING week, k 5, 1 per thread)
           one LLM call: exact counts for that week + the posts per prediction -> verdicts
           code: keep only evidence ids that were shown; happened/partly with none -> no_evidence
           save Judgement(kind: "prediction", data: results + scored_week)
Summary    hit rate overall / by confidence / by basis
```

## Check: live run on the Anki forums

Four weeks (10-19 to 11-09 reports, scored against the week after each), about $0.14 of judge calls on top of the reports:

| | scored | hit rate | happened / partly / did not | could not tell |
|---|---|---|---|---|
| all | 13 | 0.42 | 2 / 7 / 4 | 5 |
| low confidence | 5 | 0.50 | 1 / 3 / 1 | 1 |
| medium | 6 | 0.42 | 1 / 3 / 2 | 2 |
| high | 2 | 0.25 | 0 / 1 / 1 | 2 |
| basis: trend | 5 | 0.50 | | |
| basis: event | 6 | 0.42 | | |
| basis: recurring | 2 | 0.25 | | |

Read this carefully:

- 13 scored predictions is a small sample, so the numbers show the method works, not that the predictor is good or bad.
- 5 of 18 predictions (28%) were left out as "could not tell". Counting them as misses would give 0.31.
- 7 of the 13 were "partly", worth half each. Counting only full hits, the strict rate is 2 of 13, about 0.15.
- "High" confidence did not beat "low", but only 2 high-confidence predictions could be scored. That is a hint that the stated confidence is not yet worth trusting, not a finding.

**Second run, from scratch on my machine (2026-11-24).** Same 4 weeks, new reports: 10 scored, hit rate **0.45** (1 happened, 7 partly, 2 did not, 7 could not tell). Low and high confidence both scored 0.50 (2 each), medium 0.42. By basis: trend 0.38, recurring 0.50, event 0.50. So the overall rate held steady (0.42 then 0.45), while the per-confidence and per-basis splits moved around, as you'd expect from 2 to 6 predictions each. Confidence still doesn't separate hits from misses.

Known limits:

- **The judge.** It is the writer's own model unless `LLM_JUDGE_MODEL` is set, and a model can be kind to its own claims.
- **Edits after the fact.** Posts and thread titles are stored as they look on the day of the crawl. A later edit ("EDIT: fixed in 26.10.1") or a renamed beta thread can reach an old week's report, including the release/beta detector, which matches on titles. Small, but not zero.

## What to understand

- Why the future is allowed in the scorer but nowhere else.
- Why a judge that can only cite what it was shown is more trustworthy than one that remembers.
- Why "could not tell" is not the same as "wrong".

## Check yourself

1. If a trend signal quietly used data from the week it predicts, what would the hit rate look like, and how would you notice?
2. High-confidence predictions scored lower than low ones. Name two reasons that could be true besides "the model is bad".
3. Why does the backtest reuse stored reports rather than re-writing them?

## Possible next steps

- Score more weeks (each costs about $0.15 for the report) before drawing conclusions.
- Compare against a dumb baseline ("next week looks like this week") to see whether the LLM adds anything.
- Calibrate: tell the model how often each confidence level has been right.
