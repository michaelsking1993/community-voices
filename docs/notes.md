# Running notes

My notes for the README and the interview, in my own words. The AI assistant adds a short entry at the end of each step; I edit them.

## Step 1: scaffold

- One database does two jobs: normal tables for posts and a `vector` column for embeddings. That is the whole "vector DB" for this project.
- Jobs run on Solid Queue, which also lives in Postgres. No Redis.

## Step 3: ingest

- The crawler pages backwards through `/posts.json` at 1 request/second and upserts by the forum's post id, so any run can be repeated.
- One week is ~330 posts and ~50k tokens. That fits in a big context window, so RAG has to beat "paste it all", not just "nothing".
- Real data caught a bug: post ids are not strictly in date order, so the crawler stops on a whole old page, not the first old post.

## Step 4: chunk and embed

- Chunks are ~150 words with a header (topic, category, date). The header gives each chunk its context back.
- "sync problems" finds a post that says "maintain the connection to the server": semantic search, not keywords.
- Generation never creates chunks. Chunks only come from ingestion; the model reads them.
- A content hash means only new or edited text is ever embedded.
- Open problem for step 5: one long thread can fill the whole top 5.

## Step 5: retrieval

- Retrieval = nearest *and* close enough *and* not all one thread *and* in the right week.
- The distance cut-off (0.6) is what makes "not enough evidence" possible. Off-topic questions never got closer than 0.71.
- Max 2 chunks per thread took the top 8 from 3.9 threads to 5.5, with the same hit rate.
- HNSW gotcha: the date filter is applied after the index walk, so raise `ef_search` or a narrow window comes back short.
- 15 hand-labelled queries; the eval caught a mistake in my own labels. Measure every change.

## Step 6: themes

- Themes = k-means over *threads* (average of each thread's chunk vectors that week), seeded so a week always gives the same answer.
- Why that k: text has no natural k (silhouette ~0.1 for every k). So k = about one theme per 12 threads, between 4 and 8; a fixed 8 splintered a quiet week into one-thread themes.
- SQL counts threads, posts and people. The LLM only names each cluster, from titles and excerpts, in one structured-output call.
- Week of 2026-11-16: the AnkiMobile 26.10 release dominated (two themes), then lost decks and sync. One cluster was a mixed bag: k-means makes every thread join some group.
- All LLM calls go through one provider-neutral, injected `Llm` interface (Anthropic adapter by default), which records tokens and cost for the A/B comparison.
