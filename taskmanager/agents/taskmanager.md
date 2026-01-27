---
description: >
  Data and invariants spec for the MWGuerra Task Manager. Defines the structure
  and rules for .taskmanager/taskmanager.db (SQLite database) and logs.
  All planning and execution behavior is defined in the taskmanager skill
  and related commands.
version: 2.0.0
---

# MWGuerra Task Manager – Agent Spec

This document defines the **data contracts and invariants** for the
`.taskmanager` runtime using SQLite as the storage backend.

It does **not** define behavior (planning, execution, PRD ingestion, auto-run,
dashboard, or commands). All behavior lives in the plugin's skills and commands.

---

## Plugin Resources

This agent has access to the following resources within the `taskmanager` plugin:

### Commands (14 total)

| Command | Description |
|---------|-------------|
| `taskmanager:init` | Initialize a `.taskmanager` directory with SQLite database |
| `taskmanager:plan` | Parse PRD content and generate a hierarchical task tree with dependencies and complexity |
| `taskmanager:dashboard` | Display a text-based progress dashboard with status counts, completion metrics, and critical path |
| `taskmanager:next-task` | Find and display the next available task based on dependencies and priority |
| `taskmanager:execute-task` | Execute a single task by ID or find the next available task with memory support |
| `taskmanager:run-tasks` | Autonomously execute tasks in batch with progress tracking and memory support |
| `taskmanager:stats` | Get token-efficient statistics using SQL queries |
| `taskmanager:get-task` | Get a specific task by ID using SQL query |
| `taskmanager:update-status` | Batch update task status for one or more tasks efficiently |
| `taskmanager:memory` | Manage project memories - add, list, show, update, deprecate with conflict detection |
| `taskmanager:migrate-archive` | Archive completed tasks by setting archived_at timestamp |
| `taskmanager:sync` | Two-way sync with Claude Code native tasks |
| `taskmanager:export` | Export database to JSON format |
| `taskmanager:rollback` | Revert to JSON format from SQLite |

### Skills (2 total)

| Skill | Description |
|-------|-------------|
| `taskmanager` | Core task management - parse PRDs, generate hierarchical tasks, manage status propagation, time estimation |
| `taskmanager-memory` | Memory management - constraints, decisions, conventions with conflict detection and resolution |

### Template

The initialization template is located at:
```
skills/taskmanager/template/.taskmanager/
```

This template contains the initial structure for new projects including schemas and starter files.

---

## 1. Folder Layout

At the project root after initialization:

```text
.taskmanager/
  taskmanager.db                # SQLite database (all data)
  backup-v1/                    # Migration backup (if migrated from JSON)
  logs/
    errors.log                  # Append-only error log
    debug.log                   # Verbose debug tracing
    decisions.log               # High-level planning/decision log
  docs/
    prd.md                      # Project requirements document
```

### 1.1 Token-Efficient Task Operations

SQLite enables efficient operations without loading all data into memory:

#### Using Commands

```bash
# Get statistics in JSON format
taskmanager:stats --json

# Get a specific task by ID
taskmanager:get-task 1.2.3
taskmanager:get-task 1.2.3 status
taskmanager:get-task 1.2.3 complexity_scale

# Update status for tasks
taskmanager:update-status done 1.2.3
taskmanager:update-status done 1.2.3 1.2.4 1.2.5
```

#### Using sqlite3 Directly

```bash
# Get statistics
sqlite3 .taskmanager/taskmanager.db "
SELECT COUNT(*) as total,
  SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) as done
FROM tasks WHERE archived_at IS NULL"

# Get specific task as JSON
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks WHERE id = '1.2.3'"

# Get next available task
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks
WHERE status = 'planned' AND archived_at IS NULL
ORDER BY priority DESC, id
LIMIT 1"

# Update task status
sqlite3 .taskmanager/taskmanager.db "
UPDATE tasks SET status = 'done', completed_at = datetime('now')
WHERE id = '1.2.3'"
```

#### Benefits of SQLite:
- Indexed queries for instant lookups regardless of task count
- No file size limits or token concerns
- Atomic transactions prevent data corruption
- FTS5 full-text search for memories

Agents MUST:

* Use proper SQL queries to read/write data.
* Maintain referential integrity (parent_id references valid tasks).
* Write decisions and errors to the appropriate log files.

Initialization of `.taskmanager/` SHOULD be done using:

```
taskmanager:init
```

---

## 2. Database Schema

All data is stored in `.taskmanager/taskmanager.db`, a SQLite database.

