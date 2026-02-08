---
allowed-tools: Skill(taskmanager), Bash
description: Update task fields with optional AI-assisted rewriting and cascade to dependents
argument-hint: "<task-id> [--title \"...\"] [--description \"...\"] [--details \"...\"] [--test-strategy \"...\"] [--priority <level>] [--type <type>] [--prompt \"...\"] [--from <id>] [--debug]"
---

# Update Task Command

You are implementing `taskmanager:update-task`.

## Purpose

Update task details with either direct field changes or AI-assisted rewriting. Supports cascading changes to dependent tasks when the update fundamentally changes the task's approach.

## Arguments

### Direct field updates:
- `$1` (required): Task ID to update (e.g., `1.2.3`)
- `--title "new title"`: Update the task title
- `--description "new description"`: Update the description
- `--details "new details"`: Update implementation details
- `--test-strategy "new strategy"`: Update the test strategy
- `--priority <critical|high|medium|low>`: Update priority
- `--type <feature|bug|chore|analysis|spike>`: Update task type
- `--complexity <XS|S|M|L|XL>`: Update complexity scale (score auto-calculated)
- `--tags '["tag1","tag2"]'`: Replace tags (JSON array)

### AI-assisted updates:
- `--prompt "description of changes"`: AI rewrites the task based on the prompt
- `--from <id>`: When used with `--prompt`, also update all tasks that depend on `<id>` (cascade)

### Flags:
- `--debug` or `-d`: Enable verbose debug logging

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Check for `--debug` / `-d` flag.
3. Update state table:
   ```sql
   UPDATE state SET
       session_id = '<session-id>',
       debug_enabled = <1|0>,
       last_update = datetime('now')
   WHERE id = 1;
   ```
4. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started update-task command for task <id>
   ```

### 1. Load the task

```sql
SELECT * FROM tasks WHERE id = '<task-id>' AND archived_at IS NULL;
```

If the task doesn't exist or is archived, inform the user and stop.

### 2. Direct field updates (when no `--prompt`)

If any direct field flags are provided (title, description, details, etc.):

1. Build the UPDATE statement dynamically with only the specified fields:
   ```sql
   UPDATE tasks SET
       title = COALESCE('<new-title>', title),
       description = COALESCE('<new-description>', description),
       -- ... only fields that were explicitly provided ...
       updated_at = datetime('now')
   WHERE id = '<task-id>';
   ```

2. If `--complexity` is provided, also update complexity_score:
   ```
   XS = 0, S = 1, M = 2, L = 3, XL = 4
   ```
   And re-estimate `estimate_seconds` based on the new complexity.

3. If `--priority` is provided and it changes, log the priority change.

### 3. AI-assisted update (when `--prompt` is provided)

1. **Load full task context**:
   ```sql
   SELECT id, title, description, details, test_strategy, priority, type,
          complexity_score, complexity_scale, complexity_reasoning, tags
   FROM tasks WHERE id = '<task-id>';
   ```

2. **Call the `taskmanager` skill** with instructions to:
   - Read the current task's full context.
   - Apply the prompt's instructions to rewrite the task.
   - Maintain the same level of detail and structure.
   - Re-assess complexity and estimate if the prompt changes the approach.
   - Update the test_strategy to match the new approach.
   - Return the updated fields.

3. **Show the diff to the user**:
   Present a before/after comparison of the changed fields:
   ```
   Task 1.2.3 update preview:

   Title: "Implement user auth" -> "Implement JWT-based user auth"

   Description (changed):
   - Old: "Implement user authentication using sessions..."
   + New: "Implement JWT-based authentication with refresh tokens..."

   Complexity: M (3) -> L (4)
   Estimate: 2h -> 4h
   ```

4. **Ask for confirmation** using AskUserQuestion:
   - "Apply these changes?"
   - Options: "Apply", "Edit further", "Cancel"

5. **Apply the changes**:
   ```sql
   UPDATE tasks SET
       title = '<new-title>',
       description = '<new-description>',
       details = '<new-details>',
       test_strategy = '<new-test-strategy>',
       complexity_score = <new-score>,
       complexity_scale = '<new-scale>',
       complexity_reasoning = '<new-reasoning>',
       estimate_seconds = <new-estimate>,
       updated_at = datetime('now')
   WHERE id = '<task-id>';
   ```

### 4. Cascade updates (when `--from <id>` with `--prompt`)

When `--from` is specified, also update dependent tasks:

1. **Find all tasks that depend on the target**, ordered by dependency chain:
   ```sql
   WITH RECURSIVE dep_chain AS (
       -- Start with tasks directly depending on the target
       SELECT t.id, t.title, t.description, t.details, t.dependencies, 1 as depth
       FROM tasks t
       WHERE t.archived_at IS NULL
         AND t.status NOT IN ('done', 'canceled', 'duplicate')
         AND EXISTS (
             SELECT 1 FROM json_each(t.dependencies) d
             WHERE d.value = '<from-id>'
         )
       UNION ALL
       -- Recursively find tasks depending on those
       SELECT t.id, t.title, t.description, t.details, t.dependencies, dc.depth + 1
       FROM tasks t
       JOIN dep_chain dc ON EXISTS (
           SELECT 1 FROM json_each(t.dependencies) d
           WHERE d.value = dc.id
       )
       WHERE t.archived_at IS NULL
         AND t.status NOT IN ('done', 'canceled', 'duplicate')
         AND dc.depth < 5  -- Limit cascade depth
   )
   SELECT * FROM dep_chain ORDER BY depth, id;
   ```

2. **For each dependent task**:
   - Use the `taskmanager` skill to analyze how the original change affects this task.
   - Generate updated description/details if relevant.
   - Apply updates.
   - Log to `decisions.log`.

3. **Summarize cascade results**.

### 5. Update parent estimates

If complexity or estimate changed, recompute parent estimates:
```sql
UPDATE tasks SET
    estimate_seconds = (
        SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
        FROM tasks c WHERE c.parent_id = tasks.id
          AND c.status NOT IN ('canceled', 'duplicate')
    ),
    updated_at = datetime('now')
