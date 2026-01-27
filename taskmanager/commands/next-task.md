---
allowed-tools: Bash
description: Find and display the next task ready for execution based on dependencies and priority
argument-hint: "[--debug]"
---

# Next Task Command

You are implementing `taskmanager:next-task`.

## Purpose

Find the next available task based on:
1. Not already completed (done/canceled/duplicate)
2. Is a leaf task (no subtasks)
3. All dependencies satisfied
4. Sorted by priority (critical > high > medium > low)
5. Then by complexity (lower first)

## Behavior

### 1. Query next available task

```bash
sqlite3 -column -header .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    t.id,
    t.title,
    t.status,
    t.priority,
    t.complexity_scale,
    t.complexity_score,
    ROUND(COALESCE(t.estimate_seconds, 0) / 3600.0, 1) as estimate_hours,
    t.description
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
    COALESCE(t.complexity_score, 3),
    t.id
LIMIT 1;
"
```

### 2. Handle no available tasks

If query returns no results:

```
No available tasks found.

Possible reasons:
- All tasks are completed
- Remaining tasks are blocked by dependencies
- Remaining tasks have subtasks (not leaf tasks)

Run taskmanager:dashboard for full status overview.
```

### 3. Format output

```
=== Next Recommended Task ===

ID: 1.2.3
Title: Implement user authentication
Status: planned
Priority: high
Complexity: M (3)
Estimate: 4 hours

Description:
Add JWT-based authentication with login/logout endpoints...

To start working on this task:
  taskmanager:execute-task 1.2.3
```

## Debug Mode

With `--debug` flag, also show:
- Total tasks checked
- Tasks filtered by each criterion
- Dependency resolution details

## Notes

- Uses SQL subqueries for efficient dependency checking
- json_each() parses the dependencies JSON array
- Results are deterministic (ORDER BY includes id as tiebreaker)
