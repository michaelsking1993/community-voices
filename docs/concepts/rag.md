# RAG: retrieval-augmented generation

**In one line:** before the model writes, we *retrieve* the most relevant stored text and put it in the prompt, so the model answers from real sources it can cite instead of from memory.

## The three steps

1. **Retrieve.** Embed the question, then find the nearest chunks in `chunks.embedding` (plus SQL filters like "last 7 days").
2. **Augment.** Paste those chunks into the prompt, each with an id: `[c123] Topic: Sync keeps failing ...`.
3. **Generate.** The model writes the report and cites chunk ids. Code can check each citation points at a real post.

## Does "generate" create new chunks?

No. This is a common confusion. The chunks are the *library*: they come only from ingestion (crawl → chunk → embed). Generation *reads* chunks and writes an answer; the answer is not added back to the library. If nothing relevant is retrieved, a well-designed prompt makes the model say "not enough evidence" rather than invent something. (Saving reports somewhere is fine, but they are outputs, not sources.)

## Why not just paste everything?

| Approach | Works when | Fails when |
|---|---|---|
| No context | Never, for "last week" | The model cannot know last week, so it invents |
| Paste everything | The data fits (one week ≈ 50k tokens does) | 12 weeks of history does not; cost grows with every call; the model skims long contexts |
| RAG | Data is bigger than the prompt, or you want the *relevant* slice | Retrieval misses the right chunks (so we measure hit rate) |

Our A/B test runs all three side by side. That is the honest way to show RAG earns its keep.

## Where it shows up in this repo

- Library: `posts` → `chunks` with embeddings (steps 3-4).
- Retrieval: `Search::Retriever` (date window, cut-off, max 2 per thread, logging); see [retrieval.md](retrieval.md).
- Generation: the report builder in steps 7-8.
