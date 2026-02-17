# X/Twitter Post Format Reference

## Constraints

| Parameter | Value |
|-----------|-------|
| **Tweet max** | 280 characters |
| **Thread tweets** | 5-15 (default 8) |
| **Hashtags** | 1-3 |
| **Tone shift** | Formality -1, Opinionated +1 from base |
| **Companion project** | No |

## Single Tweet Structure

```
[Strong standalone statement or insight]

[Optional: 1-3 hashtags]
```

## Tweet Guidelines

- **280 characters maximum** — count carefully
- Write for shareability (people retweet insights, not paragraphs)
- Be direct and punchy
- Use line breaks for emphasis
- Hashtags: 1-3 maximum, only if they add value

## Thread Structure

```
Tweet 1: [HOOK - Strong opener that makes people click "Show this thread"]
Tweet 2: [Context or problem statement]
Tweet 3-N: [Key points, one per tweet]
Tweet N+1: [Summary or contrarian twist]
Tweet N+2: [CTA - Follow, retweet, reply]
```

### Thread Guidelines

- **Tweet 1 is everything** — if it doesn't hook, nobody reads the rest
- **One idea per tweet** — don't try to cram
- **Number the tweets** for scanability: "1/8", "2/8", etc. (optional but helpful)
- **Each tweet should stand alone** if retweeted individually
- **End with engagement CTA** — "What would you add?" or "RT if you agree"
- **Avoid walls of text** — mix short and medium tweets
- **Use line breaks** within tweets for readability

### Thread Tweet Length Guide

| Tweet Type | Ideal Length |
|------------|-------------|
| Hook (tweet 1) | 200-280 chars — use the full space |
| Key points | 150-260 chars |
| CTA (last tweet) | 100-200 chars |

## Output Files

```
{slug}.x.tweet.{lang}.md    # Single tweet version
{slug}.x.thread.{lang}.md   # Thread version
```

### Frontmatter

```yaml
---
platform: x
type: tweet | thread
author: {author_id}
derived_from: {source_id or null}
created_at: {ISO timestamp}
char_count: {count}           # for single tweet
tweet_count: {count}          # for thread
hashtags: [tag1, tag2]
---
```

## Example Single Tweet

```markdown
---
platform: x
type: tweet
author: mwguerra
created_at: 2026-02-17T10:00:00Z
char_count: 248
hashtags: [Laravel, PHP]
---

Your API has no rate limiting?

That means one script can take down your production server.

Laravel ships with ThrottleRequests middleware. You don't need Redis. You don't need packages.

Just add it. Today.

#Laravel #PHP
```

## Example Thread

```markdown
---
platform: x
type: thread
author: mwguerra
created_at: 2026-02-17T10:00:00Z
tweet_count: 8
hashtags: [Laravel, RateLimiting]
---

## 1/8

Your Laravel API has no rate limiting.

That means any script can send 10,000 requests/second and take down your entire production server.

Here's what I learned protecting an API serving 50k requests/day:

## 2/8

Step 1: Use the built-in middleware.

Laravel ships with ThrottleRequests. You don't need Redis. You don't need packages.

Route::middleware('throttle:60,1')

That's 60 requests per minute. Done.

## 3/8

Step 2: Don't use one limit for everything.

Your login endpoint and your search endpoint have completely different abuse patterns.

Auth: 5/min
API reads: 60/min
API writes: 20/min

## 4/8

Step 3: Return useful response headers.

X-RateLimit-Remaining
X-RateLimit-Limit
Retry-After

Your API consumers need to know where they stand. Don't make them guess.

## 5/8

Step 4: Custom 429 responses.

Don't just drop the connection. Return a clear JSON error:

{"error": "Rate limit exceeded", "retry_after": 30}

Be helpful, even when saying no.

## 6/8

Step 5: Monitor before you need to.

Log rate limit hits. Track which endpoints get hammered.

You'll be surprised — it's rarely the endpoints you expect.

## 7/8

The biggest mistake?

Waiting until you're already under attack.

Rate limiting is like server insurance. Boring until you need it. Then it's the only thing that matters.

## 8/8

TL;DR:

- Use built-in middleware (no Redis needed)
- Different limits per endpoint
- Return rate limit headers
- Custom 429 responses
- Monitor everything

What rate limiting strategy are you using?

#Laravel #RateLimiting
```
