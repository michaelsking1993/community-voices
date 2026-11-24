# Step 4: Chunk and embed

## What we built

Every post is cleaned, split into chunks of up to 150 words with a 30-word overlap, and given a three-line header (topic, category, date). Each chunk is embedded locally with all-MiniLM-L6-v2 into a 384-number vector and stored in `chunks.embedding`, with an HNSW index for fast nearest-neighbour search. The weekly job now runs the whole pipeline: crawl → chunk → embed.

## Why this way

- **Chunks, not whole posts.** The model reads at most ~256 word-pieces, so long posts would be silently cut off. And one vector for a long post blurs several ideas together; smaller chunks keep one idea per vector. (DECISIONS #12)
- **A header on every chunk.** "Try a full sync from the desktop" means little alone. With `Topic: Sync keeps failing / Category: Anki › Syncing & AnkiWeb` on top, both the vector and the model reading it later know the context. (DECISIONS #13)
- **Skip posts under 12 words.** "Thanks, that worked!" has no content, and dozens of near-identical "thanks" vectors would crowd search results. About 10% of posts are skipped. (DECISIONS #14)
- **Drop quoted text.** A reply that quotes another post would otherwise embed the same words twice.
- **Content hash.** Each chunk stores a SHA-256 of its text. Unchanged text keeps its embedding; changed text gets its embedding cleared and redone. Re-running the pipeline costs nothing if nothing changed. (DECISIONS #15)
- **Local model, not an API.** No key, no cost, works offline after a one-time ~90 MB download. Quality is lower than large hosted models, but plenty for forum posts. (DECISIONS #16)
- **HNSW index.** An approximate index: very fast, very high recall, no training step (unlike IVFFlat, which needs data before it is built). (DECISIONS #17)

## How it works

```
Post (raw Markdown)
  └─ Chunking::TextCleaner   drop quotes, images, code, HTML
  └─ Chunking::Chunker       < 12 words? skip.  else 150-word windows, 30 overlap
                             prepend "Topic / Category / Date" header
                             SHA-256 unchanged? keep embedding : clear it
  └─ Embeddings::Embedder    batches of 64 chunks with no embedding
       └─ Embeddings::LocalModel   all-MiniLM-L6-v2 via ONNX → 384 floats, unit length
  └─ chunks.embedding        vector(384), HNSW index, cosine distance
```

The model is injected into the Embedder. Specs use `FakeEmbeddingModel` (instant, offline, deterministic); two opt-in specs run the real model (`RUN_MODEL_SPECS=1 bundle exec rspec --tag model`).

## Check: does "sync problems" return sync posts?

On 2 weeks of real data (705 posts → 825 chunks, embedded in ~50 seconds on CPU):

```
$ bin/rails 'ingest:nearest[sync problems]'
0.433  /t/error-message-synchronising/74421/4   "...not able to maintain the connection to the server..."
0.447  /t/error-message-synchronising/74421/6
0.463  /t/error-message-synchronising/74421/3
0.480  /t/error-message-synchronising/74421/2
0.483  /t/syncing-causes-random-cards-to-be-deleted/74570/5
```

Yes, and note the first one never says "sync problems". It says "maintain the connection to the server". That is semantic search working. "add-on broke after update" similarly finds "the cause is likely an add-on that was recently updated".

It also shows the next problem: **four of five hits come from one thread.** Step 5 (retrieval) needs diversity, so one long thread cannot crowd out the rest.

## What I learned

An embedding turns text into a point in a 384-dimension space where distance means difference in meaning. Chunking decides *what* each point represents: too big and it is a blur of topics (and gets truncated), too small and it loses context. The header is a cheap way to put context back. The content hash makes the pipeline incremental, which is how you keep "overly large amounts of data" cheap: you only ever pay to embed what is new.

## Later: stamping the model (added 2026-11-24)

Reviewing this step, I asked: if we switched embedding models, how would the app know? It would not have. Vectors from two models are on different maps, so they cannot be compared, even when both have 384 numbers. Now:

- Every chunk records the model that embedded it (`chunks.embedding_model`). Existing rows were stamped `Xenova/all-MiniLM-L6-v2`, the only model ever used.
- The Embedder re-embeds any chunk stamped with a different model, so switching models re-embeds everything once, automatically.
- The Retriever only compares chunks embedded by the same model as the query.
- `Embeddings::Guard` checks the model's length against the column (`vector(384)`) *before* calling the model, and checks every returned vector before saving or searching. A 1,536-number model now fails at once with a message saying what to change, instead of a database error halfway through a batch.

Themes and the map average whatever vectors are stored; between switching models and the next embed run they could mix maps. Running the Embedder right after a switch closes that window. (DECISIONS #54)

## What I would do next

- Chunks with many long words or URLs can exceed the model's ~256 word-piece limit, and the model then ignores the tail. A token-based splitter (using the model's own tokenizer) would be exact. Deferred: rare in forum prose, and the overlap means the tail usually starts the next chunk.
- Split on sentence or paragraph boundaries instead of a fixed word count.
- Try a larger model (e.g. bge-small or a hosted model) and compare retrieval hit rates on the step 5 test set. The model stamp means a switch re-embeds everything by itself; a model with a different length also needs a migration for the column.
