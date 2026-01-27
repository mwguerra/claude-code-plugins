---
allowed-tools: Skill(taskmanager), Skill(taskmanager-memory)
description: Execute a single task by ID with dependency resolution, memory application, and status propagation
argument-hint: "<task-id> [--memory \"global memory\"] [--task-memory \"temp memory\"] [--debug]"
---

# Execute Task Command

You are implementing `taskmanager:execute-task`.

## Arguments

- `$1` (required): Task ID to execute (e.g., `1.2.3`)
- `--memory "description"` or `-gm "description"`: Add a global memory (persists to memories table)
- `--task-memory "description"` or `-tm "description"`: Add a task-scoped memory (temporary, reviewed at task end)
- `--debug` or `-d`: Enable verbose debug logging

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID using timestamp: `sess-$(date +%Y%m%d%H%M%S)` (e.g., `sess-20251212103045`).
2. Check for `--debug` / `-d` flag.
3. Update state table:
   ```sql
   UPDATE state SET
       session_id = '<session-id>',
       debug_enabled = 1,  -- or 0 if no --debug flag
       last_update = datetime('now')
   WHERE id = 1;
   ```
4. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started execute-task command for task $1
   ```

### 1. Parse arguments

- `$1` must be provided (e.g., `1.2.3`).
- If not provided, ask the user to specify an ID or suggest running `taskmanager:next-task`.
- Extract `--memory` / `-gm` value if provided.
- Extract `--task-memory` / `-tm` value if provided.
- Extract `--debug` / `-d` flag if provided.

2. **Process memory arguments**:
   - If `--memory` is provided:
     - Use the `taskmanager-memory` skill to create a new global memory in the `memories` table.
     - Set `source_type = 'user'`, `source_via = 'execute-task'`.
     - Set reasonable defaults: `importance = 3`, `confidence = 0.9`, `status = 'active'`.
   - If `--task-memory` is provided:
     - Update state table to add to task_memory JSON array:
       ```sql
       UPDATE state SET
           task_memory = json_insert(
               task_memory,
               '$[#]',
               json_object(
                   'content', '<the description>',
                   'addedAt', datetime('now'),
                   'taskId', '<task-id>',
                   'source', 'user'
               )
           ),
           last_update = datetime('now')
       WHERE id = 1;
       ```

3. **Load task via SQL**:
   ```bash
   TASK=$(sqlite3 -json .taskmanager/taskmanager.db "
       SELECT id, parent_id, title, description, details, test_strategy,
              status, type, priority, complexity_score, complexity_scale,
              tags, dependencies, owner, created_at, updated_at
       FROM tasks
       WHERE id = '$TASK_ID' AND archived_at IS NULL;
   " | jq '.[0]')
   ```
   - If result is empty or null, inform the user and stop.
   - Parse the JSON result to extract task properties.

4. **Check dependencies via SQL**:
   ```bash
   UNMET_DEPS=$(sqlite3 .taskmanager/taskmanager.db "
       SELECT d.value
       FROM tasks t, json_each(t.dependencies) d
       WHERE t.id = '$TASK_ID'
         AND d.value NOT IN (
             SELECT id FROM tasks
             WHERE status IN ('done', 'canceled', 'duplicate')
         );
   ")
   ```
   - If `UNMET_DEPS` is not empty:
     - Use the AskUserQuestion tool to ask how to proceed, with options such as:
       - "Execute a dependency task first"
       - "Mark dependencies as done and continue"
       - "Abort execution of this task"
     - Act according to the user's answer.

5. **Load and apply memories** (PRE-EXECUTION):
   - Use the `taskmanager-memory` skill to query relevant memories for this task.
   - Load global memories from `memories` table:
     ```sql
     SELECT * FROM memories
     WHERE status = 'active'
       AND importance >= 3
     ORDER BY importance DESC, last_used_at DESC;
     ```
   - Load task-scoped memories from state table:
     ```sql
     SELECT json_each.value FROM state, json_each(state.task_memory)
     WHERE state.id = 1
       AND (json_extract(json_each.value, '$.taskId') = '$TASK_ID'
            OR json_extract(json_each.value, '$.taskId') = '*');
     ```
   - **Run conflict detection** on all loaded memories:
     - Check for file/pattern obsolescence.
     - Check for implementation divergence.
     - If conflicts detected, resolve using the conflict resolution workflow.
   - Display summary of applicable memories.
   - Store applied memory IDs in state:
     ```sql
     UPDATE state SET
         applied_memories = json('<array-of-memory-ids>'),
         last_update = datetime('now')
     WHERE id = 1;
     ```
   - Increment `use_count` and update `last_used_at` for each applied memory:
     ```sql
     UPDATE memories SET
         use_count = use_count + 1,
         last_used_at = datetime('now')
     WHERE id IN (<applied-memory-ids>);
     ```

6. **Start execution**:
   - Update the task status to `"in-progress"`:
     ```sql
     UPDATE tasks SET
         status = 'in-progress',
         started_at = COALESCE(started_at, datetime('now')),
         updated_at = datetime('now')
     WHERE id = '$TASK_ID';
     ```
   - Update state table:
     ```sql
     UPDATE state SET
         current_task_id = '$TASK_ID',
         current_subtask_path = '$TASK_ID',
         current_step = 'execution',
         mode = 'interactive',
         started_at = datetime('now'),
         last_update = datetime('now')
     WHERE id = 1;
     ```
   - **Propagate in-progress status to ancestors** using recursive CTE:
     ```sql
     WITH RECURSIVE ancestors AS (
         SELECT parent_id as id
         FROM tasks
         WHERE id = '$TASK_ID' AND parent_id IS NOT NULL
         UNION ALL
         SELECT t.parent_id
         FROM tasks t
         JOIN ancestors a ON t.id = a.id
         WHERE t.parent_id IS NOT NULL
     )
     UPDATE tasks SET
         status = 'in-progress',
         updated_at = datetime('now')
     WHERE id IN (SELECT id FROM ancestors);
     ```

7. **Execute the task**:
   - Perform the code changes, file edits, or other work implied by the task.
   - Apply loaded memories as constraints during implementation.

8. **Post-execution memory review** (before marking done):
   - **Run conflict detection again** on all applied memories.
   - If conflicts detected, resolve using the conflict resolution workflow.
   - **Review task-scoped memories**:
     - Query task memories for this task:
       ```sql
       SELECT json_each.value as memory FROM state, json_each(state.task_memory)
       WHERE state.id = 1
         AND json_extract(json_each.value, '$.taskId') = '$TASK_ID';
       ```
     - If any task memories exist:
       - Ask the user: "Should any task memories be promoted to global memory?"
       - For each: "Promote to global memory" or "Discard".
       - Create global memories for promoted items (insert into `memories` table).
       - Clear task memories for this task:
         ```sql
         UPDATE state SET
             task_memory = (
                 SELECT json_group_array(json_each.value)
                 FROM state s, json_each(s.task_memory)
                 WHERE s.id = 1
                   AND json_extract(json_each.value, '$.taskId') != '$TASK_ID'
             ),
             applied_memories = '[]',
             last_update = datetime('now')
         WHERE id = 1;
         ```

9. **Complete execution with status propagation**:
   - Update the leaf task status based on outcome and propagate to all ancestors.
   - Use this single transaction for atomic status propagation:

   ```sql
   -- Update the leaf task
   UPDATE tasks SET
       status = '<final-status>',  -- 'done', 'blocked', 'paused', or 'needs-review'
       completed_at = CASE WHEN '<final-status>' = 'done' THEN datetime('now') ELSE completed_at END,
       updated_at = datetime('now')
   WHERE id = '$TASK_ID';

   -- Propagate status to all ancestors using recursive CTE
   WITH RECURSIVE ancestors AS (
       SELECT parent_id as id
       FROM tasks
       WHERE id = '$TASK_ID' AND parent_id IS NOT NULL
       UNION ALL
       SELECT t.parent_id
       FROM tasks t
       JOIN ancestors a ON t.id = a.id
       WHERE t.parent_id IS NOT NULL
   )
   UPDATE tasks SET
       status = (
           SELECT CASE
               WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress')
                   THEN 'in-progress'
               WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked')
                   THEN 'blocked'
               WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review')
                   THEN 'needs-review'
               WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned', 'draft', 'paused'))
                   THEN 'planned'
               WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done')
                   THEN 'done'
               ELSE 'canceled'
           END
       ),
       completed_at = CASE
           WHEN NOT EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status NOT IN ('done', 'canceled', 'duplicate'))
           THEN datetime('now')
           ELSE completed_at
       END,
       updated_at = datetime('now')
   WHERE id IN (SELECT id FROM ancestors);
   ```

   - **Archive if terminal status**: If the final status is `"done"`, `"canceled"`, or `"duplicate"`:
     ```sql
     -- Archive the completed task
     UPDATE tasks SET
         archived_at = datetime('now'),
         updated_at = datetime('now')
     WHERE id = '$TASK_ID';

     -- Archive parent if all children are now archived
     UPDATE tasks SET
         archived_at = datetime('now'),
         updated_at = datetime('now')
     WHERE id = (SELECT parent_id FROM tasks WHERE id = '$TASK_ID')
       AND NOT EXISTS (
           SELECT 1 FROM tasks c
           WHERE c.parent_id = (SELECT parent_id FROM tasks WHERE id = '$TASK_ID')
             AND c.archived_at IS NULL
       );
     ```

   - Update state table to clear current task:
     ```sql
     UPDATE state SET
         current_task_id = NULL,
         current_subtask_path = NULL,
         current_step = 'idle',
         last_update = datetime('now')
     WHERE id = 1;
     ```

### 10. Summarize for the user

- Final status of the task.
- Memories that were applied and any conflicts resolved.
- Any follow-up tasks or dependencies suggested.
- Query remaining work:
  ```sql
  SELECT COUNT(*) as remaining FROM tasks
  WHERE archived_at IS NULL
    AND status NOT IN ('done', 'canceled', 'duplicate');
  ```

### 11. Cleanup logging session

1. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Completed execute-task command for task $1 with status "<final-status>"
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
- Any errors encountered (database errors, validation failures)
- Conflict detection results when conflicts are found

**To decisions.log** (ALWAYS):
- Command start and completion
- Task status transitions
- Memory application and conflict resolutions
- Any user decisions made

**To debug.log** (ONLY when `--debug` enabled):
- Detailed argument parsing
- SQL queries being executed
- Memory matching algorithm steps
- Conflict detection intermediate steps

---

## Status Propagation Helper (Recursive CTE)

Whenever this command changes the status of any **leaf** task, it MUST also update the status of all its **ancestor** tasks using a single recursive CTE query.

### Propagation Rules (applied per parent, based on direct children):

1. If **any** child is `"in-progress"` -> parent `status = "in-progress"`
2. Else if **any** child is `"blocked"` -> parent `status = "blocked"`
3. Else if **any** child is `"needs-review"` -> parent `status = "needs-review"`
4. Else if **any** child is in `"planned"`, `"draft"`, `"paused"` -> parent `status = "planned"`
5. Else if **all** children are in `{"done", "canceled", "duplicate"}`:
   - If at least one child is `"done"` -> parent `status = "done"`
   - Else -> parent `status = "canceled"`

### Complete Propagation Query

```sql
-- First, get all ancestors
WITH RECURSIVE ancestors AS (
    SELECT parent_id as id
    FROM tasks
    WHERE id = '$TASK_ID' AND parent_id IS NOT NULL
    UNION ALL
    SELECT t.parent_id
    FROM tasks t
    JOIN ancestors a ON t.id = a.id
    WHERE t.parent_id IS NOT NULL
)
-- Then update each ancestor based on its children's statuses
UPDATE tasks SET
    status = (
        SELECT CASE
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress')
                THEN 'in-progress'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked')
                THEN 'blocked'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review')
                THEN 'needs-review'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned', 'draft', 'paused'))
                THEN 'planned'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done')
                THEN 'done'
            ELSE 'canceled'
        END
    ),
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors);
```

**Key advantages of SQL propagation:**
- **Atomic**: All updates happen in a single transaction
- **Efficient**: Single query instead of iterative JSON manipulation
- **Consistent**: Database ensures integrity via foreign keys

---

## Related Commands

- `taskmanager:get-task <id> [key]` - Token-efficient way to retrieve task properties
- `taskmanager:update-status <status> <id1> [id2...]` - Batch status updates without propagation
- `taskmanager:stats` - Token-efficient statistics via SQL aggregates

**Note:** Unlike `taskmanager:update-status`, this command (`execute-task`) performs full status propagation to parent tasks. Use `execute-task` when you need proper status cascading; use `update-status` only for quick batch updates where you'll handle propagation separately.
