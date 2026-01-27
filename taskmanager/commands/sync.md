---
allowed-tools: Bash, TaskCreate, TaskList, TaskUpdate
description: Two-way sync with Claude Code native tasks
argument-hint: "[--push | --pull | --status | --clear]"
---

# Sync Command

You are implementing `taskmanager:sync`.

## Purpose

Synchronize taskmanager tasks with Claude Code's native task system for session-based tracking.

## Arguments

- `--push` - Push taskmanager tasks to native task list
- `--pull` - Pull completed native tasks back to taskmanager
- `--status` - Show sync status without making changes
- `--clear` - Clear sync mappings
- (no args) - Two-way sync (push then pull)

## Behavior

### Push Workflow

1. Query next N available tasks from taskmanager:

```bash
sqlite3 -json .taskmanager/taskmanager.db "
WITH done_ids AS (SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate'))
SELECT id, title, description, priority, complexity_scale, estimate_seconds
FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (t.dependencies = '[]' OR NOT EXISTS (
      SELECT 1 FROM json_each(t.dependencies) d WHERE d.value NOT IN (SELECT id FROM done_ids)
  ))
ORDER BY CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END
LIMIT 5;
"
```

2. For each task, use TaskCreate:

```
TaskCreate with:
  subject: [task.title]
  description: [task.description]
  activeForm: "Working on [task.title]"
```

3. Log the sync mapping:

```bash
sqlite3 .taskmanager/taskmanager.db "
INSERT INTO sync_log (direction, task_id, native_task_id, action, session_id)
VALUES ('push', '$TASK_ID', '$NATIVE_TASK_ID', 'created', '$SESSION_ID');
"
```

### Pull Workflow

1. Call TaskList to get all native tasks
2. Match against sync_log by native_task_id
3. For completed native tasks:

```bash
sqlite3 .taskmanager/taskmanager.db "
-- Update taskmanager task
UPDATE tasks SET
    status = 'done',
    completed_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = '$TASK_ID';

-- Log the sync
INSERT INTO sync_log (direction, task_id, native_task_id, action, session_id)
VALUES ('pull', '$TASK_ID', '$NATIVE_TASK_ID', 'completed', '$SESSION_ID');
"
```

4. Run status propagation for each completed task

### Status Mode

```bash
echo "=== Sync Status ==="

# Tasks pushed this session
sqlite3 -box .taskmanager/taskmanager.db "
SELECT task_id, native_task_id, action, synced_at
FROM sync_log
WHERE direction = 'push'
ORDER BY synced_at DESC
LIMIT 10;
"

# Tasks pulled this session
sqlite3 -box .taskmanager/taskmanager.db "
SELECT task_id, native_task_id, action, synced_at
FROM sync_log
WHERE direction = 'pull'
ORDER BY synced_at DESC
LIMIT 10;
"
```

### Clear Mode

```bash
sqlite3 .taskmanager/taskmanager.db "DELETE FROM sync_log;"
echo "Sync mappings cleared"
```

## Notes

- Sync is session-scoped - mappings track which tasks were pushed in this session
- Native tasks are ephemeral; taskmanager tasks are persistent
- Push creates native tasks for tracking; pull captures completions
