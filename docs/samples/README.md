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
| Input tokens | 17,321 | 63,773 | 1,029 |
| Cost | $0.123 | $0.348 | $0.035 |
| Citations pointing at real posts (code check) | 67 of 67 | 96 of 96 | none |
| Quotes found word for word (code check) | 8 of 8 | 10 of 10 | none |
| Sentences with a citation (code check) | 85% | 96% | 0% |
| Cited sentences the cited posts support (judge; partly = ½) | 0.78 | 0.78 | n/a |
| Blind judge, 1 to 5: coverage / accuracy / specificity / usefulness | 5 / 4 / 5 / 4 | 5 / 4 / 5 / 5 | 1 / 2 / 1 / 1 |

The blind judge (Sonnet, shown the three reports shuffled and unlabelled, plus exact counts and the 40 biggest threads) ranked paste-all first, RAG a close second and no context last. Its notes:

- **Paste the whole week:** "Matches the big threads well (iPad Save/Cancel, 26.10.x regressions, ß audio, missing cards, AnkiHub trust, down arrow, macOS crash)."
- **RAG:** "Covers most of the major threads and gives useful theme-level trends. It includes many unverifiable specifics such as trend counts ..."
- **No context:** "Admits it has no data and speculates generically ... a product team learns nothing."

The RAG report here is the second try. The first missed the week's second-biggest thread and scored 3 for coverage; why, and the fix, are in [step 10](../steps/10-ab-test.md#check-live-run-week-of-2026-11-16-about-085-in-all) and DECISIONS #53.
