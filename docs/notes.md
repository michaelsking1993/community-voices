# Running notes

My notes for the README and the interview, in my own words. Claude adds a short entry at the end of each step; I edit them.

## Step 1: scaffold

- One database does two jobs: normal tables for posts and a `vector` column for embeddings. That is the whole "vector DB" for this project.
- Jobs run on Solid Queue, which also lives in Postgres. No Redis.

## Step 3: ingest

- The crawler pages backwards through `/posts.json` at 1 request/second and upserts by the forum's post id, so any run can be repeated.
- One week is ~330 posts and ~50k tokens. That fits in a big context window, so RAG has to beat "paste it all", not just "nothing".
- Real data caught a bug: post ids are not strictly in date order, so the crawler stops on a whole old page, not the first old post.
