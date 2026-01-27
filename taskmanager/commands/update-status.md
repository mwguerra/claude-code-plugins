---
allowed-tools: Bash
description: Update task status by ID or list of IDs without loading the full database
argument-hint: "<status> <id1> [id2...] | Examples: done 1.2.3 | in-progress 1.2.3 1.2.4"
---

# Update Status Command

You are implementing `taskmanager:update-status`.

## Purpose

Batch update task status via SQL. This command does NOT propagate status to parent tasks - use `execute-task` for that.

## Arguments

- `$1` (required): New status value
- `$2+` (required): One or more task IDs

## Valid Statuses

- `draft`, `planned`, `in-progress`, `blocked`, `paused`, `done`, `canceled`, `duplicate`, `needs-review`

## Behavior

### 1. Validate arguments

```bash
VALID_STATUSES="draft planned in-progress blocked paused done canceled duplicate needs-review"
NEW_STATUS="$1"
shift
TASK_IDS=("$@")

if [[ -z "$NEW_STATUS" ]] || [[ ${#TASK_IDS[@]} -eq 0 ]]; then
    echo "Usage: taskmanager:update-status <status> <id1> [id2...]"
    exit 1
fi

if ! echo "$VALID_STATUSES" | grep -qw "$NEW_STATUS"; then
    echo "Error: Invalid status '$NEW_STATUS'"
    echo "Valid: $VALID_STATUSES"
    exit 1
fi
```

### 2. Build and execute UPDATE query

```bash
# Build ID list for SQL IN clause
ID_LIST=$(printf "'%s'," "${TASK_IDS[@]}" | sed 's/,$//')

# Update with appropriate timestamps
sqlite3 .taskmanager/taskmanager.db "
UPDATE tasks SET
    status = '$NEW_STATUS',
    updated_at = datetime('now'),
    started_at = CASE
        WHEN '$NEW_STATUS' = 'in-progress' AND started_at IS NULL
        THEN datetime('now')
        ELSE started_at
    END,
    completed_at = CASE
        WHEN '$NEW_STATUS' IN ('done', 'canceled', 'duplicate') AND completed_at IS NULL
        THEN datetime('now')
        ELSE completed_at
    END,
    duration_seconds = CASE
        WHEN '$NEW_STATUS' IN ('done', 'canceled', 'duplicate') AND started_at IS NOT NULL
        THEN CAST((julianday(datetime('now')) - julianday(started_at)) * 86400 AS INTEGER)
        ELSE duration_seconds
    END
WHERE id IN ($ID_LIST);
"

# Report results
UPDATED=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE id IN ($ID_LIST) AND status = '$NEW_STATUS';")
echo "Updated $UPDATED task(s) to status '$NEW_STATUS'"
```

### 3. Log the change

```bash
echo "$(date -Iseconds) [DECISION] [update-status] Set status=$NEW_STATUS for tasks: ${TASK_IDS[*]}" >> .taskmanager/logs/decisions.log
```

## Examples

**Mark single task done:**
```bash
sqlite3 .taskmanager/taskmanager.db "UPDATE tasks SET status = 'done', completed_at = datetime('now'), updated_at = datetime('now') WHERE id = '1.2.3';"
```

**Mark multiple tasks in-progress:**
```bash
sqlite3 .taskmanager/taskmanager.db "UPDATE tasks SET status = 'in-progress', started_at = COALESCE(started_at, datetime('now')), updated_at = datetime('now') WHERE id IN ('1.2.3', '1.2.4');"
```

## Notes

- This command does **NOT** propagate status to parent tasks
- Use `taskmanager:execute-task` for proper status propagation
- Timestamps are set automatically based on status transitions
- Changes are logged to decisions.log
