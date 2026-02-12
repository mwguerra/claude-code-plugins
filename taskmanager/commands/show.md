---
allowed-tools: Bash
argument-hint: "[<id> [field]] | [--next [N]] | [--stats [...]] | [--deferrals [<task-id>]] | [--milestones] | [--analysis [id]]"
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
- `show --stats [--summary|--json|--status|--priority|--levels|--remaining|--time|--completion|--tags|--moscow|--milestones]`
- `show --deferrals` → all pending deferrals
- `show --deferrals <task-id>` → deferrals targeting a specific task
- `show --milestones` → milestone progress table
- `show --analysis [id]` → view plan analyses

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

Include sections for: progress bar, status breakdown, priority breakdown, time estimates, next tasks, tag distribution (if tags exist), **current milestone progress** (if milestones exist), **MoSCoW distribution** (if tasks have moscow), **pending deferrals summary** (if any exist).

#### Milestone section (in dashboard)

Only show if milestones exist:

```bash
MILESTONE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM milestones;")
if [[ "$MILESTONE_COUNT" -gt 0 ]]; then
    echo "--- Milestone Progress ---"
    sqlite3 -box "$DB" "
    SELECT m.id as ID, m.title as Milestone, m.status as Status,
        COUNT(t.id) as Tasks,
        SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) as Done,
        ROUND(100.0 * SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) / NULLIF(COUNT(t.id), 0), 1) || '%' as Complete
    FROM milestones m
    LEFT JOIN tasks t ON t.milestone_id = m.id AND t.archived_at IS NULL
    GROUP BY m.id
    ORDER BY m.phase_order;
    "
fi
```

#### MoSCoW section (in dashboard)

Only show if tasks have moscow values:

```bash
MOSCOW_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE moscow IS NOT NULL AND archived_at IS NULL;")
if [[ "$MOSCOW_COUNT" -gt 0 ]]; then
    echo "--- MoSCoW Distribution ---"
    sqlite3 -box "$DB" "
    SELECT
        COALESCE(moscow, 'unset') as MoSCoW,
        COUNT(*) as Tasks,
        SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as Done,
        SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining
    FROM tasks WHERE archived_at IS NULL
    GROUP BY moscow ORDER BY
        CASE moscow WHEN 'must' THEN 0 WHEN 'should' THEN 1 WHEN 'could' THEN 2 WHEN 'wont' THEN 3 ELSE 4 END;
    "
fi
```

#### Deferrals section (in dashboard)

Only show if pending deferrals exist:

```bash
DEFERRAL_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM deferrals WHERE status = 'pending';")
if [[ "$DEFERRAL_COUNT" -gt 0 ]]; then
    echo "--- Pending Deferrals ---"
    sqlite3 -box "$DB" "
    SELECT
        COUNT(*) as 'Pending',
        SUM(CASE WHEN target_task_id IS NOT NULL THEN 1 ELSE 0 END) as 'Assigned',
        SUM(CASE WHEN target_task_id IS NULL THEN 1 ELSE 0 END) as 'Unassigned'
    FROM deferrals WHERE status = 'pending';
    "
fi
```

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

Available columns: `id`, `title`, `status`, `priority`, `type`, `description`, `details`, `test_strategy`, `complexity_scale`, `estimate_seconds`, `started_at`, `completed_at`, `duration_seconds`, `dependencies`, `parent_id`, `tags`, `milestone_id`, `acceptance_criteria`, `moscow`, `business_value`, `dependency_types`.

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
    ),
    'pending_deferrals', (SELECT COUNT(*) FROM deferrals WHERE status = 'pending'),
    'unassigned_deferrals', (SELECT COUNT(*) FROM deferrals WHERE status = 'pending' AND target_task_id IS NULL),
    'by_moscow', (
        SELECT json_group_object(COALESCE(moscow, 'unset'), cnt)
        FROM (SELECT moscow, COUNT(*) as cnt FROM tasks WHERE archived_at IS NULL GROUP BY moscow)
    ),
    'milestones', (SELECT COUNT(*) FROM milestones),
    'active_milestone', (SELECT id FROM milestones WHERE status = 'active' ORDER BY phase_order LIMIT 1)
);
"
```

### `show --deferrals [task-id]` — Deferrals view

#### All pending deferrals (no task-id):

```bash
sqlite3 -column -header "$DB" "
SELECT
    d.id as ID,
    SUBSTR(d.title, 1, 30) as Title,
    d.source_task_id as Source,
    COALESCE(d.target_task_id, 'unassigned') as Target,
    d.status as Status,
    SUBSTR(d.reason, 1, 30) as Reason
