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

Read this carefully: 13 scored predictions is a small sample, so the numbers show the method works, not that the predictor is good or bad. The one real signal is that "high" confidence did **not** beat "low": the stated confidence is not yet worth trusting, which is exactly what a calibration check is for. Only 2 high-confidence predictions could be scored, and 2 more "high" ones had no evidence either way.

## What to understand

- Why the future is allowed in the scorer but nowhere else.
- Why a judge that can only cite what it was shown is more trustworthy than one that remembers.
- Why "could not tell" is not the same as "wrong".

## Check yourself

1. If a trend signal quietly used data from the week it predicts, what would the hit rate look like, and how would you notice?
2. High-confidence predictions scored lower than low ones. Name two reasons that could be true besides "the model is bad".
3. Why does the backtest reuse stored reports rather than re-writing them?

## What I would do next

- Score more weeks (each costs about $0.15 for the report) before drawing conclusions.
- Compare against a dumb baseline ("next week looks like this week") to see whether the LLM adds anything.
- Calibrate: tell the model how often each confidence level has been right.