WHERE id = (SELECT parent_id FROM tasks WHERE id = '<task-id>')
  AND EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);
```

### 6. Summarize for the user

Report:
- Fields that were updated.
- New complexity and estimate if changed.
- Number of dependent tasks updated (if cascade was used).

### 7. Cleanup logging session

1. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Updated task <id>: <fields changed>. Cascade: <N tasks>
   ```
2. Reset state table:
   ```sql
   UPDATE state SET
       debug_enabled = 0,
       session_id = NULL,
       last_update = datetime('now')
   WHERE id = 1;
   ```

---

## Logging Requirements

**To errors.log** (ALWAYS):
- Task not found errors
- Invalid field values
- Database errors

**To decisions.log** (ALWAYS):
- Command start and completion
- Field changes (before -> after for key fields)
- Cascade updates

**To debug.log** (ONLY when `--debug` enabled):
- AI prompt and response details
- SQL queries executed
- Cascade chain traversal

---

## Usage Examples

```bash
# Direct field updates
taskmanager:update-task 1.2 --title "Implement JWT authentication"
taskmanager:update-task 1.2 --priority high --type bug
taskmanager:update-task 1.2 --test-strategy "Write Pest tests for login/logout/refresh endpoints"
taskmanager:update-task 1.2 --tags '["auth", "security", "sprint-3"]'

# AI-assisted update
taskmanager:update-task 1.2 --prompt "Change approach to use Redis instead of database sessions"

# AI-assisted update with cascade to dependents
taskmanager:update-task 1.2 --prompt "Switch from REST to GraphQL" --from 1.2

# Combined: direct field + AI rewrite
taskmanager:update-task 1.2 --priority critical --prompt "This is now a security fix"
```

---

## Related Commands

- `taskmanager:scope` - Adjust task scope up or down
- `taskmanager:get-task <id>` - View task details
- `taskmanager:update-status` - Update only the status field (batch mode)
- `taskmanager:expand` - Break down tasks into subtasks after updating
