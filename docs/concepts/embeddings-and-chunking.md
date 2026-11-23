# Embeddings and chunking

**In one line:** an embedding model turns a piece of text into a list of numbers (a vector) so that texts with similar *meaning* get similar numbers. Chunking decides which piece of text each vector stands for.

## Embeddings, by example

Real output from our model (dot product of unit vectors = cosine similarity, 1 = same meaning, 0 = unrelated):

| Text A | Text B | Similarity |
|---|---|---|
| my reviews vanished after syncing | lost progress after AnkiWeb sync | **0.37** |
| my reviews vanished after syncing | how do I change the card font | **0.01** |

The first pair shares almost no words, yet scores far higher. That is the whole point: keyword search would miss it.

Our model, all-MiniLM-L6-v2, makes 384-number vectors and reads up to ~256 word-pieces. It runs on CPU via ONNX in Ruby (the `informers` gem), at roughly 15 chunks a second here.

## Chunking trade-offs

| Chunk size | Good | Bad |
|---|---|---|
| Whole post / thread | Full context | Several ideas blur into one vector; long ones get truncated |
| ~150 words (ours) | One idea per vector; fits the model | Can lose context, so we add a header |
| One sentence | Very precise | "Try that instead" means nothing alone; many more vectors to store |

**Overlap** (30 words) means a sentence that falls on a boundary still appears whole in one chunk.

**Headers** put the lost context back: every chunk starts with its topic title, category and date.

**Skipping tiny posts** keeps "thanks, that worked!" out of search results.

## Incremental embedding

Each chunk stores a SHA-256 hash of its text. On re-run, an unchanged hash means "keep the vector". Only new or edited text costs model time. This is our main lever for "overly large amounts of data": the weekly run only embeds the week's new posts.
