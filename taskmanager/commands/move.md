---
allowed-tools: Bash
description: Move a task to a different position or parent in the hierarchy
argument-hint: "<task-id> <--after <id> | --under <parent-id> | --before <id>> [--debug]"
---

# Move Command

You are implementing `taskmanager:move`.

## Purpose

Reorder tasks by moving them to a different position in the hierarchy or under a different parent. All dependent references are updated automatically.

## Arguments

- `$1` (required): Task ID to move
- `--after <id>`: Position the task immediately after the specified sibling
- `--before <id>`: Position the task immediately before the specified sibling
- `--under <parent-id>`: Reparent the task under a new parent
- `--debug` or `-d`: Enable verbose debug logging

Exactly one of `--after`, `--before`, or `--under` must be provided.

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Check for `--debug` / `-d` flag.
3. Update state table and log to `decisions.log`.

### 1. Parse and validate arguments

- `$1` must be a valid, non-archived task ID.
- Exactly one positioning flag must be provided.
- The target reference task must also exist and not be archived.

### 2. Load the task and its context

```sql
-- Get the task being moved
SELECT id, parent_id, title, status FROM tasks
WHERE id = '<task-id>' AND archived_at IS NULL;

-- Get its current siblings
SELECT id, title FROM tasks
WHERE parent_id = (SELECT parent_id FROM tasks WHERE id = '<task-id>')
  AND archived_at IS NULL
ORDER BY id;

-- Get its subtasks (will move with it)
SELECT id FROM tasks WHERE parent_id = '<task-id>';
```

### 3. Determine new position

#### --after / --before (reorder among siblings):

The target task must share the same parent as the moved task, OR
you can use `--under` in combination to reparent and position.

Since task IDs encode hierarchy (dotted notation), reordering requires:

1. Calculate the new ID for the moved task based on its position among siblings.
2. Assign new IDs to the moved task and all its descendants.

**ID recalculation:**
- If moving task `1.3` after `1.1` (within same parent `1`):
  - If `1.2` exists, we need to renumber. The task gets the appropriate sibling number.
  - Generate new IDs by examining gaps or shifting existing tasks.

#### --under (reparent):

1. Determine the next available child number under the new parent:
   ```sql
   SELECT COALESCE(
       MAX(CAST(SUBSTR(id, LENGTH('<new-parent-id>') + 2) AS INTEGER)),
       0
   ) + 1 as next_num
   FROM tasks
   WHERE parent_id = '<new-parent-id>';
   ```

2. The new ID becomes `<new-parent-id>.<next_num>`.

### 4. Validate no circular dependencies

Ensure the move doesn't create a cycle:
- A task cannot be moved under one of its own descendants.

```sql
WITH RECURSIVE descendants AS (
    SELECT id FROM tasks WHERE id = '<task-id>'
    UNION ALL
    SELECT t.id FROM tasks t JOIN descendants d ON t.parent_id = d.id
)
SELECT COUNT(*) FROM descendants WHERE id = '<new-parent-id>';
```

If count > 0, error: "Cannot move a task under its own descendant."

### 5. Execute the move

1. **Build the ID mapping** (old ID -> new ID) for the task and all descendants:
   ```sql
   WITH RECURSIVE subtree AS (
       SELECT id, '<new-id>' as new_id FROM tasks WHERE id = '<task-id>'
       UNION ALL
       SELECT t.id,
              '<new-id>' || SUBSTR(t.id, LENGTH('<task-id>') + 1) as new_id
       FROM tasks t JOIN subtree s ON t.parent_id = s.id
   )
   SELECT id as old_id, new_id FROM subtree;
   ```

