---
allowed-tools: Skill(taskmanager), Bash
argument-hint: "[file-path-or-folder-or-prompt] [--expand <id>] [--expand-all] [--research]"
description: Parse a PRD into tasks, or expand existing tasks into subtasks
---

# Plan Command

You are implementing the `taskmanager:plan` command.

## Arguments

- `$1` (optional): path to a PRD file, a folder containing documentation files, or a prompt describing what to plan. If omitted, use `.taskmanager/docs/prd.md`.
- `--research`: Research key topics from the PRD before generating tasks (uses `taskmanager:research` internally)
- `--expand <id>`: Expand a single task into subtasks (post-planning)
- `--expand-all [--threshold <XS|S|M|L|XL>]`: Expand all eligible tasks above threshold (default: M)
- `--force`: Re-expand tasks that already have subtasks
- `--estimate`: Generate time estimates (not default during expansion)

## Database

This command uses SQLite database at `.taskmanager/taskmanager.db`.

**Schema reference for tasks table:**
```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    details TEXT,
    test_strategy TEXT,
    status TEXT NOT NULL DEFAULT 'planned',
    type TEXT NOT NULL DEFAULT 'feature',
    priority TEXT NOT NULL DEFAULT 'medium',
    complexity_scale TEXT,
    complexity_reasoning TEXT,
    complexity_expansion_prompt TEXT,
    estimate_seconds INTEGER,
    tags TEXT DEFAULT '[]',
    dependencies TEXT DEFAULT '[]',
    dependency_analysis TEXT,
    meta TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);
```

## Routing

- `plan` → parse PRD from `.taskmanager/docs/prd.md`
- `plan <file-or-folder-or-prompt>` → parse input into tasks
- `plan --expand <id>` → expand single task into subtasks
- `plan --expand-all` → bulk expand all eligible tasks
- `plan --expand-all --threshold L` → expand only L and XL tasks

## Behavior

### 0. Initialize session

1. Generate session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Verify database exists.
3. Update state table with session_id.
4. Log to `activity.log`.

### PRD Planning Mode (no --expand flags)

### 1. Determine input type
   - If the user provided an argument, determine if `$1` is:
     1. **A folder path** - Contains multiple documentation files
     2. **A file path** - A single PRD/documentation file
     3. **A prompt** - Free-text describing what should be done
   - If nothing is provided, default to `.taskmanager/docs/prd.md`.

### 1.1 Handling folder input

When `$1` is a folder (directory):

1. **Discover documentation files** - Use Glob to find all markdown files (`**/*.md`) in the folder and its subdirectories.
2. **Read all files** - Use Read to load the content of each discovered file.
3. **Aggregate content** - Combine all file contents into a single PRD context, preserving the source file names as section headers.
4. **Pass aggregated content to the skill**.

### 2. Generate and insert tasks

1. Call the `taskmanager` skill with instructions to generate a hierarchical plan.
2. **Insert tasks via SQL transaction** for atomicity.

**Important SQL notes:**
- Use single quotes for string values, escape internal quotes by doubling them.
- JSON fields must be valid JSON strings.
- `parent_id` must reference an existing task ID or be NULL for top-level tasks.
- Insert parent tasks before their children to satisfy foreign key constraints.
- Always wrap multiple inserts in a transaction.

### 3. Summarize

Query created task counts and report to user.

### Expansion Mode (--expand)

### expand <id> — Single task expansion

1. Load the task:
   ```sql
   SELECT id, title, description, details, test_strategy, complexity_scale,
          complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies
   FROM tasks WHERE id = '<task-id>' AND archived_at IS NULL;
   ```

2. Validate:
   - If task doesn't exist, inform user and stop.
   - If task already has subtasks and `--force` not set: inform user and stop.
   - If `--force` set: warn user, delete existing subtasks.

3. Generate subtasks using the `taskmanager` skill:
   - Use `complexity_expansion_prompt` if available.
   - Each subtask gets: id, title, description, details, test_strategy, status, type, priority, complexity_scale, estimate_seconds, tags, dependencies.
   - Subtask IDs follow parent pattern (e.g., parent `1.2` gets `1.2.1`, `1.2.2`).

4. Insert subtasks and update parent estimate via SQL transaction.

5. Check if any new subtasks need further expansion (recursive check).

### expand --all — Bulk expansion

Map threshold to complexity_scale order:
```
XS < S < M < L < XL
```

```sql
SELECT id, title, description, details, test_strategy, complexity_scale,
       complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND CASE complexity_scale
      WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE -1
  END >= <threshold_value>
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id)
ORDER BY
    CASE complexity_scale WHEN 'XL' THEN 0 WHEN 'L' THEN 1 WHEN 'M' THEN 2 WHEN 'S' THEN 3 ELSE 4 END,
    CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    id;
```

Expand each eligible task, then recursively check new subtasks.

### 4. Cleanup

Log to `activity.log`. Reset state session.

## Logging

All logging goes to `.taskmanager/logs/activity.log`:
- Command start and completion
- Task creation summaries
- Expansion details
- Errors

## Error Handling

- If database does not exist, instruct user to run `taskmanager:init`.
- If INSERT fails due to duplicate ID, report conflict and suggest resolution.
- If foreign key constraint fails, check task insertion order.
- Always ROLLBACK transaction on error.

## Usage Examples

```bash
# Plan from default PRD
taskmanager:plan

# Plan from file
taskmanager:plan docs/new-feature-prd.md

# Plan from folder
taskmanager:plan docs/project-specs/

# Plan from prompt
taskmanager:plan "Create a react counter app"

# Plan with research
taskmanager:plan docs/prd.md --research

# Expand a single task
taskmanager:plan --expand 1.2

# Re-expand a task
taskmanager:plan --expand 1.2 --force

# Expand all tasks with complexity M or above
taskmanager:plan --expand-all

# Expand only L and XL tasks
taskmanager:plan --expand-all --threshold L
```

## Related Commands

- `taskmanager:show` - View tasks, dashboard, stats
- `taskmanager:run` - Execute tasks
- `taskmanager:research` - Research before planning
- `taskmanager:update` - Update task fields
