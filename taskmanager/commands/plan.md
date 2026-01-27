---
allowed-tools: Skill(taskmanager), Bash
argument-hint: "[file-path-or-folder-or-prompt] [--debug]"
description: Parse a PRD file, folder, or prompt and generate hierarchical tasks with dependencies and complexity analysis
---

# Plan Command

You are implementing the `taskmanager:plan` command.

## Arguments

- `$1` (optional): path to a PRD file, a folder containing documentation files, or a prompt describing what to plan. If omitted, use `.taskmanager/docs/prd.md`.
- `--debug` or `-d`: Enable verbose debug logging to `.taskmanager/logs/debug.log`

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
    complexity_score INTEGER,
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

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID using timestamp: `sess-$(date +%Y%m%d%H%M%S)` (e.g., `sess-20251212103045`).
2. Check for `--debug` / `-d` flag.
3. **Verify database exists** - Check if `.taskmanager/taskmanager.db` exists:
   ```bash
   if [ ! -f .taskmanager/taskmanager.db ]; then
       echo "Error: Database not initialized. Run 'taskmanager:init' first."
       exit 1
   fi
   ```
4. Update session state in database:
   ```bash
   sqlite3 .taskmanager/taskmanager.db "
   UPDATE state SET
       session_id = '<session-id>',
       debug_enabled = <1|0>,
       last_update = datetime('now')
   WHERE id = 1;
   "
   ```
5. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started plan command
   ```

### 1. Determine input type
   - If the user provided an argument, determine if `$1` is:
     1. **A folder path** - Contains multiple documentation files
     2. **A file path** - A single PRD/documentation file
     3. **A prompt** - Free-text describing what should be done
   - If nothing is provided, default to `.taskmanager/docs/prd.md`.
   - If the argument is not a valid path but looks like one, inform the user and gracefully exit.

### 1.1 Handling folder input

When `$1` is a folder (directory):

1. **Discover documentation files** - Use Glob to find all markdown files (`**/*.md`) in the folder and its subdirectories.
2. **Read all files** - Use Read to load the content of each discovered file.
3. **Aggregate content** - Combine all file contents into a single PRD context, preserving the source file names as section headers:
   ```
   # From: architecture.md
   [content of architecture.md]

   # From: features/user-auth.md
   [content of features/user-auth.md]

   # From: database.md
   [content of database.md]
   ```
4. **Pass aggregated content to the skill** - Treat the combined content as if it were a single PRD file.

**Folder input notes:**
- Files are sorted alphabetically by path for consistent ordering.
- Only `.md` (markdown) files are included by default.
- Empty files are skipped.
- The folder structure is preserved in section headers for context.
- If no markdown files are found in the folder, inform the user and gracefully exit.

### 2. Generate and insert tasks

1. Call the `taskmanager` skill with instructions to:
   - Read the chosen file or use the prompt if provided.
   - Generate a realistic, hierarchical plan as described in the skill and its examples.
   - Return the task data structure for insertion.

2. **Insert tasks via SQL transaction** - Use a transaction for atomicity:
   ```bash
   sqlite3 .taskmanager/taskmanager.db "
   BEGIN TRANSACTION;

   -- Insert parent task
   INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority, complexity_score, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
   VALUES (
       '1',
       NULL,
       'Task title here',
       'Task description',
       'Implementation details',
       'Test strategy',
       'planned',
       'feature',
       'high',
       3,
       'M',
       'Reasoning for complexity',
       7200,
       '[\"tag1\", \"tag2\"]',
       '[]'
   );

   -- Insert subtasks with parent references
   INSERT INTO tasks (id, parent_id, title, description, status, type, priority, complexity_score, complexity_scale, estimate_seconds, tags, dependencies)
   VALUES (
       '1.1',
       '1',
       'Subtask title',
       'Subtask description',
       'planned',
       'feature',
       'medium',
       2,
       'S',
       3600,
       '[]',
       '[]'
   );

   INSERT INTO tasks (id, parent_id, title, description, status, type, priority, complexity_score, complexity_scale, estimate_seconds, tags, dependencies)
   VALUES (
       '1.2',
       '1',
       'Another subtask',
       'Description',
       'planned',
       'feature',
       'medium',
       2,
       'S',
       3600,
       '[]',
       '[\"1.1\"]'
   );

   COMMIT;
   "
   ```

**Important SQL notes:**
- Use single quotes for string values, escape internal quotes by doubling them (`''`).
- JSON fields (`tags`, `dependencies`, `meta`) must be valid JSON strings.
- `parent_id` must reference an existing task ID or be NULL for top-level tasks.
- Insert parent tasks before their children to satisfy foreign key constraints.
- Always wrap multiple inserts in a transaction for atomicity.

### 3. After the skill finishes, summarize for the user

1. Query the database for created task counts:
   ```bash
   sqlite3 .taskmanager/taskmanager.db "
   SELECT
       COUNT(*) as total,
       COUNT(CASE WHEN parent_id IS NULL THEN 1 END) as top_level,
       COUNT(CASE WHEN parent_id IS NOT NULL THEN 1 END) as subtasks
   FROM tasks
   WHERE created_at >= datetime('now', '-1 minute');
   "
   ```

2. Report to user:
   - How many new tasks/subtasks were created.
   - The IDs and titles of the most important top-level tasks.

### 4. Cleanup logging session

1. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Completed plan command: N tasks created
   ```
2. Reset session state in database:
   ```bash
   sqlite3 .taskmanager/taskmanager.db "
   UPDATE state SET
       debug_enabled = 0,
       session_id = NULL,
       last_update = datetime('now')
   WHERE id = 1;
   "
   ```

## Logging Requirements

This command MUST log to `.taskmanager/logs/`:

**To errors.log** (ALWAYS):
- Database not found errors
- File not found errors
- Parse errors
- SQL errors
- Validation errors

**To decisions.log** (ALWAYS):
- Command start and completion
- Task creation summaries

**To debug.log** (ONLY when `--debug` enabled):
- PRD parsing details
- Task generation algorithm steps
- Complexity analysis details
- SQL statements being executed

## Error Handling

**Database errors:**
- If database does not exist, instruct user to run `taskmanager:init`.
- If INSERT fails due to duplicate ID, report conflict and suggest resolution.
- If foreign key constraint fails, check task insertion order.
- Always ROLLBACK transaction on error.

**Example error handling:**
```bash
result=$(sqlite3 .taskmanager/taskmanager.db "BEGIN; INSERT...; COMMIT;" 2>&1)
if [ $? -ne 0 ]; then
    echo "SQL Error: $result"
    sqlite3 .taskmanager/taskmanager.db "ROLLBACK;"
    # Log to errors.log
fi
```

## Usage examples

### Using the default PRD file
- `taskmanager:plan`
  - Reads from `.taskmanager/docs/prd.md`

### Using a single file
- `taskmanager:plan docs/new-feature-prd.md`
  - Reads the specified markdown file

### Using a folder with multiple documentation files
- `taskmanager:plan docs/project-specs/`
  - Discovers and reads all `.md` files in the folder recursively
  - Example folder structure:
    ```
    docs/project-specs/
    ├── architecture.md      # System architecture overview
    ├── database.md          # Database schema and design
    ├── features/
    │   ├── user-auth.md     # User authentication feature
    │   └── dashboard.md     # Dashboard feature
    └── api/
        └── endpoints.md     # API endpoint definitions
    ```
  - All files are aggregated into a single PRD context for task generation

### Using a prompt
- `taskmanager:plan "Create a react app that has a counter button that increments one each time its clicked on an on screen counter that begins at zero"`
  - Uses the prompt text directly as PRD content

### With debug logging
- `taskmanager:plan docs/specs/ --debug`
  - Enables verbose debug logging to `.taskmanager/logs/debug.log`