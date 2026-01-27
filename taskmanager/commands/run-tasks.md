---
allowed-tools: Skill(taskmanager), Skill(taskmanager-memory)
description: Autonomously execute multiple tasks in sequence with memory support and conflict resolution
argument-hint: "[max-tasks] [--memory \"global memory\"] [--task-memory \"temp memory\"] [--debug]"
---

# Run Tasks Command

You are implementing `taskmanager:run-tasks`.

## Arguments

- `$1` (optional): Maximum number of tasks to execute in this run (default: 3-5)
- `--memory "description"` or `-gm "description"`: Add a global memory (persists to memories table)
- `--task-memory "description"` or `-tm "description"`: Add a batch task memory (applies to all tasks in this run, reviewed at batch end)
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
       debug_enabled = CASE WHEN '<debug-flag>' = 'true' THEN 1 ELSE 0 END,
       mode = 'autonomous',
       started_at = datetime('now'),
       last_update = datetime('now')
   WHERE id = 1;
   ```
4. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started run-tasks batch (max: $1 tasks)
   ```

### 1. Parse arguments and initialize

1. **Parse arguments**:
   - Extract max tasks from `$1` (default: 3-5 if not provided).
   - Extract `--memory` / `-gm` value if provided.
   - Extract `--task-memory` / `-tm` value if provided.
   - Extract `--debug` / `-d` flag if provided.

2. **Process memory arguments at batch start**:
   - If `--memory` is provided:
     - Use the `taskmanager-memory` skill to create a new global memory in the `memories` table.
     - Set `source_type = 'user'`, `source_via = 'run-tasks'`.
     - Set reasonable defaults: `importance = 3`, `confidence = 0.9`, `status = 'active'`.
   - If `--task-memory` is provided:
     - Update state table to add to task_memory JSON array with `taskId = "*"` (applies to all tasks in batch):
       ```sql
       UPDATE state SET
           task_memory = json_insert(
               task_memory,
               '$[#]',
               json_object(
                   'content', '<the description>',
                   'addedAt', datetime('now'),
                   'taskId', '*',
                   'source', 'user'
               )
           ),
           last_update = datetime('now')
       WHERE id = 1;
       ```

3. **Initialize deferred data** (track in memory during execution):
   - `deferredConflicts = []` (conflicts to present at batch end).
   - `executedTasks = []` (track what was executed).

### 2. Task iteration loop

For each iteration up to the limit:

#### 2.1 Find next task (SQL Query)

Query the next available task using the same logic as `next-task`:

```bash
TASK=$(sqlite3 -json .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    t.id,
    t.parent_id,
    t.title,
    t.description,
    t.details,
    t.test_strategy,
    t.status,
    t.type,
    t.priority,
    t.complexity_score,
    t.complexity_scale,
    t.tags,
    t.dependencies,
    t.owner
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
" | jq '.[0]')
```

- If `TASK` is empty or null:
  - No more tasks available, proceed to batch summary.