2. **Create new task records** with updated IDs and parent references:
   ```sql
   BEGIN TRANSACTION;

   -- For each task in the subtree (process in reverse depth order to avoid FK issues):
   -- Insert with new ID
   INSERT INTO tasks (id, parent_id, title, description, details, test_strategy,
                      status, type, priority, complexity_score, complexity_scale,
                      complexity_reasoning, complexity_expansion_prompt,
                      estimate_seconds, duration_seconds, owner,
                      domain, writing_type, content_unit, writing_stage,
                      target_word_count, current_word_count,
                      created_at, updated_at, started_at, completed_at, archived_at,
                      tags, dependencies, dependency_analysis, meta)
   SELECT '<new-id>', '<new-parent-id>',
          title, description, details, test_strategy,
          status, type, priority, complexity_score, complexity_scale,
          complexity_reasoning, complexity_expansion_prompt,
          estimate_seconds, duration_seconds, owner,
          domain, writing_type, content_unit, writing_stage,
          target_word_count, current_word_count,
          created_at, datetime('now'), started_at, completed_at, archived_at,
          tags, '<updated-dependencies>', dependency_analysis, meta
   FROM tasks WHERE id = '<old-id>';

   COMMIT;
   ```

3. **Update dependency references** across ALL tasks:
   For every task in the database, update any dependency references that point to old IDs:
   ```sql
   -- For each old_id -> new_id mapping:
   UPDATE tasks SET
       dependencies = REPLACE(dependencies, '"<old-id>"', '"<new-id>"'),
       updated_at = datetime('now')
   WHERE dependencies LIKE '%"<old-id>"%';
   ```

4. **Delete old task records** (after all new records are created):
   ```sql
   DELETE FROM tasks WHERE id IN (<old-ids>);
   ```

5. **Update sync_log references** if any:
   ```sql
   UPDATE sync_log SET task_id = '<new-id>' WHERE task_id = '<old-id>';
   ```

6. **Recompute parent estimates** for both old and new parents:
   ```sql
   -- Old parent
   UPDATE tasks SET
       estimate_seconds = (
           SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
           FROM tasks c WHERE c.parent_id = tasks.id
       ),
       updated_at = datetime('now')
   WHERE id = '<old-parent-id>'
     AND EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = '<old-parent-id>');

   -- New parent
   UPDATE tasks SET
       estimate_seconds = (
           SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
           FROM tasks c WHERE c.parent_id = tasks.id
       ),
       updated_at = datetime('now')
   WHERE id = '<new-parent-id>'
     AND EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = '<new-parent-id>');
   ```

### 6. Summarize for the user

Report:
- Task moved: `<old-id>` -> `<new-id>`
- Subtasks moved: N tasks renumbered
- Dependencies updated: N references updated
- Old parent estimate recalculated
- New parent estimate recalculated

### 7. Cleanup logging session

Log to `decisions.log` and reset state table.

---

## Logging Requirements

**To errors.log** (ALWAYS):
- Invalid task IDs
- Circular move detection
- Database errors

**To decisions.log** (ALWAYS):
- Move operation with old/new IDs
- Dependency reference updates
- Estimate recalculations

**To debug.log** (ONLY when `--debug` enabled):
- Full ID mapping table
- SQL queries executed
- Dependency graph updates

---

## Usage Examples

```bash
# Move task 1.3 to be after 1.1 (reorder)
taskmanager:move 1.3 --after 1.1

# Move task 2.1 under a different parent
taskmanager:move 2.1 --under 3

# Move task 1.2.3 before 1.2.1
taskmanager:move 1.2.3 --before 1.2.1

# Move with debug logging
taskmanager:move 1.3 --under 2 --debug
```

---

## Important Notes

- Moving a task also moves ALL its subtasks (the entire subtree).
- All dependency references across the project are updated to reflect new IDs.
- The operation is atomic (wrapped in a transaction).
- This is a complex operation -- for simple reordering of execution priority, consider using `taskmanager:update-task --priority` instead.

---

## Related Commands

- `taskmanager:dependencies` - Validate dependencies after moving
- `taskmanager:get-task <id>` - View task details
- `taskmanager:dashboard` - View updated hierarchy
- `taskmanager:update-task` - Update task fields without moving
