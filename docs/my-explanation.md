# The pipeline, in my own words

I wrote this at the end of the build, once I could explain every piece without looking. It's where my learning actually landed. Lightly tidied for reading; the explanations are mine.

## The short version

The pipeline has three parts:

1. **Ingest.** A job crawls the Anki forum and chunks and embeds its posts so they can be searched later, using just a small neural network.
2. **Report.** A job uses an LLM to write the report: it defines themes, gets the chunks (evidence) most relevant to each theme, and has the LLM write a report that cites that evidence.
3. **Evaluate.** A rake task (or a button) runs an A/B test of the same report written three ways: with every post of the week pasted in, with RAG (our themes plus the retrieved evidence for each), and with no context. Plus a backtest of the predictions.

Paste-all comes out sliiiiiightly better. But it won't scale: once there are more and more threads and posts, they won't fit in the prompt. That's the real case for RAG; costing a third to a half as much is a bonus.

## 1. Ingest

Once a week we crawl Anki's forum and save it to the database. Then we cut each post into 150-word chunks, with a 30-word overlap so that a sentence cut at a chunk boundary still appears whole in one chunk. Each chunk starts with a short header (thread title, category, date) so its vector carries the topic.

Then we embed each chunk with a lightweight model that turns text into a list of 384 numbers, each between -1 and 1. That lets us compare two chunks by meaning: multiply the numbers at each position and add them all up. The closer to 1, the more they point in the same direction. Postgres's `<=>` cosine operator gives 1 minus that closeness, which is their "distance": small means they say similar things.

Once the chunks and embeddings are stored, they're searchable, and the report can be written at any point, as many times as we like.

## 2. Report

### Themes (clustering)

First we decide how many themes: the number of threads divided by 12, bumped up to 4 or down to 8 if it falls outside that range. We didn't want too many, so the report stays readable. (If the number of threads ever got super big, we'd need something like tree RAG: more themes, then combine those sub-themes again.)

Each thread has a position on the "map": the average of its chunks' embeddings. We place the first theme marker on one thread, picked "randomly" but with a fixed seed, so the same week always gives the same themes. The other markers go on other threads, picked with much more weight on ones far from the existing markers, so they start out spread across the map.

Then it's k-means:

1. Every thread joins the marker it's closest to.
2. Each marker moves to the average position of its threads.
3. Repeat, since a thread may now be closer to a different marker, until no thread switches.

The LLM then gets the 4 to 8 groups. For each, we give it the titles of the 12 threads closest to the marker and the first 80 words of the 5 closest threads. From that it writes a theme: a label, a one-line summary and a "kind" (problem, request, discussion, announcement or other). Groups with fewer than 2 threads are dropped. Each theme's label plus summary becomes its search query.

### Retrieval (the "R" in RAG)

For each theme, we embed its label plus summary on the fly, and search for chunks from the report's week whose embedding is closest: `ORDER BY embedding <=> query`.

- Each theme gets the closest chunks under a **0.6 distance cut-off** (chosen with an eval set of 15 hand-labelled queries), up to a **budget based on its size**: 36 chunks shared across themes, 3 to 12 each, **at most 2 per thread**.
- Each theme's **2 busiest threads** (by post count) always get their closest chunk in.
- We run the same query over the **previous 12 weeks** for 3 chunks (1 per thread): "this came up before".
- Every search and its hits are logged in `retrievals` and `retrieval_hits`, which power the "most retrieved" stats on the Charts page.

The chosen chunks are numbered [E1], [E2] ... and handed to generation.

### Generation

One LLM call writes the whole report. If retrieval found nothing, we skip the call and the report says "not enough evidence". Otherwise the LLM gets four things:

1. The chunks, grouped by theme, each labelled [E1], [E2] ... so it can cite them.
2. A stat sheet: threads, posts and people for the week and for each theme, plus trend counts and recent beta and release threads.
3. The rules: use only the evidence and the stat sheet, and cite the evidence behind every claim.
4. A JSON schema for the answer: a headline, a short overview, one section per theme (with 1 or 2 word-for-word quotes), and "predictions for next week", each with a cited reason and a confidence (low, medium or high).

A plain Ruby class, `Grounding`, then grades the report: do the citations exist, are the quotes exact, and how many sentences have no citation at all. The scores are saved with the report, and the citations link to the real forum posts.

Keep in mind that this step **does not see all the chunks**, only a sample of the closest ones. That's why the stat sheet matters.

## 3. Evaluate

### A/B test

Three reports for the same week: **no context** (no evidence), **paste-all** (every post of the week) and **RAG** (the method above). All three use the same builder, prompt and model; only the evidence differs. Then three judges:

1. **The code inspector:** are the citations real, are quotes copied exactly, how many sentences have no source?
2. **The support judge:** a fact checker that reads each cited sentence next to the posts it cites and asks whether the post actually says that.
3. **The blind ranker:** gets the three reports shuffled, with no sign of which is which, and scores each 1 to 5 on coverage, accuracy, specificity and usefulness. It's a different model, to avoid self-preference bias.

Paste-all ranked first every time and RAG second, close on coverage and specificity, at a third to a half of the cost. No context could only guess.

### Backtest

Each report ends with predictions for next week. We can't grade those for the current week, because next week hasn't happened yet, but we can go back to past weeks and check.

It's RAG again: each prediction becomes a search query over the following week's chunks. We keep the 5 closest posts plus that week's exact counts from SQL, and one LLM call judges each prediction: happened (1), partly (½), didn't happen (0) or can't tell, citing the posts it used. Code downgrades any "happened" or "partly" without a real citation to "can't tell".

The result was a hit rate of 0.42, mostly "partly", and 0.45 when I re-ran it from scratch. It's only honest because there's no peeking: old reports were written only with data from before their week ended, and a spec proves it by planting a "future" post and checking it never reaches the prompt.
