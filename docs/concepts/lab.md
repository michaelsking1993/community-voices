# Concepts lab: guess, then measure

Six sentences, embedded with our model (all-MiniLM-L6-v2). I guessed first, then we measured.

| | Sentence |
|---|---|
| A | My reviews disappeared after I synced |
| B | I lost all my progress when AnkiWeb synced |
| C | How do I make the card text bigger? |
| D | Can I change the font size on my flashcards? |
| E | Sync failed with a network error |
| F | What's a good number of new cards per day? |

## My guesses

- Most similar: A–B and C–D
- Least similar: D–E
- A–B similarity: 0.8

## Measured (cosine similarity, 1 = same meaning, 0 = unrelated)

| Rank | Pair | Similarity | |
|---|---|---|---|
| 1 | C–D | 0.621 | same question, different words |
| 2 | A–B | 0.370 | both about losing data on sync |
| 3 | B–E | 0.275 | both about sync |
| 4 | C–F | 0.261 | both "how should I set up my cards" |
| 5 | A–E | 0.240 | sync again |
| … | … | … | |
| 15 | D–E | −0.055 | font size vs network error: least similar |

The same A–B comparison in SQL, with pgvector's cosine *distance* operator:

```sql
SELECT a.embedding <=> b.embedding;  -- 0.63  (distance = 1 − similarity = 1 − 0.37)
```

## What I took away

- **The ranking was right; the number was not.** I guessed 0.8 for A–B; it is 0.37. Absolute scores depend on the model (small models like MiniLM spread scores low), so you never hard-code "0.8 means relevant". You rank by distance and take the top k, and only add a cut-off after measuring on real queries.
- **Meaning beats shared words.** C and D share almost no words ("text bigger" vs "font size") and score highest of all.
- **Topic pulls things together, even when the intent differs.** B–E (lost progress vs network error) score fairly close just because both are about syncing. That is why each chunk gets a header: the topic is part of what gets matched.
- **Distance vs similarity.** pgvector's `<=>` returns distance (0 = identical). Smaller is closer.
