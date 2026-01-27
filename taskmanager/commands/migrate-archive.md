---
allowed-tools: Bash
description: Archive existing completed tasks to reduce active task count
argument-hint: "[--dry-run]"
---

# Migrate Archive Command

You are implementing `taskmanager:migrate-archive`.

## Purpose

Mark completed tasks as archived. In SQLite, this sets the `archived_at` timestamp rather than moving to a separate file.

## Behavior

### 1. Dry run mode

```bash
if [[ "$1" == "--dry-run" ]]; then
    echo "=== Dry Run - Tasks that would be archived ==="
    sqlite3 -box .taskmanager/taskmanager.db "
    SELECT id, title, status, completed_at
    FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
      AND archived_at IS NULL
    ORDER BY completed_at;
    "

    COUNT=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE status IN ('done', 'canceled', 'duplicate') AND archived_at IS NULL;")
    echo ""
    echo "Would archive $COUNT tasks"
    exit 0
fi
```

### 2. Archive completed tasks

```bash
sqlite3 .taskmanager/taskmanager.db "
UPDATE tasks
SET archived_at = datetime('now'), updated_at = datetime('now')
WHERE status IN ('done', 'canceled', 'duplicate')
  AND archived_at IS NULL;
"

COUNT=$(sqlite3 .taskmanager/taskmanager.db "SELECT changes();")
echo "Archived $COUNT tasks"
```

### 3. Log the action

```bash
echo "$(date -Iseconds) [DECISION] [migrate-archive] Archived $COUNT completed tasks" >> .taskmanager/logs/decisions.log
```

## Notes

- Archived tasks remain in the database but are filtered out of most queries
- Use `WHERE archived_at IS NULL` to exclude archived tasks
- Much simpler than JSON approach (no file splitting needed)
