# Step 3: Ingest the forum

## What we built

A crawler that reads the Anki forum's public Discourse JSON API, one request per second, and upserts posts into `topics` and `posts`. `IngestWeekJob` runs it every Monday at 6am on Solid Queue. `bin/rails 'ingest:backfill[12]'` loads history; `bin/setup` loads 2 weeks by default so a reviewer's first run takes about 20 seconds.

## Why this way

- **`/posts.json` instead of walking every topic.** It returns the 50 newest posts *with their raw text* and pages backwards with `?before=<post id>`. One week is about 7 requests. Walking topics would cost one request per topic (60+ a week) plus extra pages for long threads. (DECISIONS #7)
- **Upsert by the forum's post id.** Running the crawler twice, or overlapping two weekly runs, updates rows instead of duplicating them. That makes retries and the 8-day overlap safe. (DECISIONS #8)
- **One request per second, a clear User-Agent, and backing off on HTTP 429.** It is someone else's server. (DECISIONS #9)
- **Filter at ingest only what is never useful** (moderator actions, hidden and deleted posts). Short "thanks!" posts are kept here and skipped at the chunking step, so post counts still match the forum.

## How it works

```
IngestWeekJob (Mondays 6am, Solid Queue)
  └─ Ingest::ForumCrawler.call(since: 8.days.ago)
       ├─ Discourse::Client#category_names     GET /categories.json   → "Anki › FSRS"
       └─ loop:
            Discourse::Client#latest_posts       GET /posts.json?before=<min id>
            keep posts created since `since`, drop non-regular posts
            Topic.upsert_all / Post.upsert_all   (unique on discourse_id)
            stop when a whole page is older than `since`
```

`Discourse::Throttle` enforces the one-second gap. Its clock and sleeper are injected, so the specs run instantly and never touch the network (WebMock blocks it, and every fixture is made up).

**A bug the real data caught:** the first version stopped at the *first* post older than `since`. Post ids are only roughly in date order, so one stray old post ended a 2-week crawl after 5 days. Now it stops when a *whole page* is older. There is a spec for it.

## Check: does it match the forum?

On 2026-11-23, for the last 7 days:

| | Forum (`/about.json`) | Ours |
|---|---|---|
| New topics | 67 | 65 |
| Posts | 517 | 342 |

Topics match within 2. Posts are lower most likely because the forum's own count also includes private messages and staff-only posts, which the public API does not return, and we drop moderator actions.

**How big is a week?** `bin/rails ingest:stats` says one full week is about 310-340 posts and roughly 45,000-55,000 tokens (at ~4 characters per token). That fits in a large context window, which is exactly why the A/B test has a "paste everything" arm: RAG has to beat that, not just beat nothing.

## What I learned

Ingestion is the "E" and "L" of ETL: extract from an API, load into tables. The important properties are *politeness* (rate limits), *idempotency* (upserts keyed on the source's id, so any run can be repeated), and *windowing* (only fetch what is new, with a small overlap so nothing falls through the gap). The "T" (cleaning, chunking, embedding) is step 4.

## What I would do next

- Track post edits: we re-fetch only the last 8 days, so an edit to an older post is missed. Discourse exposes `updated_at`; a periodic re-crawl could pick those up.
- Cache raw responses to disk so re-running the transform never needs the network. Deferred because a full re-crawl of 12 weeks takes only ~2 minutes.
