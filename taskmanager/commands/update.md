---
allowed-tools: Skill(taskmanager), Bash
argument-hint: "<id> [--status <s>] [--title \"...\"] [--prompt \"...\"] [--scope up|down] [--tag add:<t>] [--depends-on <id>] [--move-to <id>] | [--tags] [--validate-deps]"
description: Update task fields, status, scope, tags, dependencies, or position
---

# Update Command

You are implementing `taskmanager:update`.

## Purpose

Unified command for all task modifications. Replaces: `update-task`, `update-status`, `scope`, `tags`, `dependencies`, `move`.

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Routing

### Status updates
- `update <id> --status <s>` → set status for one task
- `update <id1>,<id2> --status <s>` → batch status update (comma-separated IDs)

### Field updates
- `update <id> --title "..."` → update title
- `update <id> --description "..."` → update description
- `update <id> --details "..."` → update implementation details
- `update <id> --test-strategy "..."` → update test strategy
- `update <id> --priority <critical|high|medium|low>` → update priority
- `update <id> --type <feature|bug|chore|analysis|spike>` → update type
- `update <id> --complexity <XS|S|M|L|XL>` → update complexity scale

### AI-assisted updates
- `update <id> --prompt "..."` → AI rewrites the task based on prompt
- `update <id> --prompt "..." --from <id>` → cascade AI updates to dependents

### Scope adjustments
- `update <id> --scope up "description"` → increase scope
- `update <id> --scope down "description"` → decrease scope
- `update <id> --scope up "description" --cascade` → cascade to dependents

### Tag operations
- `update <id> --tag add:<tag>` → add a tag
- `update <id> --tag remove:<tag>` → remove a tag
- `update --tags` → list all tags with counts
- `update --tags rename:<old>:<new>` → rename a tag globally
- `update --tags filter:<tag>` → show tasks with a tag

### Dependency operations
- `update <id> --depends-on <id>` → add dependency
- `update <id> --remove-dep <id>` → remove dependency
- `update --validate-deps` → validate all dependencies
- `update --validate-deps --fix` → auto-fix invalid dependencies

### Move/reparent
- `update <id> --move-to <parent-id>` → reparent task under new parent

## Behavior

### 0. Initialize session

1. Generate session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Update state table with session_id.
3. Log to `activity.log`.

### Status updates

#### Single task:
```sql
UPDATE tasks SET
    status = '<new-status>',
    updated_at = datetime('now'),
    started_at = CASE
        WHEN '<new-status>' = 'in-progress' AND started_at IS NULL
        THEN datetime('now') ELSE started_at
    END,
    completed_at = CASE
        WHEN '<new-status>' IN ('done', 'canceled', 'duplicate') AND completed_at IS NULL
        THEN datetime('now') ELSE completed_at
    END,
    duration_seconds = CASE
        WHEN '<new-status>' IN ('done', 'canceled', 'duplicate') AND started_at IS NOT NULL
        THEN CAST((julianday(datetime('now')) - julianday(started_at)) * 86400 AS INTEGER)
        ELSE duration_seconds
    END
WHERE id = '<task-id>';
```

**Note:** Status updates via this command do NOT propagate to parent tasks. Use `taskmanager:run` for proper status propagation.

Valid statuses: `draft`, `planned`, `in-progress`, `blocked`, `paused`, `done`, `canceled`, `duplicate`, `needs-review`

#### Batch:
Same query with `WHERE id IN (<comma-separated-ids>)`.

### Direct field updates

Build UPDATE statement dynamically with only specified fields:
```sql
UPDATE tasks SET
    title = '<new-title>',
    -- ... only fields that were explicitly provided ...
    updated_at = datetime('now')
WHERE id = '<task-id>';
```

If `--complexity` is provided, re-estimate `estimate_seconds` based on new scale.

### AI-assisted update (--prompt)

1. Load full task context from database.
2. Call `taskmanager` skill to rewrite the task based on prompt.
3. Show before/after diff to user.
4. Ask for confirmation via AskUserQuestion.
5. Apply changes.
6. If `--from <id>` specified, cascade to dependent tasks (up to 5 levels deep).

### Scope adjustments (--scope)

1. Load task from database.
2. Use `taskmanager` skill to adjust scope up or down based on description.
3. Update task fields (description, details, test_strategy, complexity, estimate).
4. If `--cascade`, find and update dependent tasks.
5. Recompute parent estimates.
6. If scope up increased complexity to M+, suggest running `taskmanager:plan --expand <id>`.

### Tag operations (--tag, --tags)

