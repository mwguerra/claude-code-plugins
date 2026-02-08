---
allowed-tools: Skill(taskmanager), Bash
description: Adjust task scope up (add requirements) or down (simplify) with optional cascade to dependents
argument-hint: "<up|down> <task-id> \"description\" [--cascade] [--debug]"
---

# Scope Command

You are implementing `taskmanager:scope`.

## Purpose

Dynamically adjust the scope of a task up or down. Scope changes can optionally cascade to dependent tasks, ensuring downstream work is updated to reflect the new requirements.

## Arguments

- `$1` (required): Direction — `up` or `down`
- `$2` (required): Task ID to adjust (e.g., `1.2.3`)
- `$3` (required): Description of the scope change (quoted string)
- `--cascade`: Also update dependent tasks to reflect the scope change
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
   <timestamp> [DECISION] [<session-id>] Started scope <up|down> command for task <id>
   ```

### 1. Parse and validate arguments

- `$1` must be `up` or `down`.
- `$2` must be a valid task ID.
- `$3` must be a non-empty description of the change.
- Extract `--cascade` and `--debug` flags.

### 2. Load the task

```sql
SELECT id, title, description, details, test_strategy, priority, type,
       complexity_score, complexity_scale, complexity_reasoning,
       complexity_expansion_prompt, estimate_seconds, tags, dependencies
FROM tasks
WHERE id = '<task-id>'
  AND archived_at IS NULL;
```

If the task doesn't exist or is archived, inform the user and stop.
If the task is in a terminal status (`done`, `canceled`, `duplicate`), warn the user and ask for confirmation.

### 3. Scope Up

When direction is `up` (adding requirements, increasing complexity):

1. **AI-assisted scope expansion**: Use the `taskmanager` skill to:
   - Analyze the current task `description`, `details`, and `test_strategy`.
   - Apply the scope change description to expand the task.
   - Generate updated `description`, `details`, `test_strategy`.
   - Re-assess `complexity_score` and `complexity_scale` (should stay the same or increase).
   - Re-estimate `estimate_seconds` (should stay the same or increase).

2. **Update the task**:
   ```sql
   UPDATE tasks SET
       description = '<updated-description>',
       details = '<updated-details>',
       test_strategy = '<updated-test-strategy>',
       complexity_score = <new-score>,
       complexity_scale = '<new-scale>',
       complexity_reasoning = '<updated-reasoning>',
       estimate_seconds = <new-estimate>,
       updated_at = datetime('now')
   WHERE id = '<task-id>';
   ```

3. **Check if expansion is needed**: If complexity increased to M, L, or XL and the task has no subtasks:
   - Suggest running `taskmanager:expand <id>` to break it down.

4. **If task has subtasks**: Consider whether new subtasks are needed:
   - Generate additional subtasks to cover the expanded scope.
   - Insert them with appropriate IDs (next available under the parent).
   - Update parent estimate as sum of children.

### 4. Scope Down

When direction is `down` (simplifying, reducing scope):

1. **AI-assisted scope reduction**: Use the `taskmanager` skill to:
   - Analyze the current task `description`, `details`, and `test_strategy`.
   - Apply the scope change description to simplify the task.
   - Generate updated `description`, `details`, `test_strategy`.
   - Re-assess `complexity_score` and `complexity_scale` (should stay the same or decrease).
   - Re-estimate `estimate_seconds` (should stay the same or decrease).

2. **Update the task**:
   ```sql
   UPDATE tasks SET
       description = '<updated-description>',
       details = '<updated-details>',
       test_strategy = '<updated-test-strategy>',
       complexity_score = <new-score>,
       complexity_scale = '<new-scale>',
       complexity_reasoning = '<updated-reasoning>',
       estimate_seconds = <new-estimate>,
       updated_at = datetime('now')
   WHERE id = '<task-id>';
   ```

3. **If task has subtasks**: Consider whether some subtasks are now unnecessary:
   - Identify subtasks that no longer apply.
   - Ask the user which subtasks to cancel:
     - Option: "Cancel subtask X (no longer needed)"
     - Option: "Keep subtask X (still relevant)"
   - Cancel selected subtasks:
     ```sql
     UPDATE tasks SET
         status = 'canceled',
         updated_at = datetime('now')
     WHERE id IN (<canceled-subtask-ids>);
     ```
   - Update parent estimate as sum of remaining active children.

### 5. Cascade to dependent tasks (if `--cascade`)

If `--cascade` is specified:

1. **Find dependent tasks** (tasks that depend on the modified task):
   ```sql
   SELECT id, title, description, details, dependencies
   FROM tasks
   WHERE archived_at IS NULL
     AND status NOT IN ('done', 'canceled', 'duplicate')
     AND EXISTS (
         SELECT 1 FROM json_each(tasks.dependencies) d
         WHERE d.value = '<task-id>'
     );
   ```

2. **For each dependent task**:
   - Use the `taskmanager` skill to analyze how the scope change affects this task.
   - Generate updated `description` and `details` if the scope change is relevant.
   - Re-assess complexity and estimates if affected.
   - Update the dependent task.
   - Log each cascade update to `decisions.log`.

3. **Recursive cascade**: If a dependent task was updated and has its own dependents, cascade to those as well (up to 3 levels deep to prevent infinite cascades).

### 6. Update parent estimates

After all modifications, recompute parent estimates:

```sql
-- Recompute parent estimate
UPDATE tasks SET
    estimate_seconds = (
        SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
        FROM tasks c WHERE c.parent_id = tasks.id
          AND c.status NOT IN ('canceled', 'duplicate')
    ),
    updated_at = datetime('now')
WHERE id = (SELECT parent_id FROM tasks WHERE id = '<task-id>');
```

### 7. Summarize for the user

Report:
- The scope change applied.
- Updated complexity and estimate.
- If cascade was used: which dependent tasks were updated.
- Suggestions for next steps (e.g., expand, execute).

### 8. Cleanup logging session

1. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Completed scope <up|down> for task <id>. Complexity: <old> -> <new>. Cascade: <N tasks updated>
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
- Database errors
- Cascade failures

**To decisions.log** (ALWAYS):
- Command start and completion
- Scope changes with before/after complexity
- Each cascade update
- Subtask additions or cancellations

**To debug.log** (ONLY when `--debug` enabled):
- Detailed argument parsing
- AI analysis reasoning
- SQL queries being executed
- Cascade chain details

---

## Usage Examples

```bash
# Increase scope of a task
taskmanager:scope up 1.2 "Also handle edge case for expired tokens"

# Decrease scope of a task
taskmanager:scope down 1.2 "Remove OAuth support, only use JWT"

# Scope up with cascade to dependent tasks
taskmanager:scope up 1.2 "Add rate limiting to the API" --cascade

# Scope down with debug logging
taskmanager:scope down 1.2 "Simplify to single database" --debug
```

---

## Related Commands

- `taskmanager:expand` - Break down tasks into subtasks
- `taskmanager:update-task` - Update task fields directly
- `taskmanager:get-task <id>` - View current task details
- `taskmanager:dependencies` - Validate dependencies after scope changes
