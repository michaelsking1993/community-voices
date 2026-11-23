# Clustering: finding themes nobody named

**In one line:** clustering groups vectors that sit close together, so threads about the same thing end up in the same group without anyone listing the topics in advance. The model only *names* each group afterwards.

## k-means in four lines

1. Pick k starting points ("centroids"), spread out (k-means++).
2. Put every thread in the group of its nearest centroid.
3. Move each centroid to the average of its group.
4. Repeat 2-3 until nothing moves.

For unit vectors we compare by dot product (cosine similarity) and re-normalise each centroid after averaging. That variant is called *spherical* k-means. With a fixed random seed, the same week always gives the same themes.

## What k-means is bad at

| Weakness | What it means here | What we do |
|---|---|---|
| You must choose k | 8 themes a week is a guess | Fixed at 8: about 8 threads each. The report skips tiny themes |
| Every point must join a group | A one-off thread lands in the "closest" theme, making it a bit mixed | The model is told to say when a cluster is mixed (kind "other") |
| Assumes round, similar-sized groups | One busy topic can split, two quiet ones can merge | Good enough to see the week; the counts are exact either way |

**HDBSCAN** picks the number of clusters itself and leaves outliers unassigned, which suits messy text better. It would be the next thing to try, but has no maintained Ruby implementation.

## Why cluster threads, not posts

A 100-reply thread about one bug would become its own "theme" if we clustered posts. A theme should be *several* threads about the same thing. So each thread gets one vector: the average of its chunk embeddings from that week (`avg(embedding)` in SQL), and the thread's post count is what makes a theme "big".

## Who does what

| Job | Done by | Why |
|---|---|---|
| Grouping | k-means on embeddings | Finds structure nobody named |
| Counting threads, posts, people | SQL | Exact; models are bad at counting |
| Naming and summarising | Claude, from 12 titles and 5 excerpts per cluster | Turns a group of vectors into words a person can read |
