# Instagram Post Format Reference

## Constraints

| Parameter | Value |
|-----------|-------|
| **Caption max** | 2200 characters |
| **Visible preview** | First 125 characters (before "...more") |
| **Hashtags** | 20-30 |
| **Tone shift** | Formality -2, Opinionated +1 from base |
| **Emojis** | Encouraged |
| **Carousel slides** | 2-10 (default 7) |
| **Companion project** | No |

## Caption Structure

```
[HOOK - Must grab attention in first 125 characters]
.
[BODY - Expanded content with emoji accents]
.
[VALUE SUMMARY or CTA]
.
.
.
[HASHTAGS - 20-30 tags]
```

## Caption Guidelines

- **First 125 characters are critical** — this is all users see before tapping "...more"
- Use line breaks (`.` on a line) for visual spacing
- Include 3-5 emojis naturally in the text
- End with a question or CTA to drive engagement
- Put hashtags after 3 line breaks (pushes them below the fold)

## Carousel Structure

Each slide is a visual card with text overlay.

### Slide Template

```markdown
## Slide {number}: {title}

**Body:** {2-3 key sentences}

**Visual direction:** {description of what should be on this slide visually}
```

### Carousel Flow

1. **Slide 1 (Cover)**: Title slide — bold statement or question
2. **Slides 2-N-1 (Content)**: One key point per slide
3. **Slide N (Closer)**: Summary + CTA + "Save this for later"

### Slide Guidelines

- **Text per slide**: 30-50 words maximum
- **Font**: Large, readable on mobile
- **One idea per slide**: Don't cram
- **Visual consistency**: Same color scheme, fonts throughout
- **Numbered steps**: If applicable, number them clearly

## Output Files

```
{slug}.instagram.{lang}.md           # Caption
{slug}.instagram.carousel.{lang}.md  # Carousel slides
```

### Caption Frontmatter

```yaml
---
platform: instagram
author: {author_id}
derived_from: {source_id or null}
created_at: {ISO timestamp}
char_count: {count}
hashtag_count: {count}
carousel_slides: {count}
---
```

## Example Caption

```markdown
---
platform: instagram
author: mwguerra
created_at: 2026-02-17T10:00:00Z
char_count: 1680
hashtag_count: 25
carousel_slides: 7
---

Your API is one script away from crashing. Here's how to fix it in 15 minutes with Laravel.

Rate limiting isn't optional anymore. If your API is public, someone WILL abuse it. The good news? Laravel makes this stupidly easy.

Swipe through for the 5-step setup that protects your app without any extra packages.

Save this for your next project.

What's the worst API abuse story you've heard? Tell me in the comments.

.
.
.

#laravel #php #webdev #api #ratelimiting #backend #programming #developer #coding #webdevelopment #softwaredeveloper #tech #laravelframework #phpdeveloper #backenddeveloper #apisecurity #devtips #codingtips #programminglife #softwareengineering #laraveltips #phptips #fullstack #techcommunity #100daysofcode
```

## Example Carousel

```markdown
---
platform: instagram
type: carousel
slides: 7
---

## Slide 1: Cover

**Body:** Rate Limiting in Laravel — Protect Your API in 15 Minutes

**Visual direction:** Bold title text on dark gradient background with a shield icon

## Slide 2: The Problem

**Body:** One malicious script can send 10,000 requests per second to your API. Without rate limiting, your server goes down.

**Visual direction:** Red warning icon with server crash illustration

## Slide 3: Step 1 — Middleware

**Body:** Laravel ships with ThrottleRequests middleware. Add it to your API routes. No package needed.

**Visual direction:** Code snippet showing Route::middleware('throttle:60,1')

## Slide 4: Step 2 — Tiered Limits

**Body:**
- Auth: 5/min
- API reads: 60/min
- API writes: 20/min

Different endpoints, different limits.

**Visual direction:** Three-tier diagram with different colors per tier

## Slide 5: Step 3 — Headers

**Body:** Always return X-RateLimit-Remaining and Retry-After headers. Your API consumers need to know their limits.

**Visual direction:** HTTP response showing rate limit headers highlighted

## Slide 6: Step 4 — Custom Responses

**Body:** Return 429 Too Many Requests with a clear message. Don't just drop the connection.

**Visual direction:** Code snippet showing custom JSON response

## Slide 7: CTA

**Body:** Rate limiting = server insurance. Don't wait until you need it.

Save this post. Follow @author for more Laravel tips.

**Visual direction:** Author branding, follow CTA, save icon
```