### 2.1 Database Tables

| Table | Purpose |
|-------|---------|
| `tasks` | All tasks (active and archived via `archived_at` column) |
| `memories` | Project memories with metadata |
| `memories_fts` | FTS5 virtual table for full-text search on memories |
| `state` | Single-row execution state |
| `sync_log` | Native task sync tracking |
| `schema_version` | Migration tracking |

### 2.2 Tasks Table Schema

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,              -- Dotted ID pattern: "1", "1.2", "1.2.3"
  parent_id TEXT,                   -- Parent reference (NULL for top-level)
  title TEXT NOT NULL,
  description TEXT,
  details TEXT,
  status TEXT NOT NULL DEFAULT 'planned',
  type TEXT DEFAULT 'feature',
  priority TEXT DEFAULT 'medium',
  domain TEXT DEFAULT 'software',
  complexity_score INTEGER,         -- 0-5
  complexity_scale TEXT,            -- XS, S, M, L, XL
  complexity_reasoning TEXT,
  estimate_seconds INTEGER,
  duration_seconds INTEGER,
  started_at TEXT,                  -- ISO 8601 timestamp
  completed_at TEXT,                -- ISO 8601 timestamp
  archived_at TEXT,                 -- ISO 8601 timestamp (NULL = active)
  dependencies TEXT,                -- JSON array of task IDs
  tags TEXT,                        -- JSON array of strings
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (parent_id) REFERENCES tasks(id)
);
```

**Status values:**
- `draft`, `planned`, `in-progress`, `blocked`, `paused`
- `done`, `canceled`, `duplicate`, `needs-review`

**Type values:**
- `feature`, `bug`, `chore`, `analysis`, `spike`

**Priority values:**
- `low`, `medium`, `high`, `critical`

### 2.3 Hierarchy Rules

* IDs are **unique** across all tasks.
* Dotted paths define hierarchy:

  * `"1"` → top level
  * `"1.2"` → second child of task 1
  * `"1.2.3"` → third child of task 1.2
* `parent_id` MUST:

  * Be `NULL` for top-level tasks
  * Match the actual parent's ID for subtasks

The hierarchy is enforced via foreign key constraint.

### 2.4 Task Domains

  - `domain` can be:
    - `"software"` (default)
    - `"writing"` (for books, articles, documentation, fiction, etc.)

  - All invariants (status propagation, time estimation, dependencies, critical path) are domain-agnostic.

### 2.5 SQL Query Examples

```sql
-- Get all active (non-archived) tasks
SELECT * FROM tasks WHERE archived_at IS NULL;

-- Get task with children
SELECT * FROM tasks WHERE id = '1' OR parent_id = '1';

-- Get next available task (planned, no blockers)
SELECT * FROM tasks
WHERE status = 'planned'
  AND archived_at IS NULL
  AND (dependencies IS NULL OR dependencies = '[]')
ORDER BY
  CASE priority
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
  END,
  id
LIMIT 1;

-- Insert new task
INSERT INTO tasks (id, parent_id, title, status, type, priority)
VALUES ('1.3', '1', 'New subtask', 'planned', 'feature', 'medium');
```

### 2.6 Time & Estimation Invariants

  - `estimate_seconds`
    - Leaf tasks: MUST be non-null (>= 0) once planning is complete.
    - Parent tasks: SHOULD equal the sum of `estimate_seconds` of their direct children.
  - `started_at` / `completed_at`
    - Set only by the runtime when a leaf task enters `"in-progress"` or a terminal state.
    - Stored as ISO 8601 UTC timestamps.
  - `duration_seconds`
    - Computed as `completed_at - started_at` in seconds, when a leaf becomes terminal.
    - Never negative; NULL if `started_at` was not set.

### 2.7 Archival

Archival is handled via the `archived_at` column - no separate table needed:

```sql
-- Archive a task
UPDATE tasks
SET archived_at = datetime('now')
WHERE id = '1.2.3';

-- Unarchive a task
UPDATE tasks
SET archived_at = NULL
WHERE id = '1.2.3';

-- Get only archived tasks
SELECT * FROM tasks WHERE archived_at IS NOT NULL;

