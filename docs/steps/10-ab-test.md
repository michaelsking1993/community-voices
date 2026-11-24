# Step 10: A/B test RAG against the alternatives

## What we built

The challenge asks how an LLM does *without* RAG. We wrote the same weekly report three ways and compared them:

| Arm | What the model gets |
|---|---|
| `none` | The week's dates only. This is "just ask an LLM". |
| `paste_all` | The week's exact counts, then every post of the week once, cleaned, grouped by thread with each title once. No search, no themes (about 64,000 tokens). |
| `rag` | Themes, then retrieval per theme: posts from this week (more for bigger themes, always including each theme's busiest threads) plus 3 similar posts from earlier weeks, plus trend counts and release threads (about 17,000 tokens). |

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

## Check: live run, week of 2026-11-16, about $0.85 in all

Reports written by `claude-opus-5-5`; support judge and blind ranker `claude-sonnet-5-5`. "RAG, first try" is the run that found the gap below; "RAG" is after the fix (DECISIONS #53). The same themes were used both times.

| | RAG | RAG, first try | Paste whole week | No context |
|---|---|---|---|---|
| Input tokens per report | 17,321 | 14,777 | 63,773 | 1,029 |
| Cost per report | $0.123 | $0.130 | $0.348 | $0.035 |
| Seconds | 24 | 31 | 44 | 17 |
| Citations pointing at real posts | 67 of 67 | 63 of 63 | 96 of 96 | none to check |
| Quotes word for word | 8 of 8 | 10 of 10 | 10 of 10 | none |
| Sentences with a citation | 85% | 77% | 96% | 0% |
| Support score of cited sentences (supported = 1, partly = ½) | 0.78 | 0.80 | 0.78 | n/a |
| Blind judge: coverage / accuracy / specificity / usefulness | 5 / 4 / 5 / 4 | 3 / 3 / 4 / 3 | 5 / 4 / 5 / 5 | 1 / 2 / 1 / 1 |
| Blind ranking | 2nd | 2nd | 1st | 3rd |

**What this says, honestly.**

- Both grounded arms are far better than no context. With no posts there is nothing to cite, and the judge said "a product team learns nothing".
- **The first RAG run missed the week's second-biggest thread** (iPad Save/Cancel, 15 posts); the judge scored its coverage 3. The cause was the retrieval budget, not the themes: the thread was in the right theme, but every theme got 6 chunks however big it was (that theme had 33 threads), and the theme's query lands near its centre, so a big thread at the edge lost to ones that sounded more like the label. Retrieval answers the question you ask; "what sounds like this theme?" is not "what was big this week?".
- **The fix:** share the chunk budget by each theme's size, and always give each theme's 2 busiest threads (counted in SQL) their chunk closest to the query (vectors). 17% more input tokens; the report came out shorter, so it cost slightly less. Coverage went from 3 to 5 and RAG now matches paste-all on three of the four scores.
- **Paste-all is still ranked first**, on usefulness (5 vs 4), at **2.8 times RAG's cost** and 3.7 times its input tokens. While a week fits in the prompt, pasting it all is a strong, simple baseline. RAG's case is cost and scale: pasting grows with the data (12 weeks would be ~750,000 tokens, past any context window), retrieval grows with the question.
- The judge still counts several "invented" specifics in each grounded report. For RAG some are things its facts cannot confirm (trend counts, earlier-week references): the judge only sees the week's totals and thread titles.
- **The fix was checked on the week that exposed the problem.** The budget-by-size change (#53) was designed after seeing this week's miss, and then re-run on this same week. The next section checks it on a week it was never tuned on.
- One week and one judge is a small, soft sample. The earlier run (two weeks, Opus judging Opus, paste-all with chunks and our themes) pointed the same way. Each week is ranked once, in one shuffled order, so position bias is not averaged out.

## Second check: a fresh week, on my machine (2026-11-24)

The fix above was tuned on 2026-11-16, so its score there proves little. To check it on data it had never seen, I ran `bin/rails 'ab:run[2]'` from a fresh database on my own machine, with `LLM_JUDGE_MODEL=claude-sonnet-5-5`. That wrote and judged 2026-11-09 (never looked at while tuning) and wrote 2026-11-16 again from scratch.

Blind judge: coverage / accuracy / specificity / usefulness, and rank.

| Week | RAG | Paste whole week | No context | Cost: RAG vs paste-all |
|---|---|---|---|---|
| 2026-11-09 (fresh) | 4 / 3 / 5 / 4, 2nd | 5 / 4 / 5 / 5, 1st | 1 / 3 / 1 / 1, 3rd | $0.19 vs $0.40 |
| 2026-11-16 (again) | 4 / 2 / 4 / 3, 2nd | 5 / 3 / 5 / 5, 1st | 1 / 2 / 1 / 1, 3rd | $0.18 vs $0.36 |
| 2026-11-16 (published run above) | 5 / 4 / 5 / 4, 2nd | 5 / 4 / 5 / 5, 1st | 1 / 2 / 1 / 1, 3rd | $0.12 vs $0.35 |

**What this says.**

- **Paste-all ranked first in all three judged runs, and RAG second.** That part is stable.
- **On the fresh week the fix partly held.** Coverage was 4, not the 3 of the first try, but not the 5 of the tuned week either. The judge says RAG "gives little weight to Browse, search and image regressions", which paste-all covered. A theme-shaped query still misses some big threads at a theme's edge.
- **The judge is noisy.** The same week, the same code and the same judge model moved RAG from 5 / 4 / 5 / 4 to 4 / 2 / 4 / 3. The reports were rewritten from scratch, so this is the writer's noise and the judge's together, and it is about as large as the gaps between the arms. Read single scores loosely; the ranking is the steadier signal.
- **Part of RAG's accuracy penalty is the judge's blind spot.** Both notes say RAG "invents" per-theme thread, post and people counts. Those counts come from SQL on the RAG arm's fact sheet (#25), which the judge does not see; it only gets the week's totals and thread titles. Some penalties are real, though: on 11-16 RAG placed the "Undo 26.10" thread in the previous week, likely misled by an earlier-week look-alike.
- **Cost:** RAG cost about half of paste-all on these runs ($0.18 to $0.19 against $0.36 to $0.40), more than the published run's $0.12. I have not pinned down why RAG cost more here.
- **The conclusion stays the same, stated more carefully:** while a week fits in a prompt, pasting it all writes a slightly better report. RAG comes reliably second at a third to a half of the cost, and its real case is scale.

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
- A larger retrieval budget for RAG to see where it catches up with paste-all.
