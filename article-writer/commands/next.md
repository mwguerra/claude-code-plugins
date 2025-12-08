---
name: next
description: Get the next pending article from the queue to work on
usage: /article-writer:next
arguments: []
---

# Next Article

Get the first pending article from the queue to start working on.

**File**: `.article_writer/article_tasks.json`
**Documentation**: [docs/COMMANDS.md](../docs/COMMANDS.md#next)

## Usage

```
/article-writer:next
```

## What It Does

1. Loads `.article_writer/article_tasks.json`
2. Filters articles with `status: "pending"`
3. Sorts by priority (if set) then by order in file
4. Returns the first pending article with full details
5. Shows the command to start writing it

## Output

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  ID:       laravel-rate-limiting
  Title:    Implementing Rate Limiting in Laravel
  Area:     Backend Development
  Author:   mwguerra
  Priority: high

  Subject:
  How to implement and customize rate limiting in Laravel APIs
  using built-in middleware and Redis.

────────────────────────────────────────────────────────────────
  To start writing:
  /article-writer:article laravel-rate-limiting
────────────────────────────────────────────────────────────────

  Queue: 1 pending, 3 draft, 2 published
═══════════════════════════════════════════════════════════════
```

## When Queue is Empty

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  ✓ No pending articles in queue!

  Queue: 0 pending, 5 draft, 10 published

  To add articles:
  /article-writer:queue add "Article Title" --area "Category"
═══════════════════════════════════════════════════════════════
```

## Priority Order

Articles are selected in this order:

1. **Priority** (if set): `critical` → `high` → `normal` → `low`
2. **Position** in file (first pending wins)

## Related Commands

| Command | Description |
|---------|-------------|
| `/article-writer:article <id>` | Start writing the article |
| `/article-writer:queue status` | See full queue status |
| `/article-writer:queue list pending` | See all pending articles |

## Process

After getting the next article:

1. Review the article details
2. Run `/article-writer:article <id>` to start
3. Follow the article creation workflow
4. Article status changes: `pending` → `in_progress` → `draft`
