---
description: Create social media posts for LinkedIn, Instagram, or X/Twitter - standalone or derived from blog articles
allowed-tools: Skill(social-post-writer), Skill(author-profile), Skill(article-queue), Bash(bun:*)
argument-hint: <linkedin|instagram|x|all> <topic | derive ID> [--author ID]
user-invocable: true
---

# Social Media Post Creator

Create platform-optimized social media content for LinkedIn, Instagram, or X/Twitter.

## Usage

```bash
# Standalone posts from a topic
/article-writer:social linkedin "Why rate limiting matters"
/article-writer:social instagram "5 Laravel tips"
/article-writer:social x "The future of PHP"

# Derive from existing blog article
/article-writer:social linkedin derive 42
/article-writer:social instagram derive 42
/article-writer:social all derive 42    # All 3 platforms at once

# With author override
/article-writer:social linkedin "topic" --author mwguerra
```

## Process

1. **Parse arguments**: Determine platform, mode (standalone vs derive), topic/source ID, and author
2. **Resolve author**: Use specified author or default (lowest sort_order)
3. **Load platform defaults**: Read from settings `platform_defaults.<platform>`
4. **Calculate effective tone**: Apply platform's tone_adjustment to author's base tone
5. **Invoke Skill(social-post-writer)**: Pass all context for content creation

## Platform Quick Reference

| Platform | Length | Hashtags | Tone Shift |
|----------|--------|----------|------------|
| LinkedIn | 200-1300 words (default 600) | 3-5 | Formality +1 |
| Instagram | Caption: 2200 chars + Carousel: 2-10 slides | 20-30 | Formality -2, Opinionated +1 |
| X/Twitter | Tweet: 280 chars + Thread: 5-15 tweets | 1-3 | Formality -1, Opinionated +1 |

## Argument Parsing

```
/article-writer:social <platform> <topic-or-derive> [--author <id>]

<platform>: linkedin | instagram | x | all
<topic-or-derive>: "topic string" | derive <article-id>
--author <id>: Optional author override
```

### When platform is "all"

Create posts for all 3 platforms (linkedin, instagram, x) from the same topic or source article.

### Derive Mode

When using `derive <id>`:
1. Load the source blog article from DB
2. Extract key themes, arguments, and takeaways
3. Restructure for the target platform
4. Create a `social/` subfolder inside the source article's folder
5. Insert new article row with `derived_from` FK pointing to source

### Standalone Mode

When using a topic string:
1. Create a new article folder with lighter structure (no code/, no 03_drafts/, etc.)
2. Research the topic (lighter than blog research)
3. Create platform-optimized content
4. Insert new article row with `platform` set accordingly
