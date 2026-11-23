# Grounded prompting: making the model write only what the evidence says

**In one line:** give the model numbered evidence, make it cite an id after every claim, ask for its answer as JSON, and then check the citations and quotes in code. Trust, but verify mechanically.

## The pieces

| Piece | What it looks like here | Why |
|---|---|---|
| Numbered evidence | `[E3] 2026-11-18 · Anki › Help · "Sync keeps failing"` then the chunk text | The model can point at a source, and we can follow the pointer |
| "Cite or don't say it" | Every claim ends with `[E3]` or `[E3][E5]` | Unsupported sentences become visible (we count them) |
| Word-for-word quotes | 1-2 per section, 5-30 words, copied exactly | A quote is checkable: it is either in the post or it is not |
| Exact numbers from SQL | "309 posts in 103 threads by 113 people" in the prompt | The model must not count or estimate; it copies |
| Structured output | A JSON schema: headline, overview, sections[{theme, title, body, quotes}] | No parsing prose; a missing field is an error, not a surprise |
| Context, labelled as such | "Similar posts from earlier weeks (context)" | Lets the model say "this keeps coming back" without mixing weeks up |
| A way out | If nothing is retrieved, no model call and "Not enough evidence" | The model never has to fill a gap by inventing |

## Checks in code, not by a second model

`Reports::Grounding` reads the model's answer and the evidence and counts:

- citations that point at real evidence ids (a made-up `[E42]` is caught)
- quotes found word for word in the cited post (ignoring case, curly quotes and spacing)
- sentences in theme sections with no citation at all

These are cheap, deterministic and explainable. They do not prove a claim is *true to* its source (a sentence can cite E3 and still misread it). That needs a judge, which the A/B step adds and labels as model-judged.

## What not to do

- Do not paste "be accurate" and hope. Make inaccuracy *detectable*.
- Do not let the model compute numbers it was not given.
- Do not store generated reports as chunks. The library is forum posts only; a report that retrieved its own earlier claims would drift away from the forum.