#### list (--tags):
```sql
SELECT tag.value as Tag, COUNT(DISTINCT t.id) as 'Task Count',
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) as Done,
    SUM(CASE WHEN t.status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining
FROM tasks t, json_each(t.tags) tag
WHERE t.archived_at IS NULL
GROUP BY tag.value
ORDER BY COUNT(DISTINCT t.id) DESC;
```

#### add:
```sql
UPDATE tasks SET
    tags = json_insert(tags, '$[#]', '<tag>'),
    updated_at = datetime('now')
WHERE id = '<task-id>';
```

#### remove:
```sql
UPDATE tasks SET
    tags = (
        SELECT COALESCE(json_group_array(tag.value), '[]')
        FROM json_each(tags) tag WHERE tag.value != '<tag>'
    ),
    updated_at = datetime('now')
WHERE id = '<task-id>';
```

#### rename:
```sql
UPDATE tasks SET
    tags = (
        SELECT json_group_array(
            CASE WHEN tag.value = '<old>' THEN '<new>' ELSE tag.value END
        ) FROM json_each(tags) tag
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.tags) tag WHERE tag.value = '<old>'
);
```

#### filter:
```sql
SELECT t.id as ID, SUBSTR(t.title, 1, 40) as Title, t.status as Status,
       t.priority as Priority, COALESCE(t.complexity_scale, '-') as Size
FROM tasks t, json_each(t.tags) tag
WHERE tag.value = '<tag>' AND t.archived_at IS NULL
ORDER BY CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, t.id;
```

### Dependency operations

#### validate (--validate-deps):
Check for: missing references, self-references, circular dependencies, archived non-terminal references.

```sql
-- Missing references
SELECT t.id as task_id, d.value as missing_dep
FROM tasks t, json_each(t.dependencies) d
WHERE t.archived_at IS NULL AND d.value NOT IN (SELECT id FROM tasks);

-- Self-references
SELECT t.id FROM tasks t, json_each(t.dependencies) d WHERE d.value = t.id;

-- Circular dependencies (recursive CTE with depth limit 20)
```

#### fix (--validate-deps --fix):
Auto-remove missing references, self-references, and break cycles.

#### add (--depends-on):
```sql
UPDATE tasks SET
    dependencies = json_insert(dependencies, '$[#]', '<dep-id>'),
    updated_at = datetime('now')
WHERE id = '<task-id>';
```

Check for circular dependency before adding.

#### remove (--remove-dep):
```sql
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(tasks.dependencies) d WHERE d.value != '<dep-id>'
    ),
    updated_at = datetime('now')
WHERE id = '<task-id>';
```

### Move/reparent (--move-to)

1. Validate target parent exists and is not a descendant of the task being moved.
2. Calculate new ID: `<parent-id>.<next-child-number>`.
3. Create new task record with new ID and parent_id.
4. Update dependency references across all tasks.
5. Delete old task record.
6. Recompute parent estimates for both old and new parents.

### Cleanup

Log to `activity.log`. Reset state session.

## Logging

All logging goes to `.taskmanager/logs/activity.log`:
- Field changes with before/after
- Status transitions
- Tag operations
- Dependency changes
- Scope adjustments
- Move operations
- Errors

## Usage Examples

```bash
# Status update
taskmanager:update 1.2.3 --status done
taskmanager:update 1.2.3,1.2.4 --status in-progress

# Field updates
taskmanager:update 1.2 --title "Implement JWT authentication"
taskmanager:update 1.2 --priority critical --type bug

# AI rewrite
taskmanager:update 1.2 --prompt "Change to use Redis instead of database sessions"
taskmanager:update 1.2 --prompt "Switch to GraphQL" --from 1.2

# Scope
taskmanager:update 1.2 --scope up "Add rate limiting"
taskmanager:update 1.2 --scope down "Remove OAuth, JWT only" --cascade

# Tags
taskmanager:update --tags
taskmanager:update 1.2 --tag add:sprint-3
taskmanager:update 1.2 --tag remove:sprint-2
taskmanager:update --tags rename:sprint-3:sprint-4
taskmanager:update --tags filter:security

# Dependencies
taskmanager:update --validate-deps
taskmanager:update --validate-deps --fix
taskmanager:update 1.3 --depends-on 1.2
taskmanager:update 1.3 --remove-dep 1.2

# Move
taskmanager:update 2.1 --move-to 3
```

## Related Commands

- `taskmanager:show` - View tasks, dashboard, stats
- `taskmanager:run` - Execute tasks
- `taskmanager:plan` - Create and expand tasks
