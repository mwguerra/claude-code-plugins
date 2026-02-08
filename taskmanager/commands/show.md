---
allowed-tools: Bash
argument-hint: "[<id> [field]] | [--next [N]] | [--stats [...]]"
description: View dashboard, task details, next tasks, or statistics
---

# Show Command

You are implementing `taskmanager:show`.

## Purpose

Unified read-only view into the task database. Replaces: `dashboard`, `get-task`, `next-task`, `stats`.

## Routing

- `show` (no args) → dashboard view
- `show <id>` → full task JSON
- `show <id> <field>` → single field value
- `show --next [N]` → next N available tasks (default: 1)
- `show --stats [--summary|--json|--status|--priority|--levels|--remaining|--time|--completion|--tags]`

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### Check database exists

```bash
DB=".taskmanager/taskmanager.db"
if [[ ! -f "$DB" ]]; then
    echo "Error: Taskmanager not initialized. Run taskmanager:init first."
    exit 1
fi
```

### `show` — Dashboard

```bash
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    TASKMANAGER DASHBOARD                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    COUNT(*) as 'Total Tasks',
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as 'Done',
    SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END) as 'In Progress',
    SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END) as 'Blocked',
    SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as 'Remaining',
    ROUND(100.0 * SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) / COUNT(*), 1) || '%' as 'Complete'
FROM tasks WHERE archived_at IS NULL;
"
```

Include sections for: progress bar, status breakdown, priority breakdown, time estimates, next tasks, tag distribution (if tags exist).

**Removed:** The writing progress section from the old dashboard is no longer shown.

### `show <id>` — Task JSON

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks WHERE id = '$1';
" | jq '.[0] // empty'
```

If no result: `Error: Task '<id>' not found`

### `show <id> <field>` — Single field

```bash
sqlite3 .taskmanager/taskmanager.db "
SELECT $2 FROM tasks WHERE id = '$1';
"
```

Available columns: `id`, `title`, `status`, `priority`, `type`, `description`, `details`, `test_strategy`, `complexity_scale`, `estimate_seconds`, `started_at`, `completed_at`, `duration_seconds`, `dependencies`, `parent_id`, `tags`.

### `show --next [N]` — Next available tasks

Default N = 1. Uses the standard next-task query:

```bash
sqlite3 -column -header .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    t.id as ID,
    SUBSTR(t.title, 1, 40) as Title,
    t.priority as Priority,
    COALESCE(t.complexity_scale, '-') as Size,
    ROUND(COALESCE(t.estimate_seconds, 0) / 3600.0, 1) || 'h' as Est
FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (
      t.dependencies = '[]'
      OR NOT EXISTS (
          SELECT 1 FROM json_each(t.dependencies) d
          WHERE d.value NOT IN (SELECT id FROM done_ids)
      )
  )
ORDER BY
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    CASE t.complexity_scale WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE 2 END,
    t.id
LIMIT <N>;
"
```

If no tasks available, show helpful message about possible reasons.

### `show --stats [mode]` — Statistics

Supported modes (default: `--summary`):

- `--summary` — Full text summary with counts, status, priority, levels, time
- `--json` — Compact JSON output for programmatic use
- `--status` — Task counts by status
- `--priority` — Task counts by priority
- `--levels` — Task counts by hierarchy level
- `--remaining` — Count of remaining tasks
- `--time` — Estimated time remaining
- `--completion` — Completion percentage
- `--tags` — Tag distribution and statistics

All modes are **read-only** and use direct SQL queries.

#### --json

```bash
sqlite3 "$DB" "
SELECT json_object(
    'total', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL),
    'done', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'done'),
    'in_progress', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'in-progress'),
    'blocked', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'blocked'),
    'remaining', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status NOT IN ('done', 'canceled', 'duplicate')),
    'by_status', (
        SELECT json_group_object(status, cnt)
        FROM (SELECT status, COUNT(*) as cnt FROM tasks WHERE archived_at IS NULL GROUP BY status)
    ),
    'by_priority', (
        SELECT json_group_object(priority, cnt)
        FROM (SELECT priority, COUNT(*) as cnt FROM tasks WHERE archived_at IS NULL GROUP BY priority)
    ),
    'estimated_remaining_seconds', (
        SELECT COALESCE(SUM(estimate_seconds), 0)
        FROM tasks
        WHERE archived_at IS NULL
          AND status NOT IN ('done', 'canceled', 'duplicate')
          AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id)
    )
);
"
```

## Notes

- This command is **read-only** — it does not modify any files or database.
- Uses SQLite queries for efficiency.
- All task ordering uses `complexity_scale` CASE expression.
- For full dashboard with all sections, use bare `show`.
- For programmatic access, use `show --stats --json`.

## Usage Examples

```bash
# Dashboard
taskmanager:show

# Get full task
taskmanager:show 1.2.3

# Get specific field
taskmanager:show 1.2.3 status

# Next task
taskmanager:show --next

# Next 5 tasks
taskmanager:show --next 5

# Statistics
taskmanager:show --stats
taskmanager:show --stats --json
taskmanager:show --stats --tags
```