-- Get only active tasks
SELECT * FROM tasks WHERE archived_at IS NULL;
```

**Archive invariants:**
- Tasks with `archived_at IS NOT NULL` are considered archived
- Archived tasks SHOULD have terminal status (`done`, `canceled`, `duplicate`)
- All task data remains intact (no stub/full split)

---

## 3. Memories Table

Project memories are stored in the `memories` table with FTS5 full-text search support.

### 3.1 Memories Table Schema

```sql
CREATE TABLE memories (
  id TEXT PRIMARY KEY,              -- Format: M-0001, M-0002, etc.
  content TEXT NOT NULL,
  category TEXT,                    -- constraint, decision, convention, etc.
  importance INTEGER DEFAULT 3,     -- 1-5 scale
  status TEXT DEFAULT 'active',     -- active, deprecated, superseded
  source_type TEXT,                 -- user, system, agent
  source_task_id TEXT,
  source_command TEXT,
  tags TEXT,                        -- JSON array
  file_patterns TEXT,               -- JSON array
  use_count INTEGER DEFAULT 0,
  last_used_at TEXT,
  auto_updatable INTEGER DEFAULT 1, -- 0 for user-created
  superseded_by TEXT,
  conflict_resolutions TEXT,        -- JSON array
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- FTS5 virtual table for full-text search
CREATE VIRTUAL TABLE memories_fts USING fts5(
  id,
  content,
  category,
  tags,
  content=memories,
  content_rowid=rowid
);
```

**Purpose**

Capture long-lived project knowledge that should survive across sessions, tasks, and agents:

- Architectural and product decisions
- Invariants and constraints
- Common pitfalls, bugfixes, and workarounds
- Conventions, naming rules, testing rules
- Repeated errors and their resolutions

### 3.2 Memory Invariants

- IDs are stable (`M-0001`, `M-0002`, ...).
- `status = 'deprecated'` or `'superseded'` memories MUST NOT be deleted; they stay for history.
- `importance >= 4` memories SHOULD be considered whenever planning or executing high-impact tasks.
- `auto_updatable` MUST be `0` for user-created memories (`source_type = 'user'`).
- `conflict_resolutions` JSON array MUST record every conflict resolution with timestamp and reason.

### 3.3 Memory SQL Examples

```sql
-- Add a memory
INSERT INTO memories (id, content, category, importance, source_type)
VALUES ('M-0001', 'Always use snake_case for database columns', 'convention', 4, 'user');

-- Search memories using FTS5
SELECT m.* FROM memories m
JOIN memories_fts fts ON m.id = fts.id
WHERE memories_fts MATCH 'database AND convention';

-- Get active high-importance memories
SELECT * FROM memories
WHERE status = 'active' AND importance >= 4
ORDER BY importance DESC, use_count DESC;

-- Update usage tracking
UPDATE memories
SET use_count = use_count + 1, last_used_at = datetime('now')
WHERE id = 'M-0001';

-- Deprecate a memory
UPDATE memories
SET status = 'deprecated', updated_at = datetime('now')
WHERE id = 'M-0001';
```

### 3.4 Memory Scopes

There are two scopes of memory:

1. **Global Memory** (persisted in `memories` table):
   - Added via `--memory` / `-gm` command argument or `taskmanager:memory add` command.
   - Persists across all tasks and sessions.
   - User-created memories require user approval for any changes.

2. **Task-Scoped Memory** (stored in `state` table `task_memory` column):
   - Added via `--task-memory` / `-tm` command argument.
   - Temporary, lives only for duration of task or batch.
   - Reviewed for promotion to global at task completion.

### 3.5 Lifecycle

- **Creation**: When a user, agent, or command makes a decision that should apply to future work.
- **Update**: When a memory is refined, corrected, or superseded.
- **Conflict Detection**: Runs automatically at task start and end.
- **Conflict Resolution**: Depends on ownership:
  - User-created (`source_type = 'user'`): ALWAYS requires user approval.
  - System-created: Can auto-update for refinements, requires approval for reversals.
- **Usage Tracking**: When applied to a task, `use_count` incremented and `last_used_at` updated.

---

## 4. State Table

The `state` table stores execution state as a single row.

### 4.1 State Table Schema

```sql
CREATE TABLE state (
  id INTEGER PRIMARY KEY CHECK (id = 1),  -- Ensures single row
  version TEXT DEFAULT '2.0.0',
  current_task_id TEXT,
  current_subtask_path TEXT,
  current_step TEXT DEFAULT 'idle',
  mode TEXT DEFAULT 'interactive',
  started_at TEXT,
  last_update TEXT DEFAULT (datetime('now')),
  -- Evidence (stored as JSON)
  evidence_files_created TEXT DEFAULT '[]',
  evidence_files_modified TEXT DEFAULT '[]',
  evidence_commit_sha TEXT,
  evidence_tests_before INTEGER DEFAULT 0,
  evidence_tests_after INTEGER DEFAULT 0,
  -- Verifications
  verify_files_created INTEGER DEFAULT 0,
  verify_files_non_empty INTEGER DEFAULT 0,
  verify_git_changes INTEGER DEFAULT 0,
  verify_tests_pass INTEGER DEFAULT 0,
  verify_committed INTEGER DEFAULT 0,
  -- Optional fields
  loop_count INTEGER,
  context_snapshot TEXT,
  last_decision TEXT,
  task_memory TEXT DEFAULT '[]',      -- JSON array of task-scoped memories
  applied_memories TEXT DEFAULT '[]', -- JSON array of memory IDs
  -- Logging
  debug_enabled INTEGER DEFAULT 0,
  session_id TEXT
);
```

### 4.2 State Fields

* `current_task_id` — string or NULL
* `current_subtask_path` — string or NULL
* `current_step` — one of:
  * `starting`, `planning-top-level`, `expanding-subtasks`,
    `dependency-analysis`, `execution`, `verification`,
    `idle`, `done`
* `mode` — `autonomous`, `interactive`, `paused`

### 4.3 Task Memory

`task_memory` JSON column stores temporary, task-scoped memories:

```json
[
  {
    "content": "Focus on error handling in this task",
    "addedAt": "2025-12-11T10:00:00Z",
    "taskId": "1.2.3",
    "source": "user"
  }
]
```

**Invariants**:
- `taskId` MUST be a valid task ID pattern OR `"*"` for batch-level memories.
- Cleared for each task at task completion (after promotion review).
- `"*"` task memories are cleared at batch completion.

### 4.4 SQL Examples

```sql
-- Get current state
SELECT * FROM state WHERE id = 1;

-- Update current task
UPDATE state SET
  current_task_id = '1.2.3',
  current_step = 'execution',
  last_update = datetime('now')
WHERE id = 1;

-- Clear task memory after completion
UPDATE state SET
  task_memory = '[]',
  applied_memories = '[]',
  current_task_id = NULL,
  current_step = 'idle'
WHERE id = 1;

-- Initialize state (done by init command)
INSERT OR REPLACE INTO state (id, version, mode, started_at)
VALUES (1, '2.0.0', 'interactive', datetime('now'));
```

---

## 5. Logs Contract

Logs live under:

```
.taskmanager/logs/
```

### 5.1 Log Files

| File | Purpose | When to Write |
|------|---------|---------------|
| `errors.log` | Runtime errors, validation failures, conflicts | ALWAYS when errors occur |
| `decisions.log` | High-level planning decisions, task status changes, memory operations | ALWAYS during execution |
| `debug.log` | Verbose tracing, intermediate states, detailed conflict analysis | ONLY when `--debug` flag is enabled |

### 5.2 Logging Rules

* Logs are **append-only**. Never truncate or overwrite.
* All log entries MUST include an ISO 8601 timestamp.
* All log entries SHOULD include a session ID for correlation (from `state.session_id`).

### 5.3 Log Entry Format

```text
<timestamp> [<level>] [<session-id>] <message>
```

**Levels:**
- `ERROR` — Failures, exceptions, validation errors
- `DECISION` — Planning choices, task transitions, memory changes
- `DEBUG` — Verbose tracing (only when debug enabled)

**Examples:**

```text
2025-12-11T10:00:00Z [DECISION] [sess-abc123] Started task 1.2.3: "Implement user auth"
2025-12-11T10:00:01Z [DECISION] [sess-abc123] Applied memories: M-0001, M-0003
2025-12-11T10:00:02Z [ERROR] [sess-abc123] Conflict detected: M-0001 references deleted file app/OldAuth.php
2025-12-11T10:00:03Z [DEBUG] [sess-abc123] Queried tasks table, found 15 tasks, 8 pending
2025-12-11T10:05:00Z [DECISION] [sess-abc123] Completed task 1.2.3 with status "done"
```

### 5.4 What to Log

**errors.log** — ALWAYS write:
- SQL errors and constraint violations
- Database connection failures
- Memory conflict detection results
- Dependency resolution failures
- Any exception or unexpected state

**decisions.log** — ALWAYS write:
- Task creation (from planning)
- Task status transitions (planned → in-progress → done)
- Memory creation, update, deprecation, supersession
- Memory application (which memories applied to which task)
- Conflict resolution outcomes
- Batch start/end summaries

**debug.log** — ONLY write when `state.debug_enabled = 1`:
- SQL queries executed
- Memory matching algorithm details
- Conflict detection intermediate steps
- File existence checks
- Performance timing information

### 5.5 Debug Mode

Debug logging is **disabled by default** to avoid excessive log growth.

To enable debug logging for a command:
- Pass `--debug` or `-d` flag to any command
- This sets `state.debug_enabled = 1` for the session
- Debug mode persists until the command completes

Commands MUST:
1. Check for `--debug` / `-d` flag at startup
2. Set `state.debug_enabled = 1` if present
3. Generate a unique `session_id` for log correlation
4. Reset `debug_enabled = 0` at command completion

### 5.6 Logging Configuration in State Table

```sql
-- Enable debug mode
UPDATE state SET debug_enabled = 1, session_id = 'sess-20251212103045' WHERE id = 1;

-- Disable debug mode
UPDATE state SET debug_enabled = 0, session_id = NULL WHERE id = 1;
```

**Invariants:**
- `debug_enabled` defaults to `0`
- `session_id` is generated at command start using timestamp format
- Both are reset at command completion

---

## 6. Sync Log Table

The `sync_log` table tracks synchronization with Claude Code native tasks.

### 6.1 Sync Log Schema

```sql
CREATE TABLE sync_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  native_task_id TEXT,
  taskmanager_id TEXT,
  action TEXT,          -- created, updated, deleted
  direction TEXT,       -- to_native, from_native
  synced_at TEXT DEFAULT (datetime('now')),
  details TEXT          -- JSON with sync details
);
```

### 6.2 Schema Version Table

```sql
CREATE TABLE schema_version (
  version INTEGER PRIMARY KEY,
  applied_at TEXT DEFAULT (datetime('now')),
  description TEXT
);
```

---

## 7. Interop Rules (Very Important)

All planning, execution, dashboard, next-task, and other features must:

1. Treat this document as the **contract** for:

   * `taskmanager.db` SQLite database
   * Tables: `tasks`, `memories`, `memories_fts`, `state`, `sync_log`, `schema_version`
   * Logging rules
2. Use proper SQL queries to read/write data
3. Delegate all behavior to the plugin's skills and commands:

   * `taskmanager` skill — task management behavior
   * `taskmanager-memory` skill — memory management behavior
   * Plugin commands — command implementations

4. For memory operations:

   * Use the `taskmanager-memory` skill for all memory management
   * Use FTS5 search via `memories_fts` table for content matching
   * Run conflict detection at task start AND end
   * Always ask user for approval when modifying user-created memories
   * Track `applied_memories` during execution and clear after task completion
   * Review task-scoped memories for promotion before marking task as done

This file is intentionally **behavior-light**.
Its purpose is to define *what the data must look like*, not how tasks are planned or executed.

---

## 8. Command Reference

### Initialization

```bash
taskmanager:init
```

Creates `.taskmanager/` directory with SQLite database and required tables.

### Planning

```bash
taskmanager:plan [source]
```

Parse PRD content from file, folder, or text input to generate tasks.

Examples:
- `taskmanager:plan docs/prd.md` - Plan from file
- `taskmanager:plan docs/specs/` - Plan from folder (aggregates all .md files)
- `taskmanager:plan "Build a counter app"` - Plan from text

### Dashboard & Status

```bash
taskmanager:dashboard
taskmanager:stats [--json]
```

View progress, completion metrics, and task overview.

### Task Execution

```bash
taskmanager:next-task
taskmanager:execute-task [task-id] [--memory "..."] [--task-memory "..."]
taskmanager:run-tasks [count] [--memory "..."] [--task-memory "..."]
```

Find and execute tasks with optional memory context.

### Efficient Operations

```bash
taskmanager:get-task <id> [column]
taskmanager:update-status <status> <id1> [id2...]
```

Token-efficient task queries and updates using SQL.

### Memory Management

```bash
taskmanager:memory add "description"
taskmanager:memory list [--status active]
taskmanager:memory show <id>
taskmanager:memory update <id>
taskmanager:memory deprecate <id>
taskmanager:memory search "query"
```

Manage project memories with FTS5 full-text search and conflict detection.

### Archival

```bash
taskmanager:migrate-archive
```

Archive completed tasks by setting `archived_at` timestamp.

### Sync & Export

```bash
taskmanager:sync
```

Two-way sync with Claude Code native tasks. Syncs status and creates missing tasks in either direction.

```bash
taskmanager:export [--output file.json]
```

Export entire database to JSON format for backup or migration.

```bash
taskmanager:rollback [--backup-dir path]
```

Revert from SQLite back to JSON format. Uses backup-v1/ directory if available.
