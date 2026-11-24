# Step 10: A/B test RAG against the alternatives

## What we built

The challenge asks how an LLM does *without* RAG. We wrote the same weekly report three ways and compared them:

| Arm | What the model gets |
|---|---|
| `none` | The week's dates only. This is "just ask an LLM". |
| `paste_all` | The week's exact counts, then every post of the week once, cleaned, grouped by thread with each title once. No search, no themes (about 64,000 tokens). |
| `rag` | Themes, then retrieval per theme: a few posts from this week plus 3 similar posts from earlier weeks, plus trend counts and release threads (about 15,000 tokens). |

Run it with `bin/rails 'ab:run[1]'` (add `LLM_JUDGE_MODEL=claude-sonnet-5-5` for a judge that did not write the reports); see it on the Charts page. The three reports from the run below are in [`docs/samples/`](../samples).

## Why this way

- **One builder, one schema, one set of checks.** Arms are `Reports::Builder` with a different evidence source, so only the context differs. (#32, #41)
- **Paste-all is the rival that matters.** A week fits in the model's context, so "RAG vs nothing" would be a weak test. It is the honest version of "just paste it": each post once (not overlapping chunks), each thread title once, and none of our pipeline (no themes, trends or release list), only the exact counts both grounded arms get. It finds its own topics. (#41, #49)
- **"No context" really means none.** Giving the baseline our themes would leak our pipeline into it. (#42)
- **Three ways to judge, from objective to soft:** checks in code, a support judge that reads each cited sentence next to only its sources, and a blind ranker that sees shuffled, unlabelled reports plus exact facts about the week. (#43)
- **The judge is a different model**: `LLM_JUDGE_MODEL`. Unset, the judge is the writer's own model, which may favour its own style; the run below used Sonnet to judge Opus. (#44, #50)

## How it works

```
Ab::Run.call(week)
  for arm in rag, paste_all, none:  stored report, else Builder for that arm
  SupportJudge  per report: sentences with [E] ids, each with only its cited posts -> supported / partly / unsupported
                (sentences citing nothing real are "unsupported" without asking; no citations, no call)
  Ranker        one call: reports shuffled (seeded by the week), citations removed, plus exact counts
                and the 40 biggest threads -> coverage, accuracy, specificity, usefulness (1-5), ranking
Ab::Comparison  averages per arm over weeks that have all three
```

## Check: live run, week of 2026-11-16, about $0.63 in all

Reports written by `claude-opus-5-5`; support judge and blind ranker `claude-sonnet-5-5`.

| | RAG | Paste whole week | No context |
|---|---|---|---|
| Input tokens per report | 14,777 | 63,773 | 1,029 |
| Cost per report | $0.130 | $0.348 | $0.035 |
| Seconds | 31 | 44 | 17 |
| Citations pointing at real posts | 63 of 63 | 96 of 96 | none to check |
| Quotes word for word | 10 of 10 | 10 of 10 | none |
| Sentences with a citation | 77% | 96% | 0% |
| Support score of cited sentences (supported = 1, partly = ½) | 0.80 | 0.78 | n/a |
| Blind judge: coverage / accuracy / specificity / usefulness | 3 / 3 / 4 / 3 | 5 / 4 / 5 / 5 | 1 / 2 / 1 / 1 |
| Blind ranking | 2nd | 1st | 3rd |

**What this says, honestly.**

- Both grounded arms are far better than no context. With no posts there is nothing to cite, and the judge called it "honest but useless for this week".
- **On one week that fits in the prompt, pasting it all wrote the better report**, at **2.7 times the cost** and 4.3 times the input tokens. The judge's note on RAG: it "misses the iPad Save/Cancel thread, the second biggest". That is retrieval's real failure mode: a big thread that no theme's query lands near never reaches the model. Paste-all cannot miss it.
- Both arms' cited sentences are equally well supported (0.80 vs 0.78), so RAG's evidence is not worse, there is just less of it.
- The judge counted 5 "invented" specifics in RAG against 3 for paste-all. Some of RAG's are the theme counts and earlier-week references the judge's facts cannot confirm (it only sees the week's totals and thread titles), so this number overstates RAG's errors.
- So RAG is the cheaper way to get most of the quality, not the better one, while a week fits. Its case is scale: pasting grows with the data (12 weeks would be ~750,000 tokens, past any context window), retrieval grows with the question.
- One week and one judge is a small, soft sample. The earlier run (two weeks, Opus judging Opus, paste-all with chunks and our themes) pointed the same way: paste-all slightly ahead at 3.1 times the cost.
- Limits: each week is ranked once, in one shuffled order, so position bias is not averaged out; the ranker's facts are counts and thread titles, so "accuracy" cannot check fine detail.

## What to understand

- The difference between *checked in code* (citations exist), *checked by a judge* (the sentence follows from its source) and *scored blind* (overall usefulness).
- Why cost and context size belong in the comparison, not only quality.
- When pasting everything stops being an option.

## Check yourself

1. Paste-all scored a bit higher than RAG. Why is RAG still the right design for this app?
2. Why are the reports shuffled and stripped of citation ids before the ranker sees them?
3. What would you change in the test to be more sure of the result?

## What I would do next

- More weeks, ranked in two orders each, to cancel position bias.
- Fix RAG's coverage gap: also retrieve for the week's biggest threads by post count, not only per theme, so a big thread cannot be missed.
- A larger retrieval budget for RAG to see where it catches up with paste-all.
