---
allowed-tools: Skill(taskmanager), Bash
description: Expand a task or all tasks above a complexity threshold into subtasks
argument-hint: "<task-id> | --all [--threshold <XS|S|M|L|XL>] [--debug]"
---

# Expand Command

You are implementing `taskmanager:expand`.

## Purpose

Expand an existing task into subtasks after initial planning. This enables progressive elaboration -- breaking down tasks into smaller pieces as understanding grows, without needing to re-plan the entire project.

## Arguments

- `$1` (optional): Task ID to expand (e.g., `1.2.3`)
- `--all`: Expand all eligible tasks (those at or above the complexity threshold)
- `--threshold <scale>`: Minimum complexity scale for `--all` mode (default: `M`). One of: `XS`, `S`, `M`, `L`, `XL`
- `--force`: Re-expand tasks that already have subtasks
- `--debug` or `-d`: Enable verbose debug logging

If neither `$1` nor `--all` is provided, ask the user which task to expand.

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID using timestamp: `sess-$(date +%Y%m%d%H%M%S)`.
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
   <timestamp> [DECISION] [<session-id>] Started expand command
   ```

### 1. Parse arguments

- Determine mode: single task expansion (`$1`) or bulk expansion (`--all`).
- Extract `--threshold` value if provided (default: `M`).
- Extract `--force` flag if provided.
- Extract `--debug` / `-d` flag if provided.

### 2. Find tasks to expand

#### Single task mode (`expand <id>`):

```sql
SELECT id, title, description, details, test_strategy, complexity_score, complexity_scale,
       complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies
FROM tasks
WHERE id = '<task-id>'
  AND archived_at IS NULL;
```

Validation:
- If the task doesn't exist, inform the user and stop.
- If the task already has subtasks and `--force` is not set:
  - Inform the user: "Task <id> already has subtasks. Use --force to re-expand."
  - Stop.
- If the task already has subtasks and `--force` IS set:
  - Warn the user that existing subtasks will be replaced.
  - Delete existing subtasks (cascade):
    ```sql
    DELETE FROM tasks WHERE parent_id = '<task-id>';
    ```

#### Bulk mode (`expand --all`):

Map the threshold to a numeric score:
```
XS = 0, S = 1, M = 2, L = 3, XL = 4
```

```sql
SELECT id, title, description, details, test_strategy, complexity_score, complexity_scale,
       complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND complexity_score >= <threshold_score>
  AND NOT EXISTS (
      SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id
  )
ORDER BY complexity_score DESC,
  CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
  id;
```

If no tasks match, inform the user and stop.

### 3. Expand each task

For each task to expand:

1. **Check for expansion prompt**: If the task has a `complexity_expansion_prompt`, use it as guidance for the expansion. This field was set during planning to provide specific instructions on how to break down this task.

2. **Generate subtasks using the taskmanager skill**:
   - Call the `taskmanager` skill with instructions to:
     - Read the task's `description`, `details`, `test_strategy`, and `complexity_expansion_prompt`.
     - Generate subtasks following the same rules as planning (see SKILL.md section 5: Level-by-Level Task Generation).
     - Each subtask must have: `id`, `title`, `description`, `details`, `test_strategy`, `status`, `type`, `priority`, `complexity_score`, `complexity_scale`, `estimate_seconds`, `tags`, `dependencies`.
     - Subtask IDs follow the parent's ID pattern (e.g., parent `1.2` gets children `1.2.1`, `1.2.2`, etc.).
     - Dependencies between subtasks should be expressed as full dotted IDs.
     - Subtasks inherit the parent's `type` and `tags` unless there's a reason to differ.

3. **Insert subtasks via SQL transaction**:
   ```sql
   BEGIN TRANSACTION;

   -- Insert subtasks
   INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority,
                      complexity_score, complexity_scale, complexity_reasoning, estimate_seconds,
                      tags, dependencies)
   VALUES ('<parent-id>.1', '<parent-id>', 'Subtask title', 'Description', 'Details',
           'Test strategy', 'planned', 'feature', 'medium', 2, 'S', 'Reasoning', 3600,
           '[]', '[]');
   -- ... more subtasks ...

   -- Update parent estimate_seconds as sum of children
   UPDATE tasks SET
       estimate_seconds = (
           SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
           FROM tasks c WHERE c.parent_id = '<parent-id>'
       ),
       updated_at = datetime('now')
   WHERE id = '<parent-id>';

   COMMIT;
   ```

4. **Log the expansion**:
   ```
   <timestamp> [DECISION] [<session-id>] Expanded task <id> into N subtasks
   ```

### 4. Recursive expansion check

After expanding, check if any newly created subtasks themselves need expansion:

```sql
SELECT id, title, complexity_score, complexity_scale
FROM tasks
WHERE parent_id = '<expanded-task-id>'
  AND complexity_score >= <threshold_score>
  AND NOT EXISTS (
      SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id
  );
```

If any subtasks are above the threshold:
- In single-task mode: Ask the user if they want to expand these subtasks too.
- In bulk mode: Automatically expand them (recursive until all leaves are below threshold).

### 5. Summarize for the user

Report:
- How many tasks were expanded.
- Total new subtasks created.
- Any tasks that were skipped (already had subtasks, below threshold).
- Query the updated task tree:
  ```sql
  SELECT id, title, complexity_scale, estimate_seconds
  FROM tasks
  WHERE (id = '<parent-id>' OR parent_id = '<parent-id>')
    AND archived_at IS NULL
  ORDER BY id;
  ```

### 6. Cleanup logging session

1. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Completed expand command: N tasks expanded, M subtasks created
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

Throughout execution, this command MUST log:

**To errors.log** (ALWAYS):
- Task not found errors
- Database errors
- Validation failures

**To decisions.log** (ALWAYS):
- Command start and completion
- Each task expansion with subtask count
- Any skipped tasks and reasons

**To debug.log** (ONLY when `--debug` enabled):
- Detailed argument parsing
- SQL queries being executed
- Expansion prompt details
- Subtask generation algorithm steps

---

## Usage Examples

```bash
# Expand a single task
taskmanager:expand 1.2

# Expand a task even if it already has subtasks
taskmanager:expand 1.2 --force

# Expand all tasks with complexity M or above
taskmanager:expand --all

# Expand all tasks with complexity L or above
taskmanager:expand --all --threshold L

# Expand all tasks with complexity S or above (more granular)
taskmanager:expand --all --threshold S

# With debug logging
taskmanager:expand 1.2 --debug
```

---

## Related Commands

- `taskmanager:plan` - Initial task generation from PRD (includes expansion during planning)
- `taskmanager:get-task <id>` - View task details before expanding
- `taskmanager:scope <id>` - Adjust task scope before or after expansion
- `taskmanager:dashboard` - View overall progress after expansion
