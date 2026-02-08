---
allowed-tools: Bash
description: Validate and auto-fix task dependencies - detect circular, missing, and archived references
argument-hint: "<--validate | --fix | --add <from> <to> | --remove <from> <to>> [--debug]"
---

# Dependencies Command

You are implementing `taskmanager:dependencies`.

## Purpose

Validate the integrity of task dependencies across the project and optionally auto-fix issues. Also provides commands to add and remove individual dependencies with validation.

## Arguments

- `--validate`: Report all invalid dependencies without making changes
- `--fix`: Auto-remove invalid references and break cycles
- `--add <from-id> <to-id>`: Add a dependency (task `<from-id>` depends on `<to-id>`)
- `--remove <from-id> <to-id>`: Remove a dependency
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

### --validate — Report invalid dependencies

Run all validation checks and report findings:

#### 1. Missing references (dependencies pointing to non-existent tasks)

```sql
SELECT t.id as task_id, d.value as missing_dep
FROM tasks t, json_each(t.dependencies) d
WHERE t.archived_at IS NULL
  AND d.value NOT IN (SELECT id FROM tasks);
```

#### 2. Archived references (dependencies pointing to archived but non-terminal tasks)

```sql
SELECT t.id as task_id, d.value as archived_dep
FROM tasks t, json_each(t.dependencies) d
WHERE t.archived_at IS NULL
  AND d.value IN (
      SELECT id FROM tasks
      WHERE archived_at IS NOT NULL
        AND status NOT IN ('done', 'canceled', 'duplicate')
  );
```

#### 3. Self-references (task depends on itself)

```sql
SELECT t.id as task_id
FROM tasks t, json_each(t.dependencies) d
WHERE d.value = t.id;
```

#### 4. Circular dependencies (A depends on B, B depends on A, etc.)

Use a recursive CTE to detect cycles:

```sql
WITH RECURSIVE dep_chain AS (
    -- Start from each task
    SELECT
        t.id as start_id,
        d.value as current_id,
        t.id || ' -> ' || d.value as path,
        1 as depth
    FROM tasks t, json_each(t.dependencies) d
    WHERE t.archived_at IS NULL

    UNION ALL

    -- Follow dependency chains
    SELECT
        dc.start_id,
        d.value as current_id,
        dc.path || ' -> ' || d.value,
        dc.depth + 1
    FROM dep_chain dc
    JOIN tasks t ON t.id = dc.current_id
    JOIN json_each(t.dependencies) d
    WHERE dc.depth < 20  -- Safety limit
      AND d.value != dc.current_id  -- Avoid immediate self-loops (caught above)
)
SELECT DISTINCT start_id, path || ' -> ' || start_id as cycle
FROM dep_chain
WHERE current_id = start_id;
```

#### 5. Report summary

```
=== Dependency Validation Report ===

Missing references: N
  - Task 1.2 depends on 3.5 (not found)
  - Task 2.1 depends on 9.9 (not found)

Archived references: N
  - Task 1.3 depends on 1.1 (archived, status: paused)

Self-references: N
  - Task 2.2 depends on itself

Circular dependencies: N
  - 1.2 -> 1.3 -> 1.2

Total issues: N
```

### --fix — Auto-remove invalid dependencies

1. Run the same validation checks as `--validate`.
2. For each issue found:

**Missing references**: Remove from dependencies array:
```sql
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(dependencies) d
        WHERE d.value IN (SELECT id FROM tasks)
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.dependencies) d
    WHERE d.value NOT IN (SELECT id FROM tasks)
);
```

**Self-references**: Remove self from dependencies:
```sql
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(dependencies) d
        WHERE d.value != id
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.dependencies) d
    WHERE d.value = t.id
);
```

**Circular dependencies**: Break cycle by removing the dependency on the task with the highest ID in the cycle:
- For cycle `A -> B -> C -> A`, remove C's dependency on A.
- Log the decision with reasoning.

