# Workflow insights

The challenge's optional step asks for `/insights` "and/or other unique aspects of your coding workflows". `/insights` only reads the session history on the machine it runs on, and this project was built in about 17 short-lived Claude Code cloud sessions, so it saw almost nothing. This page is the replacement: Claude read every one of those sessions after the fact and wrote down what actually happened. Michael reviewed it.

Times are US Eastern. Anything inferred rather than read directly from a session or from GitHub is marked *(inferred)*.

## The numbers

| | |
|---|---|
| Wall-clock span | Mon 23 Nov, 3:29 PM (plan starts) to Tue 24 Nov, 7:05 PM (last merge), about 28 hours including a night's sleep |
| Sessions ("threads") | 16 working threads, plus a coordinator session in the project chat, plus this one |
| Pull requests | 33 opened, 33 merged, each with green CI |
| Commits on `main` | 82 (54 not counting merge commits) |
| Specs | 49 spec files, 170 examples at the end; RSpec, RuboCop, Brakeman and a `docker compose` build in CI |
| DECISIONS.md | 61 rows; 7 marked "Start here" |
| Michael's messages | about 55 in the learning thread alone, about 25 in the README thread, and the rest spread across the others |
| LLM API spend (the app's own calls) | roughly $4 to $5 *(inferred: sum of the costs the sessions reported: live run $0.13, first A/B and backtest about $2, fair A/B rerun $0.63, RAG rerun $0.20, Michael's two-week A/B and backtest about $1 to $2)* |
| Claude Code usage | hit the plan's usage limit once (Mon night, about a 1-hour wait); the codebase review was scheduled for one minute after the limit reset |

## How the work was organised

