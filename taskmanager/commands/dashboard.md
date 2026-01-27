---
allowed-tools: Bash
description: Display task progress dashboard with status counts, completion stats, and critical path
---

# Dashboard Command

You are implementing `taskmanager:dashboard`.

## Purpose

Display a comprehensive progress dashboard using SQL aggregations.

## Behavior

### 1. Header and completion stats

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

### 2. Progress bar

```bash
# Calculate completion percentage
DONE=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'done';")
TOTAL=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL;")
PCT=$((DONE * 100 / TOTAL))
FILLED=$((PCT / 2))
EMPTY=$((50 - FILLED))

echo ""
printf "Progress: ["
printf '█%.0s' $(seq 1 $FILLED)
printf '░%.0s' $(seq 1 $EMPTY)
printf "] %d%%\n" $PCT
echo ""
```

### 3. Status breakdown

```bash
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Status Breakdown                                             │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    status as 'Status',
    COUNT(*) as 'Count',
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL), 1) || '%' as 'Percentage'
FROM tasks
WHERE archived_at IS NULL
GROUP BY status
ORDER BY CASE status
    WHEN 'in-progress' THEN 1
    WHEN 'blocked' THEN 2
    WHEN 'needs-review' THEN 3
    WHEN 'planned' THEN 4
    WHEN 'draft' THEN 5
    WHEN 'done' THEN 6
    ELSE 7
END;
"
```

### 4. Priority breakdown

```bash
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Priority Breakdown                                           │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    priority as 'Priority',
    COUNT(*) as 'Total',
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as 'Done',
    SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as 'Remaining'
FROM tasks
WHERE archived_at IS NULL
GROUP BY priority
ORDER BY CASE priority
    WHEN 'critical' THEN 0
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2
    ELSE 3
END;
"
```

### 5. Time estimates

```bash
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Time Estimates                                               │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    ROUND(COALESCE(SUM(CASE WHEN status = 'done' THEN duration_seconds ELSE 0 END), 0) / 3600.0, 1) as 'Completed (hrs)',
    ROUND(COALESCE(SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN estimate_seconds ELSE 0 END), 0) / 3600.0, 1) as 'Remaining (hrs)',
    ROUND(COALESCE(SUM(estimate_seconds), 0) / 3600.0, 1) as 'Total Estimated (hrs)'
FROM tasks
WHERE archived_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);
"
```

### 6. Next tasks

```bash
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Next Up                                                      │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    t.id as 'ID',
    SUBSTR(t.title, 1, 40) as 'Title',
    t.priority as 'Priority',
    t.complexity_scale as 'Size',
    ROUND(COALESCE(t.estimate_seconds, 0) / 3600.0, 1) || 'h' as 'Est'
FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (t.dependencies = '[]' OR NOT EXISTS (
      SELECT 1 FROM json_each(t.dependencies) d WHERE d.value NOT IN (SELECT id FROM done_ids)
  ))
ORDER BY
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    COALESCE(t.complexity_score, 3)
LIMIT 5;
"
```

### 7. Writing domain (if applicable)

```bash
# Check if any writing tasks exist
WRITING_COUNT=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE domain = 'writing' AND archived_at IS NULL;")

if [[ "$WRITING_COUNT" -gt 0 ]]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Writing Progress                                            │"
    echo "└─────────────────────────────────────────────────────────────┘"

    sqlite3 -box .taskmanager/taskmanager.db "
    SELECT
        writing_stage as 'Stage',
        COUNT(*) as 'Tasks',
        SUM(COALESCE(target_word_count, 0)) as 'Target Words',
        SUM(COALESCE(current_word_count, 0)) as 'Current Words'
    FROM tasks
    WHERE domain = 'writing' AND archived_at IS NULL
    GROUP BY writing_stage
    ORDER BY CASE writing_stage
        WHEN 'idea' THEN 1
        WHEN 'outline' THEN 2
        WHEN 'research' THEN 3
        WHEN 'draft' THEN 4
        WHEN 'rewrite' THEN 5
        WHEN 'edit' THEN 6
        WHEN 'copyedit' THEN 7
        WHEN 'proofread' THEN 8
        WHEN 'ready-to-publish' THEN 9
        WHEN 'published' THEN 10
        ELSE 11
    END;
    "
fi
```

## Notes

- Uses SQLite's -box format for pretty tables
- All calculations done in SQL for efficiency
- Writing section only shown if writing tasks exist
