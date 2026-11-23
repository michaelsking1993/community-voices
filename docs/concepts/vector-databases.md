# When a vector database helps, and when it does not

**In one line:** a vector database answers "which stored texts *mean* something close to this?" It is the right tool when you need meaning-based lookup over more text than you can read or paste, and the wrong tool when an exact filter, a count, or a keyword search already answers the question.

## What it is

An embedding model turns text into a list of numbers (a vector) so that texts with similar meaning end up close together. A vector database stores those vectors and, given a new one, quickly finds the nearest stored ones. In this project the "vector database" is one Postgres table with a `vector(384)` column (see [pgvector.md](pgvector.md)).

## It helps when

| Situation | Example in this project |
|---|---|
| The words differ but the meaning matches | "my reviews vanished after syncing" should find "lost progress after AnkiWeb sync" |
| There is too much text to paste into a prompt | 12 weeks of posts is far more than we want to send to the model each time |
| You want the *relevant* slice, not all of it | For the theme "FSRS settings", pull the 10 posts about it, not 370 |
| You want to find look-alikes across time | "What happened the last time a beta release came out?" |
| You want to see structure | Clustering vectors finds themes nobody labelled; a 2D map shows them |

## It does not help when

| Situation | Better tool |
|---|---|
| The question is exact: "posts in category FSRS last week" | A SQL `WHERE` clause |
| You need counts or trends: "how many posts per day?" | `GROUP BY` |
| You need an exact word or error code: "error 0x80070005" | Keyword / full-text search (embeddings blur rare tokens) |
| All the data fits in the prompt anyway | Just paste it (that is arm B of our A/B test) |
| The data changes every second and must be exact | A normal index; embeddings lag behind writes |

## Separate vector DB vs pgvector

Dedicated stores (Pinecone, Qdrant, Weaviate) shine at hundreds of millions of vectors. pgvector wins when you already run Postgres and want joins, date filters and transactions next to the vectors. We have tens of thousands of chunks, so pgvector is the simpler and better choice. (DECISIONS #2)

## The honest summary for the interview

Use vectors for *meaning*, SQL for *facts*. This app uses both together: SQL picks last week's posts and counts them per theme; vectors find which posts belong to a theme and which older posts look like this week's.