#### 2.2 Load and apply memories (PRE-EXECUTION)

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
    AND (json_extract(json_each.value, '$.taskId') = '<task-id>'
         OR json_extract(json_each.value, '$.taskId') = '*');
  ```
- **Run conflict detection** on all loaded memories:
  - **Critical conflicts** (importance >= 4):
    - Pause execution.
    - Present conflict to user.
    - Wait for resolution before continuing.
  - **Warning/Info conflicts** (importance < 4):
    - Add to `deferredConflicts[]`.
    - Continue execution.
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

#### 2.3 Start execution

- Update the task status to `"in-progress"`:
  ```sql
  UPDATE tasks SET
      status = 'in-progress',
      started_at = COALESCE(started_at, datetime('now')),
      updated_at = datetime('now')
  WHERE id = '<task-id>';
  ```
- Update state table:
  ```sql
  UPDATE state SET
      current_task_id = '<task-id>',
      current_subtask_path = '<task-id>',
      current_step = 'execution',
      mode = 'autonomous',
      last_update = datetime('now')
  WHERE id = 1;
  ```
- **Propagate in-progress status to ancestors** using recursive CTE:
  ```sql
  WITH RECURSIVE ancestors AS (
      SELECT parent_id as id
      FROM tasks
      WHERE id = '<task-id>' AND parent_id IS NOT NULL
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

#### 2.4 Execute the task

- Perform the necessary edits, file operations, or code changes as implied by the task description.
- Apply loaded memories as constraints during implementation.

#### 2.5 Post-execution memory review

- **Run conflict detection again** on all applied memories.
- **Critical conflicts**: Pause and resolve.
- **Warning/Info conflicts**: Add to `deferredConflicts[]`.
- **Review task-specific memories** (NOT `"*"` memories):
  - Query task memories for this specific task:
    ```sql
    SELECT json_each.value as memory FROM state, json_each(state.task_memory)
    WHERE state.id = 1
      AND json_extract(json_each.value, '$.taskId') = '<task-id>';
    ```
  - If any task memories exist:
    - Ask the user: "Should any task memories be promoted to global memory?"
    - Create global memories for promoted items (insert into `memories` table).
    - Clear those specific task memories:
      ```sql
      UPDATE state SET
          task_memory = (
              SELECT json_group_array(json_each.value)
              FROM state s, json_each(s.task_memory)
              WHERE s.id = 1
                AND json_extract(json_each.value, '$.taskId') != '<task-id>'
          ),
          last_update = datetime('now')
      WHERE id = 1;
      ```
- Clear applied memories from state:
  ```sql
  UPDATE state SET
      applied_memories = '[]',
      last_update = datetime('now')
  WHERE id = 1;
  ```

#### 2.6 Complete task with status propagation

- Update the leaf task status based on outcome and propagate to all ancestors.
- Use this single transaction for atomic status propagation:

  ```sql
  -- Update the leaf task
  UPDATE tasks SET
      status = '<final-status>',  -- 'done', 'blocked', 'paused', or 'needs-review'
      completed_at = CASE WHEN '<final-status>' = 'done' THEN datetime('now') ELSE completed_at END,
      updated_at = datetime('now')
  WHERE id = '<task-id>';

  -- Propagate status to all ancestors using recursive CTE
  WITH RECURSIVE ancestors AS (
      SELECT parent_id as id
      FROM tasks
      WHERE id = '<task-id>' AND parent_id IS NOT NULL
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
  WHERE id = '<task-id>';

  -- Archive parent if all children are now archived
  UPDATE tasks SET
      archived_at = datetime('now'),
      updated_at = datetime('now')
  WHERE id = (SELECT parent_id FROM tasks WHERE id = '<task-id>')
    AND NOT EXISTS (
        SELECT 1 FROM tasks c
        WHERE c.parent_id = (SELECT parent_id FROM tasks WHERE id = '<task-id>')
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

- Add task to `executedTasks[]` (in-memory tracking).

### 3. Batch completion

After finishing or reaching the limit:

1. **Review batch task memories** (where `taskId == "*"`):
   - Query batch memories:
     ```sql
     SELECT json_each.value as memory FROM state, json_each(state.task_memory)
     WHERE state.id = 1
       AND json_extract(json_each.value, '$.taskId') = '*';
     ```
   - If any `"*"` task memories exist:
     - Ask the user: "These memories were applied to all tasks in this batch. Should any be promoted to global memory?"
     - For each: "Promote to global memory" or "Discard".
     - Create global memories for promoted items (insert into `memories` table).
   - Clear all `"*"` task memories from state:
     ```sql
     UPDATE state SET
         task_memory = (
             SELECT COALESCE(json_group_array(json_each.value), '[]')
             FROM state s, json_each(s.task_memory)
             WHERE s.id = 1
               AND json_extract(json_each.value, '$.taskId') != '*'
         ),
         last_update = datetime('now')
     WHERE id = 1;
     ```

2. **Present deferred conflicts** (if any):
   - Show summary of all warning/info conflicts encountered during the batch.
   - For each conflict, ask user how to resolve.

3. **Summarize with SQL aggregates**:
   - Query task statistics:
     ```sql
     SELECT
         COUNT(*) FILTER (WHERE status = 'done') as completed,
         COUNT(*) FILTER (WHERE status NOT IN ('done', 'canceled', 'duplicate') AND archived_at IS NULL) as remaining,
         COUNT(*) FILTER (WHERE status = 'blocked') as blocked,
         COUNT(*) FILTER (WHERE status = 'in-progress') as in_progress
     FROM tasks;
     ```
   - Display:
     - Which tasks were executed (IDs + titles from `executedTasks[]`).
     - Memories that were applied.
     - Any tasks that were skipped due to dependencies.
     - Any conflicts that were resolved or deferred.
     - The new high-level state (e.g. number of tasks done vs remaining).

4. **Cleanup logging session**:
   - Log to `decisions.log`:
     ```
     <timestamp> [DECISION] [<session-id>] Completed run-tasks batch: N tasks executed, M remaining
     ```
   - Reset state table:
     ```sql
     UPDATE state SET
         mode = 'interactive',
         debug_enabled = 0,
         session_id = NULL,
         started_at = NULL,
         last_update = datetime('now')
     WHERE id = 1;
     ```

---

## Logging Requirements

Throughout batch execution, this command MUST log:

**To errors.log** (ALWAYS):
- Any errors encountered during task execution
- Conflict detection results when conflicts are found
- Dependency resolution failures

**To decisions.log** (ALWAYS):
- Batch start and completion
- Each task start and completion
- Memory application per task
- Conflict resolutions
- Memory promotions

**To debug.log** (ONLY when `--debug` enabled):
- Task selection algorithm details
- Memory matching per task
- Conflict detection steps
- Full batch state at start/end
- SQL queries being executed

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
    WHERE id = '<task-id>' AND parent_id IS NOT NULL
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

- `taskmanager:next-task` - Find the next available task (uses same selection query)
- `taskmanager:execute-task <id>` - Execute a single task with full workflow
- `taskmanager:get-task <id> [key]` - Token-efficient way to retrieve task properties
- `taskmanager:update-status <status> <id1> [id2...]` - Batch status updates without propagation
- `taskmanager:stats` - Token-efficient statistics via SQL aggregates
- `taskmanager:dashboard` - Full progress overview

**Note:** This command uses the same task selection logic as `next-task` and the same status propagation as `execute-task`, ensuring consistency across the taskmanager plugin.