**Archived references (non-terminal)**: Remove references to archived non-terminal tasks:
```sql
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(dependencies) d
        WHERE d.value NOT IN (
            SELECT id FROM tasks
            WHERE archived_at IS NOT NULL
              AND status NOT IN ('done', 'canceled', 'duplicate')
        )
    ),
    updated_at = datetime('now')
WHERE archived_at IS NULL
  AND EXISTS (
      SELECT 1 FROM json_each(dependencies) d
      WHERE d.value IN (
          SELECT id FROM tasks
          WHERE archived_at IS NOT NULL
            AND status NOT IN ('done', 'canceled', 'duplicate')
      )
  );
```

3. Report what was fixed:
```
=== Dependency Fix Report ===

Fixed missing references: N
  - Removed 3.5 from task 1.2 dependencies
  - Removed 9.9 from task 2.1 dependencies

Fixed self-references: N
  - Removed self-reference from task 2.2

Broke circular dependencies: N
  - Removed 1.2 from task 1.3 dependencies (broke cycle: 1.2 -> 1.3 -> 1.2)

Removed archived references: N
  - Removed 1.1 from task 1.3 dependencies (archived, non-terminal)

Total fixes: N
```

### --add — Add a dependency

1. Validate both task IDs exist:
   ```sql
   SELECT id FROM tasks WHERE id IN ('<from-id>', '<to-id>') AND archived_at IS NULL;
   ```

2. Check for circular dependency (adding this dependency would create a cycle):
   ```sql
   WITH RECURSIVE dep_chain AS (
       SELECT d.value as dep_id, 1 as depth
       FROM tasks t, json_each(t.dependencies) d
       WHERE t.id = '<to-id>'
       UNION ALL
       SELECT d.value, dc.depth + 1
       FROM dep_chain dc
       JOIN tasks t ON t.id = dc.dep_id
       JOIN json_each(t.dependencies) d
       WHERE dc.depth < 20
   )
   SELECT COUNT(*) FROM dep_chain WHERE dep_id = '<from-id>';
   ```

   If count > 0, warn: "Adding this dependency would create a circular reference." and stop.

3. Check if dependency already exists:
   ```sql
   SELECT COUNT(*) FROM tasks t, json_each(t.dependencies) d
   WHERE t.id = '<from-id>' AND d.value = '<to-id>';
   ```

4. Add the dependency:
   ```sql
   UPDATE tasks SET
       dependencies = json_insert(dependencies, '$[#]', '<to-id>'),
       updated_at = datetime('now')
   WHERE id = '<from-id>';
   ```

5. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Added dependency: <from-id> depends on <to-id>
   ```

### --remove — Remove a dependency

1. Validate the from-task exists.

2. Remove the dependency:
   ```sql
   UPDATE tasks SET
       dependencies = (
           SELECT COALESCE(json_group_array(d.value), '[]')
           FROM json_each(dependencies) d
           WHERE d.value != '<to-id>'
       ),
       updated_at = datetime('now')
   WHERE id = '<from-id>';
   ```

3. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Removed dependency: <from-id> no longer depends on <to-id>
   ```

### Cleanup logging session

1. Log completion to `decisions.log`.
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
- Invalid task IDs
- Circular dependency detection
- Database errors

**To decisions.log** (ALWAYS):
- Validation results summary
- Each fix applied
- Dependencies added or removed

**To debug.log** (ONLY when `--debug` enabled):
- SQL queries executed
- Cycle detection algorithm steps
- Full dependency graph

---

## Usage Examples

```bash
# Validate all dependencies
taskmanager:dependencies --validate

# Auto-fix invalid dependencies
taskmanager:dependencies --fix

# Add a dependency (task 1.3 depends on task 1.2)
taskmanager:dependencies --add 1.3 1.2

# Remove a dependency
taskmanager:dependencies --remove 1.3 1.2

# Validate with debug output
taskmanager:dependencies --validate --debug
```

---

## Related Commands

- `taskmanager:get-task <id>` - View task dependencies
- `taskmanager:scope` - Scope changes may affect dependencies
- `taskmanager:move` - Moving tasks updates dependency references
- `taskmanager:expand` - Expanding tasks may create new dependencies
