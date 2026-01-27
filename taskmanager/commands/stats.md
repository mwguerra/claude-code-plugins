---
allowed-tools: Bash
description: Get quick task statistics without loading entire database - saves tokens and context
---

# Task Statistics Command

You are implementing `taskmanager:stats`.

## Purpose

This command provides quick, efficient access to task statistics using direct SQLite queries. This is more efficient than loading the entire database into context.

## Arguments

- `[mode]` (optional): The type of statistics to retrieve. Defaults to `--summary`.

Available modes:

**Read-only statistics:**
- `--summary` - Full text summary with all statistics
- `--json` - Full JSON output for programmatic use
- `--next` - Next recommended task only
- `--next5` - Next 5 recommended tasks
- `--status` - Task counts by status
- `--priority` - Task counts by priority
- `--levels` - Task counts by level/depth
- `--remaining` - Count of remaining tasks
- `--time` - Estimated time remaining
- `--completion` - Completion statistics

## Behavior

### 1. Check if database exists

```bash
DB=".taskmanager/taskmanager.db"
if [[ ! -f "$DB" ]]; then
    echo "Error: Taskmanager not initialized. Run taskmanager:init first."
    exit 1
fi
```

### 2. Execute the appropriate query based on mode

#### --summary (default)

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Task Statistics ==="
echo ""

# Get overall counts
sqlite3 "$DB" "
SELECT
    'Total: ' || COUNT(*),
    'Done: ' || SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END),
    'In Progress: ' || SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END),
    'Blocked: ' || SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END),
    'Remaining: ' || SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END)
FROM tasks WHERE archived_at IS NULL;
" | tr '|' '\n'

# Completion percentage
sqlite3 "$DB" "
SELECT 'Completion: ' || ROUND(
    100.0 * SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0),
    1
) || '%'
FROM tasks WHERE archived_at IS NULL;
"

echo ""
echo "--- By Status ---"
sqlite3 -column -header "$DB" "
SELECT status, COUNT(*) as count
FROM tasks WHERE archived_at IS NULL
GROUP BY status ORDER BY count DESC;
"

echo ""
echo "--- By Priority ---"
sqlite3 -column -header "$DB" "
SELECT priority, COUNT(*) as count
FROM tasks WHERE archived_at IS NULL
GROUP BY priority
ORDER BY CASE priority
    WHEN 'critical' THEN 0
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2
    ELSE 3
END;
"

echo ""
echo "--- By Level ---"
sqlite3 -column -header "$DB" "
SELECT
    LENGTH(id) - LENGTH(REPLACE(id, '.', '')) + 1 as level,
    COUNT(*) as count
FROM tasks WHERE archived_at IS NULL
GROUP BY level ORDER BY level;
"

echo ""
# Time remaining
sqlite3 "$DB" "
SELECT 'Estimated remaining: ' ||
    COALESCE(SUM(estimate_seconds), 0) || ' seconds (' ||
    ROUND(COALESCE(SUM(estimate_seconds), 0) / 3600.0, 1) || ' hours / ' ||
    ROUND(COALESCE(SUM(estimate_seconds), 0) / 28800.0, 1) || ' days)'
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);
"
```

#### --json

```bash
DB=".taskmanager/taskmanager.db"

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

#### --next

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Next Recommended Task ==="
sqlite3 -line "$DB" "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    id as ID,
    title as Title,
    status as Status,
    priority as Priority,
    complexity_scale as Complexity,
    COALESCE(estimate_seconds / 3600, 0) || ' hours' as Estimate
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
    CASE t.priority
        WHEN 'critical' THEN 0
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    COALESCE(t.complexity_score, 3)
LIMIT 1;
"
```

#### --next5

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Next 5 Recommended Tasks ==="
sqlite3 -column -header "$DB" "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    id as ID,
    SUBSTR(title, 1, 40) as Title,
    priority as Priority,
    COALESCE(complexity_scale, '-') as Cmplx
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
    CASE t.priority
        WHEN 'critical' THEN 0
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    COALESCE(t.complexity_score, 3)
LIMIT 5;
"
```

#### --status

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Tasks by Status ==="
sqlite3 -column -header "$DB" "
SELECT
    status as Status,
    COUNT(*) as Count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL), 1) || '%' as Percent
FROM tasks WHERE archived_at IS NULL
GROUP BY status
ORDER BY Count DESC;
"
```

#### --priority

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Tasks by Priority ==="
sqlite3 -column -header "$DB" "
SELECT
    priority as Priority,
    COUNT(*) as Count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL), 1) || '%' as Percent
FROM tasks WHERE archived_at IS NULL
GROUP BY priority
ORDER BY CASE priority
    WHEN 'critical' THEN 0
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2
    ELSE 3
END;
"
```

#### --levels

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Tasks by Level ==="
sqlite3 -column -header "$DB" "
SELECT
    'Level ' || (LENGTH(id) - LENGTH(REPLACE(id, '.', '')) + 1) as Level,
    COUNT(*) as Count
FROM tasks WHERE archived_at IS NULL
GROUP BY LENGTH(id) - LENGTH(REPLACE(id, '.', ''))
ORDER BY 1;
"
```

#### --remaining

```bash
DB=".taskmanager/taskmanager.db"

sqlite3 "$DB" "
SELECT COUNT(*) || ' remaining tasks'
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate');
"
```

#### --time

```bash
DB=".taskmanager/taskmanager.db"

sqlite3 "$DB" "
SELECT
    'Remaining time: ' ||
    COALESCE(SUM(estimate_seconds), 0) || ' seconds (' ||
    ROUND(COALESCE(SUM(estimate_seconds), 0) / 3600.0, 1) || ' hours / ' ||
    ROUND(COALESCE(SUM(estimate_seconds), 0) / 28800.0, 1) || ' work days)'
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);
"
```

#### --completion

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Completion Statistics ==="
sqlite3 -line "$DB" "
SELECT
    COUNT(*) as Total,
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as Done,
    SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining,
    ROUND(100.0 * SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1) as 'Percent Complete'
FROM tasks WHERE archived_at IS NULL;
"
```

---

## Output Format

Present the statistics in a clean, readable format. For the json mode, output raw JSON that can be piped to other tools.

Example summary output:
```
=== Task Statistics ===

Total: 150
Done: 45
In Progress: 3
Blocked: 2
Remaining: 100
Completion: 30.0%

--- By Status ---
status       count
-----------  -----
planned      95
done         45
draft        5
in-progress  3
blocked      2

--- By Priority ---
priority  count
--------  -----
critical  5
high      25
medium    80
low       40

--- By Level ---
level    count
-------  -----
Level 1  10
Level 2  40
Level 3  100

Estimated remaining: 360000 seconds (100.0 hours / 12.5 days)
```

## Notes

- All modes are **read-only** and do not modify any files.
- Uses `sqlite3` for efficient querying without loading full data into context.
- Ideal for quick status checks before starting work.
- For full dashboard with critical path analysis, use `taskmanager:dashboard`.
- For getting a single task, use `taskmanager:get-task <id> [key]`.
- For updating status, use `taskmanager:update-status <status> <id1> [id2...]`.
