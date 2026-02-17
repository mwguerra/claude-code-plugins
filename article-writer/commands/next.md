---
description: Get the next pending article from the queue to work on
allowed-tools: Skill(article-queue), Bash(bun:*)
---

# Next Article

Get the first pending article from the queue to start working on.

**Database**: `.article_writer/article_writer.db`
**Documentation**: [docs/COMMANDS.md](../docs/COMMANDS.md#next)

## Usage

```
/article-writer:next
```

## What It Does

1. Queries the SQLite database for articles with `status = 'pending'`
2. Sorts by ID (ascending)
3. Returns the first pending article with full details
4. Shows the command to start writing it

## Output

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  ID:       5
  Title:    Implementing Rate Limiting in Laravel
  Area:     Backend
  Author:   mwguerra

  Subject:
  How to implement and customize rate limiting in Laravel APIs
  using built-in middleware and Redis.

────────────────────────────────────────────────────────────────
  To start writing:
  /article-writer:article from-queue 5
────────────────────────────────────────────────────────────────

  Queue: 1 pending, 3 draft, 2 published
═══════════════════════════════════════════════════════════════
```

## When Queue is Empty

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  No pending articles in queue!

  Queue: 0 pending, 5 draft, 10 published

  To add articles:
  /article-writer:queue add "Article Title" --area "Category"
═══════════════════════════════════════════════════════════════
```

## Priority Order

Articles are selected by ascending ID (first pending wins).

## Related Commands

| Command | Description |
|---------|-------------|
| `/article-writer:article from-queue <id>` | Start writing the article |
| `/article-writer:queue status` | See full queue status |
| `/article-writer:queue list pending` | See all pending articles |

## Process

After getting the next article:

1. Review the article details
2. Run `/article-writer:article from-queue <id>` to start
3. Follow the article creation workflow
4. Article status changes: `pending` -> `in_progress` -> `draft`
