# Running notes

My notes for the README and the interview, in my own words. Claude adds a short entry at the end of each step; I edit them.

## Step 1: scaffold

- One database does two jobs: normal tables for posts and a `vector` column for embeddings. That is the whole "vector DB" for this project.
- Jobs run on Solid Queue, which also lives in Postgres. No Redis.