1. **Plan first, no code.** The first session wrote a plan doc from the challenge PDF and TE's "Engineering at TE" doc, with open decisions at the bottom. Michael answered them (Anki forums, Rails 8 + pgvector, local embeddings, no React, finish by Tuesday) and asked six clarifying questions before anything was built.
2. **One session per chunk of work.** A coordinator session in the project chat started a fresh session for each piece: ingest (PRs #1-3), retrieval to predictions (#4-7), backtest/A/B/charts (#8-10), then review, README, UI, learning, flashcards and so on. Each session read the plan, the repo and a shared memory file, so a new one didn't have to be re-briefed from scratch.
3. **Model and effort picked per session.** Michael asked for the plan on Opus at high effort and for the flashcards and the quiz on Sonnet, with cost in mind ("I don't want to burn all my tokens"). The plan put the retrieval/report session on Opus at high effort *(inferred: recommended in the planning session; the build session doesn't say what it ran on)*.
4. **One PR per step, stacked.** Michael chose small stacked PRs over one big PR for steps 6-8. Every step also wrote a `docs/steps/` page and a DECISIONS.md row, which is where most of the documentation came from.
5. **Separate review sessions.** Two sessions that hadn't written the code reviewed it: one checked the backtest/A/B/charts right after they merged, and a scheduled full-codebase review ran that night. A third session, asked "what would a reviewer flag?", reviewed the finished repo.
6. **A dedicated learning session.** After 14 PRs had merged, Michael said he felt like "a human wrapper over a Claude subscription". A separate session then walked him through the pipeline one idea at a time, and he wrote and rewrote his own explanation of it until it held up. That became [`docs/my-explanation.md`](my-explanation.md). Later sessions turned his vocabulary list into the Flashcards tab and quizzed him on the 7 key decisions.

## How Michael steered

Things he pushed back on, corrected, or rejected. Each changed the repo.

- **Provider names.** The code and docs said "Claude" everywhere. He pointed out the app should be provider-neutral, so it became an `Llm` interface with an Anthropic adapter, and then asked for the `ANTHROPIC_API_KEY` fallback to be removed entirely (`LLM_API_KEY` only).
- **"Why 8?"** He asked why the report used 8 themes. The session admitted it was an untested judgement call, measured k = 4 to 12 on three weeks, found no natural number, and made k scale with the week (DECISIONS #24). Later he asked why only the top 6 themes got a section and argued every theme should; that became PR #18.
- **"Is there any way to make that better?"** When the A/B judge noted that RAG missed the week's second-biggest thread, he asked for the cause and a fix rather than a caveat. That became DECISIONS #53, the most important retrieval change in the project.
- **"How do we know when the model gets switched?"** He found a real gap: chunks didn't record which embedding model made them. He asked for the stamp and a guard against length mismatches ("might be a pipe dream"); it was PR #16.
- **Search capped at 8.** The search box had inherited the report's top-8 limit. He asked why it didn't show everything under the distance cut-off, and it was fixed.
- **"I think this should all be on the interface."** Evaluation only existed as rake tasks. He asked for buttons, which became the Evaluate and Data tabs, then said the UI was confusing ("I'm confused about what I'm supposed to do with it"), which led to a page-by-page UI review (#21) and readable result tables instead of terminal output (#25).
- **The skipped step 2.** The plan had folded the "concepts lab" into reading docs. He noticed he hadn't actually done it, so the session ran it live: he guessed similarities for six sentences, then the real model scored them. He got the ranking right and the number wrong (guessed 0.8, measured 0.37), which became the project's "no thresholds by feel" rule.
- **Honesty edits.** He removed wording that oversold him or put words in his mouth:
  - "pgvector is not a new database…" in a step page ("makes me look like a noob").
  - "What I learned" headings on step pages he hadn't written ("disingenuous… I didn't read those"), renamed to "Key takeaways". His own write-up became the centrepiece instead.
  - A requirement "a reviewer can run it from git clone" that he called common sense, replaced with the one that's actually distinctive (no API key needed to explore).
  - A line in the Anki paragraph telling TE what they'd "want to hear".
  - A Flashcards line claiming he drilled with it; it now says it's a toy and he'd use Anki for real memorising.
- **He wrote "How I built it" himself**, from scratch and without reading Claude's draft first. His version replaced Claude's, with five small edits he approved.

## Where the AI got things wrong, and how it was caught

| What went wrong | How it was caught | What changed |
|---|---|---|
| The plan said TE uses Rails and React. That came from an unrelated interview cheat sheet uploaded by accident. | Michael deleted the cheat sheet and asked why React was better than Hotwire. | React dropped; Rails kept on its own merits. |
| The A/B test was unfair to the rival: paste-all pasted overlapping chunks (inflating its cost) and was handed RAG's themes. | Fresh review session. | Paste-all rebuilt as "each post once, no themes" and re-run (DECISIONS #49). RAG's cost edge shrank from 3.1x to 2.7x, and the docs say so. |
| The judge model defaulted to the writer model, so Opus graded Opus. | Same review, and Michael's question "what model did we use for the tests?" | `LLM_JUDGE_MODEL`; the published run is judged by a different model. |
| Backtest conclusions claimed more than 13 predictions can show ("the one real signal" rested on n=2). | Same review. | Strict hit rate shown alongside; the claim downgraded to a hint. |
| RAG missed the week's second-biggest thread: every theme got 6 chunks whatever its size. | The blind judge's note, then Michael's "any way to make that better?" | Budget shared by theme size plus each theme's busiest threads (DECISIONS #53). |
| That fix was then tested on the same week that exposed the bug, i.e. tuned on the test set. | The "what would a reviewer flag?" session. | Michael re-ran the A/B on an unseen week (11-09): coverage 4, up from 3 but not the 5 seen on the tuning week. Written up as "better, not solved". The re-run also showed the judge is noisy (the same week moved RAG from 5/4/5/4 to 4/2/4/3). |
| The flashcards tab showed every card at once (a CSS rule overrode the hidden state). The first test only checked text on the page. | Michael opened it: "this doesn't look like flashcards to me!" | Two-line CSS fix, checked in a headless browser this time (#24). |
| The API key never reached the session (the runtime reserves `ANTHROPIC_*` names), which held up the first live run by about 45 minutes. | The session's own check (401s). | Switched to `LLM_API_KEY`; the live run moved to a fresh session that could see it. |
| Small slips: screenshots committed by accident (squash-merged to keep them out of history), a stray branch pushed, a spec that assumed an API key was set and failed in CI, and the coordinator and a thread editing Michael's vocab file at the same moment, deleting two extra rows (restored). The coordinator also guessed the Docker service name wrong ("web" instead of "app"). | Each session reported its own slip, or CI failed. | Fixed before merge or on the spot. |

Still unexplained: RAG cost $0.18 to $0.19 per report on Michael's machine against $0.12 in the published run, with the same model. Step 10 says the cause isn't known.

Writing this page also caught one overclaim in the README: it said every pull request was reviewed by a fresh session. The sessions show fresh-session reviews at three points (the A/B, backtest and charts; the whole codebase; the finished repo), not of every PR, so the README now says that.

## Patterns worth noting

- **Most of the important fixes came from asking "why?"** about a number: why 8 themes, why 6 sections, why 8 search results, why 150 words, why 0.6. Several of those numbers turned out to be untested defaults.
- **Fresh eyes found the methodology problems; real data found the code problems.** The unfair A/B, the self-grading judge and tuning on the test week were all caught by a session that hadn't written the code. Crawler ordering, partial weeks and the missed thread were caught by running on real forum data.
- **Docs written alongside the code are cheap but don't count as understanding.** Every step got a docs page, but Michael's understanding came from explaining the pipeline back, not from reading those pages. The README now says so.
- **Cost shaped the process.** Paid reruns were asked about before running, model and effort were chosen per session, and the review was scheduled around the usage limit.

## What to do differently next time

Drawn from the problems above:

1. **Do the learning walkthrough before the build, not after 14 PRs.** The step-by-step explanation is what made the project explainable; earlier, it would also have caught "why 8?" sooner.
2. **Hold out an evaluation week from day one,** and never tune on it.
3. **Pick the judge model and make the baseline fair before the first A/B run,** instead of re-running after a review.
4. **Look at every UI change in a browser before calling it done.** Two of the slips (flashcards, the confusing first UI) were visible at a glance.
5. **Sort out secrets and environment variables first,** and give each shared file one writer at a time.