FROM deferrals d
WHERE d.status = 'pending'
ORDER BY d.created_at;
"
```

#### Deferrals for a specific task (as target):

```bash
sqlite3 -column -header "$DB" "
SELECT
    d.id as ID,
    SUBSTR(d.title, 1, 30) as Title,
    d.source_task_id as Source,
    d.status as Status,
    SUBSTR(d.reason, 1, 40) as Reason,
    SUBSTR(d.body, 1, 50) as Details
FROM deferrals d
WHERE d.target_task_id = '<task-id>'
ORDER BY d.status, d.created_at;
"
```

If no deferrals found: `"No deferrals found for task <task-id>"`

### `show --milestones` — Milestone progress

```bash
sqlite3 -column -header "$DB" "
SELECT m.id as ID,
    m.title as Milestone,
    m.status as Status,
    m.phase_order as Phase,
    COUNT(t.id) as Tasks,
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) as Done,
    SUM(CASE WHEN t.status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) / NULLIF(COUNT(t.id), 0), 1) || '%' as Complete
FROM milestones m
LEFT JOIN tasks t ON t.milestone_id = m.id AND t.archived_at IS NULL
GROUP BY m.id
ORDER BY m.phase_order;
"
```

Also show business value distribution per milestone:

```bash
sqlite3 -column -header "$DB" "
SELECT m.id as Milestone,
    SUM(CASE WHEN t.business_value = 5 THEN 1 ELSE 0 END) as 'BV-5',
    SUM(CASE WHEN t.business_value = 4 THEN 1 ELSE 0 END) as 'BV-4',
    SUM(CASE WHEN t.business_value = 3 THEN 1 ELSE 0 END) as 'BV-3',
    SUM(CASE WHEN t.business_value <= 2 THEN 1 ELSE 0 END) as 'BV-1-2'
FROM milestones m
LEFT JOIN tasks t ON t.milestone_id = m.id AND t.archived_at IS NULL
GROUP BY m.id
ORDER BY m.phase_order;
"
```

If no milestones exist: `"No milestones defined. Use taskmanager:plan to create milestones from a PRD."`

### `show --analysis [id]` — View plan analyses

#### All analyses (no id):

```bash
sqlite3 -column -header "$DB" "
SELECT id as ID,
    prd_source as Source,
    SUBSTR(prd_hash, 1, 8) || '...' as Hash,
    json_array_length(tech_stack) as 'Tech',
    json_array_length(assumptions) as 'Assumptions',
    json_array_length(risks) as 'Risks',
    json_array_length(decisions) as 'Decisions',
    created_at as Created
FROM plan_analyses
ORDER BY created_at DESC;
"
```

#### Specific analysis (with id):

```bash
sqlite3 -json "$DB" "SELECT * FROM plan_analyses WHERE id = '<id>';" | jq '.[0] // empty'
```

Display formatted sections: tech stack, assumptions, risks, ambiguities, NFRs, scope, cross-cutting concerns, decisions.

If no analyses found: `"No plan analyses found. Run taskmanager:plan to analyze a PRD."`

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

# Deferrals
taskmanager:show --deferrals
taskmanager:show --deferrals 1.2.3

# Milestones
taskmanager:show --milestones

# Plan analyses
taskmanager:show --analysis
taskmanager:show --analysis PA-001
```
