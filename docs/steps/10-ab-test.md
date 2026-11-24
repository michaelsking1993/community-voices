# Step 10: A/B test RAG against the alternatives

## What we built

The challenge asks how an LLM does *without* RAG. We wrote the same weekly report three ways and compared them:

| Arm | What the model gets |
|---|---|
| `none` | The week's dates only. This is "just ask an LLM". |
| `paste_all` | The same themes as RAG, then every chunk of the week in the prompt, no search (about 88,000 tokens). |
| `rag` | Themes, then retrieval per theme: a few posts from this week plus 3 similar posts from earlier weeks (about 15,000 tokens). |

Run it with `bin/rails 'ab:run[2]'`; see it on the Charts page.

## Why this way

- **One builder, one schema, one set of checks.** Arms are `Reports::Builder` with a different evidence source, so only the context differs. (#32, #41)
- **Paste-all is the rival that matters.** A week fits in the model's context, so "RAG vs nothing" would be a weak test. Paste-all also gets the same themes and SQL signals (trend counts, releases) so its sections and predictions are comparable. What differs: paste-all gets every chunk of the week, RAG gets a few per theme plus a few similar posts from earlier weeks. (#41)
- **"No context" really means none.** Giving the baseline our themes would leak our pipeline into it. (#42)
- **Three ways to judge, from objective to soft:** checks in code, a support judge that reads each cited sentence next to only its sources, and a blind ranker that sees shuffled, unlabelled reports plus exact facts about the week. (#43)
- **Judge can be a different model**: `LLM_JUDGE_MODEL`. Unset, the judge is the writer's own model, which may favour its own style. (#44)

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

## Check: live run, two weeks (11-09 and 11-16), about $1.60 in all

| | RAG | Paste whole week | No context |
|---|---|---|---|
| Input tokens per report | 15,211 | 88,031 | 1,029 |
| Cost per report | $0.147 | $0.461 | $0.034 |
| Seconds | 37 | 51 | 17 |
| Citations pointing at real posts | 100% | 100% | none to check |
| Quotes word for word | 100% | 100% | none |
| Sentences with a citation | 79% | 84% | 0% |
| Support score of cited sentences (supported = 1, partly = ½) | 0.78 | 0.87 | n/a |
| Blind judge: coverage / accuracy / specificity / usefulness | 4.5 / 3.0 / 4.5 / 4.0 | 5.0 / 3.0 / 5.0 / 4.5 | 1 / 2 / 1 / 1 |
| First place (2 weeks) | 1 | 1 | 0 |

**What this says, honestly.**

- Both grounded arms are far better than no context: with no posts there is nothing to cite, and the judge scored it 1 on coverage and specificity.
- Paste-all matched or slightly beat RAG on every quality measure, at **3.1 times the cost** and 6 times the input tokens. That ratio is an upper bound: paste-all pastes chunks, which overlap by 30 words and each repeat a header, so pasting each post once would cost less (a week of raw posts is about 50,000 tokens, which would make it roughly 2 times). It also skips posts under 12 words, like every arm. On a week this small, pasting works. RAG is the cheaper way to get most of the quality, not a better one.
- That ratio is why RAG matters: pasting scales with the data, retrieval scales with the question. Four months of history would not fit, and RAG would cost the same.
- Two weeks and an LLM judge is a small, soft sample. Accuracy was 3.0 for both grounded arms: neither is free of mistakes.
- The judges' limits: each week was ranked once, in one shuffled order, so position bias is not averaged out; the ranker's facts are counts and thread titles, so "accuracy" cannot check fine detail; and unless `LLM_JUDGE_MODEL` is set the judge is the model that wrote the reports.

## What to understand

- The difference between *checked in code* (citations exist), *checked by a judge* (the sentence follows from its source) and *scored blind* (overall usefulness).
- Why cost and context size belong in the comparison, not only quality.
- When pasting everything stops being an option.

## Check yourself

1. Paste-all scored a bit higher than RAG. Why is RAG still the right design for this app?
2. Why are the reports shuffled and stripped of citation ids before the ranker sees them?
3. What would you change in the test to be more sure of the result?

## What I would do next

- More weeks, and a different judge model through `LLM_JUDGE_MODEL`.
- Rank each week in two orders and average, to cancel position bias.
- Paste each post once instead of its chunks, for a fair cost ratio.
- A larger retrieval budget for RAG to see where it catches up with paste-all.
