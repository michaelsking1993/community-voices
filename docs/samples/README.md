# Sample run: week of 2026-11-16

One week of the Anki forums (309 posts in 103 threads by 113 people), written up three ways by the same model (`claude-opus-5-5`) with the same rules and output schema. Only the context differs. This is the A/B test of [step 10](../steps/10-ab-test.md), produced by `LLM_JUDGE_MODEL=claude-sonnet-5-5 bin/rails 'ab:run[1]'` on 2026-11-24.

| Report | What the model was given |
|---|---|
| [RAG](2026-11-16-rag.md) | The week's themes (k-means over threads), a few retrieved posts per theme from this week and earlier weeks, trend counts and release threads |
| [Paste the whole week](2026-11-16-paste-all.md) | Every post of the week once, grouped by thread. No search, no themes |
| [No context](2026-11-16-none.md) | Only the week's dates: "just ask an LLM" |

Every `[n]` in the RAG and paste-all reports links to the forum post it cites.

## How they compared

| | RAG | Paste whole week | No context |
|---|---|---|---|
| Input tokens | 14,777 | 63,773 | 1,029 |
| Cost | $0.130 | $0.348 | $0.035 |
| Citations pointing at real posts (code check) | 63 of 63 | 96 of 96 | none |
| Quotes found word for word (code check) | 10 of 10 | 10 of 10 | none |
| Sentences with a citation (code check) | 77% | 96% | 0% |
| Cited sentences the cited posts support (judge; partly = ½) | 0.80 | 0.78 | n/a |
| Blind judge, 1 to 5: coverage / accuracy / specificity / usefulness | 3 / 3 / 4 / 3 | 5 / 4 / 5 / 5 | 1 / 2 / 1 / 1 |

The blind judge (Sonnet, shown the three reports shuffled and unlabelled, plus exact counts and the 40 biggest threads) ranked paste-all first, RAG second and no context last. Its notes:

- **Paste the whole week:** "Closely matches the biggest threads (iPad Save/Cancel, 26.10 regressions, AnkiHub/AI, sync/counter confusion, ß files, down arrow, macOS crash), though some details ... cannot be verified from the facts."
- **RAG:** "Covers the main themes ... it also misses the iPad Save/Cancel thread, the second biggest."
- **No context:** "Admits it had no data and guesses generic topics ... honest but useless for this week."

What this means, and its limits (one week, one judge), is discussed in [step 10](../steps/10-ab-test.md#check-live-run-week-of-2026-11-16-about-063-in-all).
