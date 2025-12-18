---
description: View article queue status, list pending/completed articles with filters, and show task details
allowed-tools: Skill(article-queue), Bash(bun:*)
argument-hint: <status | list [filter] | show ID>
---

# Article Queue Management

Manage the article task queue.

**File location:** `.article_writer/article_tasks.json`
**Schema:** `.article_writer/schemas/article-tasks.schema.json`
**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writerqueue)

## Commands

### View queue summary

```bash
/article-writer:queue status
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts queue`

Shows: total articles, count by status, count by author, top areas.

### List articles

```bash
/article-writer:queue list                    # All articles
/article-writer:queue list pending            # By status
/article-writer:queue list author:mwguerra    # By author
/article-writer:queue list area:Laravel       # By area
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/queue.ts list [filter]`

### Show article details

```bash
/article-writer:queue show 42
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/queue.ts show 42`

### Modify article

```bash
/article-writer:queue reset 42               # Reset to pending
/article-writer:queue skip 42                # Archive article
```

## Status Values

| Status | Meaning | Icon |
|--------|---------|------|
| `pending` | Ready to process | ⏳ |
| `in_progress` | Currently being written | 🔄 |
| `draft` | Written, needs review | 📝 |
| `review` | Under editorial review | 👀 |
| `published` | Published live | ✅ |
| `archived` | Skipped or obsolete | 📦 |

## Status Flow

```
pending → in_progress → draft → review → published
               ↓
           archived
```

## Queue Entry Fields

| Field | Description |
|-------|-------------|
| `id` | Unique identifier |
| `title` | Article title |
| `subject` | Brief description |
| `area` | Category (Laravel, PHP, etc.) |
| `difficulty` | Beginner/Intermediate/Advanced |
| `status` | Current status |
| `author.id` | Assigned author |
| `sources_used` | Researched URLs (after writing) |
| `example` | Example info (after writing) |
| `output_folder` | Article folder path (after writing) |
| `output_files` | Per-language file paths (after writing) |
