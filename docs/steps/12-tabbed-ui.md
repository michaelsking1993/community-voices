# Step 12: Tabbed UI and semantic search

## What we built

One row of tabs on every page (`app/views/shared/_tabs.html.erb`):

| Tab | Page | What it does |
|---|---|---|
| Community report | `/` | The weekly reports and the "Write report" button. Without `LLM_API_KEY` the page says so and disables the buttons; saved reports still open |
| Search | `/search` | Type a question, get the forum chunks closest in meaning |
| Evaluate | `/evaluation` | Buttons for the A/B test, backtest and retrieval eval, with cost, the data each needs, and each one's last output |
| Charts | `/charts` | A/B test, backtest, embedding map, retrieval stats (step 11) |
| Data | `/data` | What is stored per week, and a button to crawl more (12 weeks by default) |
| Flashcards | `/flashcards` | "Coming soon" placeholder |

Opening a single report keeps the Community report tab lit.

Under the tabs, every page says what data it is working from: "Forum data: 2 full weeks (2026-11-09 to 2026-11-22) · 756 posts". Pages refresh themselves while a report or a task runs.

### UI review (after first use)

Michael's first look found the UI confusing, so we went through it page by page:

| Confusion | Fix |
|---|---|
| Startup crawled 2 weeks, but the Evaluate tab talked about 12, and nothing said how much data there was | Status line on every page; Data tab with a table per week and why startup crawls 2 |
| Crawling sat on the Evaluate tab, though it is not an evaluation | Moved to the Data tab |
| Buttons could be pressed with too little data, then failed | A task needs N full weeks; with fewer, its button is disabled and says "needs 6, you have 2" |
| After pressing a button, nothing happened until you reloaded | Pages reload every 5 seconds while something runs, and say so |
| "rag · Nov 24" and "paste_all" in the report list | "Report", "A/B: paste the whole week", "A/B: no context" |
| Search intro was a paragraph of jargon | One plain sentence, example queries to click, the details folded away |
| Charts' empty sections gave rake commands | They name the tab and button instead |
| Browser-default buttons, some blue, some grey | One button style, and a clear disabled style |

## Why this way

- **Search reuses `Search::Retriever`.** The same 0.6 cosine cut-off and max 2 chunks per thread as the report, so what you see in search is what the report could cite. No date window, so you can search all stored weeks. (#56)
- **No key needed.** Embedding is local (all-MiniLM-L6-v2), so search works on a fresh clone with only the crawl done. The first search is slow while the model loads.
- **Searches are logged** with purpose `search`, so they show up in the Charts retrieval stats like any other retrieval.
- **An empty result is a message, not a guess.** Nothing within 0.6 means "the forum has no clear match".

- **Every long task has a button.** Crawl, retrieval eval, A/B test and backtest run in a background job (`PipelineJob`) and save what they printed in `job_runs`. The rake tasks call the same `Pipeline::Runner`, so the terminal and the browser cannot drift apart. Tasks that spend money ask for confirmation, are disabled without `LLM_API_KEY`, and cannot be started twice at once. Evaluation is still never automatic. (#57, #58)

## What to understand

- Search by meaning is not keyword search: "my decks vanished after syncing" can match a post that says "cards missing following AnkiWeb sync". Try both kinds of query and compare the distances.
- Distance is cosine distance: 0 is the same direction, larger is less related. The 0.6 cut-off is where hits stop being "about it" on our 12 weeks of data (step 5).

## Check yourself

1. Why does search work with no API key when "Write report" does not?
2. Search a made-up phrase. Why do you get a message rather than the nearest bad match?

## What I would do next

- Filters for category and date range (the retriever already takes a window).
- Hybrid search: add keyword matching for exact terms such as error codes.
- Show live progress on the Evaluate tab (it needs a manual refresh today).
- Flashcards: study cards for the RAG vocabulary and project facts ("What is Anki?"), a progress bar through the deck and a reset button.
