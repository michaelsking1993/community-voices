# Step 11: Charts, embedding map and retrieval stats

## What we built

A `/charts` page, with no React. The server describes each figure as plain data (`app/services/charts`) and a small Stimulus controller (`plot_controller.js`) hands it to [Plotly](https://plotly.com/javascript/), vendored in `vendor/javascript` (the 1 MB "basic" bundle, MIT, no build step). Sections:

- **A/B test**: do the checks pass, what does each arm cost, how did the blind judge score them.
- **Backtest**: hit rate by confidence and by basis, and verdicts week by week.
- **Embedding map**: each forum thread as a dot, placed by the meaning of its posts, coloured by forum category.
- **Retrieval stats**: the chunks retrieved most, and how close retrieved chunks were.

![The charts page](img/charts.png)

## Why this way

- **The server decides, the browser draws.** Figures are plain hashes, so RSpec tests them without a browser. (#46)
- **PCA for the map.** It finds the two directions along which threads differ most. Deterministic and short (`Charts::Pca`, power iteration in plain Ruby). t-SNE or UMAP separate clusters better but need a library and change between runs. One dot per thread (the average of its chunk vectors) keeps 650 threads readable. (#47)
- **Retrieval stats come from the log.** Step 5 records every search and hit, so "most retrieved chunk" is one query. (#48)

## What to understand

- 384 numbers cannot be shown on a screen: PCA keeps only the two directions of greatest spread, so the map shows rough neighbourhoods, not exact distances.
- In the retrieval chart the most-retrieved chunks are the ones about the biggest story of the weeks (the AnkiMobile 26.10 release): popular chunks mean popular topics, and the per-thread cap and cut-off stop a few chunks dominating.

## Check yourself

1. Two threads sit far apart on the map. Are they necessarily unrelated? Why not?
2. What does the histogram's right edge at 0.6 tell you about the retriever?
3. Why return JSON for Plotly instead of drawing in the browser?

## Possible next steps

- Colour the map by theme, and let a click open the thread.
- A time slider on the map to watch the forum move week by week.
