# ETL and ingestion

**In one line:** ETL means Extract (pull data from a source), Transform (clean and reshape it), Load (store it). Our weekly job is a small ETL pipeline run on a queue.

| Stage | In this project | Code |
|---|---|---|
| Extract | Page through the forum's `/posts.json` | `Discourse::Client`, `Ingest::ForumCrawler` |
| Load | Upsert into `topics` and `posts` | `Topic.upsert_all`, `Post.upsert_all` |
| Transform | Clean, chunk and embed (step 4) | `Chunker`, `Embedder` |
| Schedule | Every Monday 6am | `config/recurring.yml` → `IngestWeekJob` |

## Three properties that matter

1. **Idempotent.** Running it twice gives the same result as once. We get that by keying every row on the source's own id and using upserts.
2. **Windowed.** Each run fetches only a recent window (8 days), not everything. The one extra day of overlap covers a late or failed run.
3. **Polite.** One request per second, a descriptive User-Agent, and backing off when the server says 429 (too many requests).

## Handling "overly large amounts of data"

The challenge asks about this directly. Our levers, cheapest first:

- **Time windows:** only the last week goes into a report; history is retrieved, not pasted.
- **Filtering:** drop moderator actions at ingest, tiny posts at chunking.
- **Dedupe:** upserts by id; a content hash means unchanged text is never re-embedded.
- **Retrieval:** the model sees the top few relevant chunks, not the whole corpus.
- **Deferred:** tree RAG (summaries of summaries) for when even one week is too big.
