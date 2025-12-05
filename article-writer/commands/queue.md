---
description: Manage the article tasks queue - view status, add, update, or filter articles
allowed-tools: Skill(article-queue), Bash(bun:*)
argument-hint: <status | list | add | show ID | reset ID | skip ID>
---

# Article Queue Management

Manage the `.article_writer/article_tasks.json` queue.

## Usage

**View status:**
```
/article-writer:queue status
/article-writer:queue status pending
```

**View articles:**
```
/article-writer:queue list
/article-writer:queue list area:PHP
/article-writer:queue show 42
```

**Modify articles:**
```
/article-writer:queue reset 42
/article-writer:queue skip 42
/article-writer:queue update 42 status:review
```

**Add new:**
```
/article-writer:queue add
```

## Status Summary

Shows:
- Total by status
- Next pending article
- Recently processed
- Stuck (in_progress) articles

## Queue Location

File: `.article_writer/article_tasks.json`
Schema: `.article_writer/schemas/article-tasks.schema.json`

## Status Values

| Status | Meaning |
|--------|---------|
| pending | Ready to process |
| in_progress | Currently writing |
| draft | Created, needs review |
| review | Under editorial review |
| published | Live |
| archived | Skipped/obsolete |
