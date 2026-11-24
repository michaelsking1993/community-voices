# Step 7: Write the report

## What we built

`Reports::Builder` writes a week's Community Voices report. For each of the 6 biggest themes it retrieves chunks from that week (6 each at first; since step 10, a budget shared by theme size plus each theme's 2 busiest threads, see DECISIONS #53) and 3 look-alikes from the 12 weeks before, numbers them `[E1]`, `[E2]`..., and asks the LLM for a structured report: a headline, an overview, and a section per theme with cited claims and word-for-word quotes. `Reports::Grounding` then checks every citation and quote in code. Reports are saved with their evidence, checks, tokens and cost, and shown at `/reports` (with a Markdown download).

## Why this way

- **Retrieve per theme, not once for the week.** Each theme gets its own query (its label and summary), so every section has evidence about *that* theme, and a quiet theme is not drowned out by a loud one. (DECISIONS #28)
- **History as labelled context.** Three older look-alikes per theme let the report say "this came back" or "this is new", and they feed predictions in step 8. They are marked as context so the model does not mix weeks up.
- **Cite or don't say it, checked by code.** Numbered evidence, a citation after every claim, exact quotes, and SQL numbers only. Code counts valid citations, verbatim quotes and uncited sentences. (DECISIONS #29, [grounded prompting](../concepts/grounded-prompting.md))
- **No evidence, no LLM call.** If no theme has a chunk under the distance cut-off, the report says "Not enough evidence" and the LLM is never asked to write. Themes with nothing to cite are listed, not written about. (DECISIONS #30)
- **Reports are outputs, never sources.** They are stored in `reports`, never chunked or embedded, so the model never retrieves its own earlier claims. (DECISIONS #31)
- **Evidence is pluggable.** The builder takes an `evidence_source`. RAG is one; the A/B step adds "no context" and "paste everything" with the same prompt and checks, so only the context differs. (DECISIONS #32)

## How it works

```
Reports::Builder.call(week)
  themes      Theme.for_week(week), or Themes::Finder now; >= 2 threads; top 6
  evidence    RagEvidence: per theme, Retriever(label + summary)
                this week:   k 6, max 2 per thread      purpose "report"
                12 weeks before: k 3, max 1 per thread  purpose "report_history"
  nothing?    "Not enough evidence", no model call
  prompt      week, exact counts (SQL, vs the 4 weeks before), per theme: counts, [E1].. evidence
  Llm.client.json(schema: headline, overview, sections[theme, title, body, quotes])
  Grounding   citations valid? quotes verbatim? sentences uncited?
  save        Report: content, evidence, grounding, markdown, model, tokens, cost
```

Try it: `bin/rails report:build` (last complete week) or `bin/rails 'report:build[2026-11-16]'`, or press "Write report" at http://localhost:3000.

## Check

A dry run on the week of 2026-11-16, with a stand-in model, showed every one of the 6 themes found 6 chunks from the week and 3 from earlier weeks, and the prompt was about 7,000 tokens (about 8,100 with step 8's signals; about $0.04 per report with the default Anthropic model). That is roughly a sixth of the week's ~50,000 tokens of posts. The live run with the LLM is below.

_Live run: to do once the API key is set._

## What I learned

Grounding is a design, not a sentence in the prompt. Numbered evidence makes claims traceable; quotes and SQL numbers make them checkable; a cut-off and a "not enough evidence" path remove the pressure to invent; and code, not another model, does the first round of checking. The same builder with a different evidence source is the A/B test.

## What I would do next

- A judge prompt that checks whether each cited sentence is actually supported by its source (planned for the A/B step, labelled as model-judged).
- Prompt caching for the system prompt and schema when many reports are generated in a row (the backtest).
- Let the model ask for more evidence on a theme (a second retrieval round) instead of a fixed k.
