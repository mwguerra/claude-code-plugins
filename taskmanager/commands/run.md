---
allowed-tools: Skill(taskmanager), Skill(taskmanager-memory)
argument-hint: "[<task-id>] [--batch N] [--memory \"...\"] [--task-memory \"...\"]"
description: Execute a single task or batch of tasks with memory support and status propagation
---

# Run Command

You are implementing `taskmanager:run`.

## Purpose

Execute tasks with dependency resolution, memory application, and status propagation. Replaces: `execute-task`, `run-tasks`.

## Arguments

- `$1` (optional): Task ID to execute. If omitted, picks the next available task.
- `--batch N`: Execute up to N tasks sequentially (default: 1 if omitted)
- `--memory "description"` or `-gm "description"`: Add a global memory (persists to memories table)
- `--task-memory "description"` or `-tm "description"`: Add a task-scoped memory (temporary)

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Routing

- `run` → next available task (single)
- `run <id>` → specific task
- `run --batch N` → batch execution of up to N tasks
- Memory flags can be combined with any mode

## Behavior

### 0. Initialize session

1. Generate session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Update state table:
   ```sql
   UPDATE state SET
       session_id = '<session-id>',
       last_update = datetime('now')
   WHERE id = 1;
   ```
3. Log to `.taskmanager/logs/activity.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started run command
   ```

### 1. Parse arguments and process memory flags

- Extract task ID from `$1` if provided.
- Extract `--batch N` value if provided.
- If `--memory` provided: create global memory via `taskmanager-memory` skill.
- If `--task-memory` provided: add to `state.task_memory` JSON array.

For batch mode, task memories use `taskId = "*"` (applies to all tasks in batch).

### 2. Find task(s) to execute

#### Single task mode (no --batch):

If task ID provided, load it:
```sql
SELECT * FROM tasks WHERE id = '<task-id>' AND archived_at IS NULL;
```

If no task ID, find next available:
```sql
WITH done_ids AS (
    SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT * FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (t.dependencies = '[]' OR NOT EXISTS (
      SELECT 1 FROM json_each(t.dependencies) d
      WHERE d.value NOT IN (SELECT id FROM done_ids)
  ))
ORDER BY
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    CASE t.complexity_scale WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE 2 END,
    t.id
LIMIT 1;
```

#### Batch mode (--batch N):

Loop up to N times, each iteration finding the next available task using the same query.

### 3. Check dependencies (single task mode with explicit ID)

```sql
SELECT d.value FROM tasks t, json_each(t.dependencies) d
WHERE t.id = '<task-id>'
  AND d.value NOT IN (
      SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
  );
```

If unmet dependencies exist:
- Use AskUserQuestion to ask how to proceed:
  - "Execute a dependency task first"
  - "Mark dependencies as done and continue"
  - "Abort execution"

### 4. Load and apply memories (pre-execution)

- Use `taskmanager-memory` skill to query relevant memories.
- Load global memories (`importance >= 3`).
- Load task-scoped memories from `state.task_memory`.
- Display summary of applicable memories.
- Increment `use_count` and update `last_used_at` for applied memories.

### 5. Start execution

```sql
-- Update task status
UPDATE tasks SET
    status = 'in-progress',
    started_at = COALESCE(started_at, datetime('now')),
    updated_at = datetime('now')
WHERE id = '<task-id>';

-- Update state
UPDATE state SET
    current_task_id = '<task-id>',
    last_update = datetime('now')
WHERE id = 1;
```

Propagate in-progress status to ancestors using recursive CTE.

### 6. Execute the task

- Perform code changes, file edits, or other work implied by the task.
- Apply loaded memories as constraints.
- If `test_strategy` exists, follow it to verify implementation.

### 7. Post-execution memory review

- Review task-scoped memories for promotion to global.
- Ask user for promotion decisions.
- Clear task-specific memories from state.

### 8. Complete with status propagation

```sql
-- Update leaf task
UPDATE tasks SET
    status = '<final-status>',
    completed_at = CASE WHEN '<final-status>' = 'done' THEN datetime('now') ELSE completed_at END,
    duration_seconds = CASE
        WHEN '<final-status>' IN ('done', 'canceled', 'duplicate') AND started_at IS NOT NULL
        THEN CAST((julianday(datetime('now')) - julianday(started_at)) * 86400 AS INTEGER)
        ELSE duration_seconds
    END,
    updated_at = datetime('now')
WHERE id = '<task-id>';

-- Propagate to ancestors
WITH RECURSIVE ancestors AS (
    SELECT parent_id as id FROM tasks WHERE id = '<task-id>' AND parent_id IS NOT NULL
    UNION ALL
    SELECT t.parent_id FROM tasks t JOIN ancestors a ON t.id = a.id WHERE t.parent_id IS NOT NULL
)
UPDATE tasks SET
    status = (
        SELECT CASE
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress') THEN 'in-progress'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked') THEN 'blocked'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review') THEN 'needs-review'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned','draft','paused')) THEN 'planned'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done') THEN 'done'
            ELSE 'canceled'
        END
    ),
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors);
```

Archive if terminal. Clear state current_task_id.

### 9. Batch completion (if --batch)

After all tasks or reaching limit:
- Review batch task memories (taskId = "*") for promotion.
- Show batch summary with SQL aggregates.

### 10. Cleanup

Log completion to `activity.log`. Reset state session.

## Logging

All logging goes to `.taskmanager/logs/activity.log` (single log file):
- Task status transitions
- Memory application and conflict resolutions
- Batch start/end summaries
- Errors encountered

## Usage Examples

```bash
# Execute next available task
taskmanager:run

# Execute specific task
taskmanager:run 1.2.3

# Batch execute 5 tasks
taskmanager:run --batch 5

# With global memory
taskmanager:run --memory "Always validate API inputs"

# With task-scoped memory
taskmanager:run 1.2.3 --task-memory "Focus on error handling"
```

## Related Commands

- `taskmanager:show` - View tasks, dashboard, stats
- `taskmanager:update` - Update task fields and status
- `taskmanager:memory` - Manage memories directly
