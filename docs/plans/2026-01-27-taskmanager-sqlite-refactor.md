# Taskmanager SQLite Refactor Design

**Date:** 2026-01-27
**Status:** Approved
**Scope:** Major refactor of taskmanager plugin storage and native task integration

## Problem Statement

The current taskmanager plugin uses JSON files for storage, which causes:

1. **Token inefficiency** - Large `tasks.json` files (>25k tokens) cannot be fully loaded into context
2. **Full-file rewrites** - Any mutation requires reading, parsing, modifying, and rewriting the entire file
3. **No efficient queries** - Status propagation, filtering, and aggregation require parsing the whole tree
4. **Workaround complexity** - A 540-line bash/jq script was created to mitigate read issues, but writes remain problematic

Additionally, Claude Code now has native task management tools (`TaskCreate`, `TaskList`, etc.) that could complement taskmanager for session-scoped work.

## Solution Overview

1. **Migrate from JSON to SQLite** - Single `taskmanager.db` file with efficient queries and atomic updates
2. **Two-way sync with native tasks** - Push tasks to Claude Code's native system at session start, pull completions back
3. **Auto-migrate existing projects** - Detect JSON files and convert to SQLite on first use
4. **Keep writing domain support** - Maintain book/article tracking features

## Architecture

### Storage Structure

```
.taskmanager/
├── taskmanager.db      # Single SQLite database (all data)
├── logs/               # Keep as text files (appendable, readable)
│   ├── decisions.log
│   ├── errors.log
│   └── debug.log
└── docs/               # User documentation (PRDs)
    └── prd.md
```

### Removed Files (migrated to SQLite)

- `tasks.json` → `tasks` table
- `tasks-archive.json` → Same `tasks` table with `archived_at` column
- `memories.json` → `memories` table with FTS5 search
- `state.json` → `state` table (single row)
- `schemas/*.json` → SQLite enforces schema
- `scripts/task-stats.sh` → Replaced by SQL queries

## Database Schema

### Tasks Table

```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,           -- Dotted ID: "1", "1.2", "1.2.3"
    parent_id TEXT REFERENCES tasks(id),
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
    duration_seconds INTEGER,
    owner TEXT,

    -- Writing domain (nullable)
    domain TEXT DEFAULT 'software',
    writing_type TEXT,
    content_unit TEXT,
    writing_stage TEXT,
    target_word_count INTEGER,
    current_word_count INTEGER,

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    archived_at TEXT,              -- NULL = active, set = archived

    -- Flexible storage (JSON columns)
    tags TEXT,                     -- JSON array
    dependencies TEXT,             -- JSON array of task IDs
    dependency_analysis TEXT,      -- JSON object
    meta TEXT                      -- JSON object for custom fields
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_parent ON tasks(parent_id);
CREATE INDEX idx_tasks_archived ON tasks(archived_at);
CREATE INDEX idx_tasks_priority ON tasks(priority);
```

### Memories Table with Full-Text Search

```sql
CREATE TABLE memories (
    id TEXT PRIMARY KEY,           -- M-0001, M-0002, etc.
    title TEXT NOT NULL,
    kind TEXT NOT NULL,            -- constraint, decision, bugfix, workaround, convention, etc.
    why_important TEXT NOT NULL,
    body TEXT NOT NULL,

    -- Ownership & source
    source_type TEXT NOT NULL,     -- user, agent, command, hook, other
    source_name TEXT,
    source_via TEXT,
    auto_updatable INTEGER DEFAULT 1,

    -- Relevance scoring
    importance INTEGER NOT NULL DEFAULT 3,  -- 1-5, where 5 is critical
    confidence REAL NOT NULL DEFAULT 0.8,   -- 0-1
    status TEXT NOT NULL DEFAULT 'active',  -- active, deprecated, superseded, draft
    superseded_by TEXT REFERENCES memories(id),

    -- Scope (JSON for flexibility)
    scope TEXT,                    -- JSON: {project, files, tasks, commands, agents, domains}
    tags TEXT,                     -- JSON array
    links TEXT,                    -- JSON array of URLs

    -- Usage tracking
    use_count INTEGER DEFAULT 0,
    last_used_at TEXT,
    last_conflict_at TEXT,
    conflict_resolutions TEXT,     -- JSON array of {timestamp, resolution, reason, taskId}

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Full-text search for memory content
CREATE VIRTUAL TABLE memories_fts USING fts5(
    title, body, tags,
    content='memories',
    content_rowid='rowid'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

CREATE TRIGGER memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
END;

CREATE TRIGGER memories_au AFTER UPDATE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;
```

### State Table (Single Row)

```sql
CREATE TABLE state (
    id INTEGER PRIMARY KEY CHECK (id = 1),  -- Enforce single row
    current_task_id TEXT REFERENCES tasks(id),
    current_subtask_path TEXT,
    current_step TEXT DEFAULT 'idle',       -- starting, planning, expanding, execution, verification, idle, done
    mode TEXT DEFAULT 'interactive',        -- autonomous, interactive, paused
    started_at TEXT,
    last_update TEXT,

    -- Evidence & verification (JSON)
    evidence TEXT,                 -- JSON: {filesCreated, filesModified, commitSha, testsPassingBefore, testsPassingAfter}
    verifications_passed TEXT,     -- JSON: {filesCreated, filesNonEmpty, gitChangesExist, testsPass, committed}
    task_memory TEXT,              -- JSON array of temp memories
    applied_memories TEXT,         -- JSON array of memory IDs

    -- Logging
    debug_enabled INTEGER DEFAULT 0,
    session_id TEXT
);

-- Initialize with single row
INSERT INTO state (id) VALUES (1);
```

### Sync Log Table (Native Task Integration)

```sql
CREATE TABLE sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction TEXT NOT NULL,       -- 'push' or 'pull'
    task_id TEXT NOT NULL,         -- taskmanager task ID
    native_task_id TEXT,           -- Claude Code native task ID
    action TEXT NOT NULL,          -- 'created', 'updated', 'completed', 'deleted'
    synced_at TEXT DEFAULT (datetime('now')),
    session_id TEXT,               -- Claude Code session identifier
    details TEXT                   -- JSON for additional sync metadata
);

CREATE INDEX idx_sync_task ON sync_log(task_id);
CREATE INDEX idx_sync_native ON sync_log(native_task_id);
CREATE INDEX idx_sync_session ON sync_log(session_id);
```

## Native Task Sync Design

### Sync Workflow

**Push (session start):**
1. User runs `taskmanager:sync` or starts `taskmanager:run-tasks`
2. Query next N available tasks from SQLite (configurable, default 5)
3. For each task, call `TaskCreate` with:
   - `subject`: Task title
   - `description`: Task description + details
   - `activeForm`: "Working on {title}"
4. Store mapping in `sync_log` (task_id ↔ native_task_id)
5. Set dependencies via `TaskUpdate` with `addBlockedBy`

**Pull (session end or on-demand):**
1. Call `TaskList` to get all native tasks
2. Match against `sync_log` by native_task_id
3. For completed native tasks:
   - Update taskmanager task status to 'done'
   - Set `completed_at` timestamp
   - Run status propagation to ancestors
4. Log the sync event

### Sync Command

```
taskmanager:sync              # Two-way sync (push then pull)
taskmanager:sync --push       # Push tasks to native only
taskmanager:sync --pull       # Pull completions only
taskmanager:sync --status     # Show sync status without acting
taskmanager:sync --clear      # Clear sync mappings (reset)
```

## Status Propagation via SQL

When a leaf task status changes, all ancestors must be recalculated.

### Find Ancestors

```sql
WITH RECURSIVE ancestors AS (
    SELECT id, parent_id FROM tasks WHERE id = :task_id
    UNION ALL
    SELECT t.id, t.parent_id
    FROM tasks t JOIN ancestors a ON t.id = a.parent_id
)
SELECT id FROM ancestors WHERE parent_id IS NOT NULL;
```

### Update Ancestor Status

```sql
UPDATE tasks SET
    status = (
        SELECT CASE
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress')
                THEN 'in-progress'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked')
                THEN 'blocked'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review')
                THEN 'needs-review'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned','draft','paused'))
                THEN 'planned'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done')
                THEN 'done'
            ELSE 'canceled'
        END
    ),
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors WHERE id != :task_id);
```

## Migration Strategy

### Auto-Migration Trigger

When any taskmanager command runs:

```
if exists(.taskmanager/tasks.json) AND NOT exists(.taskmanager/taskmanager.db):
    run_migration()
```

### Migration Steps

1. **Create database** - Initialize `taskmanager.db` with full schema
2. **Migrate tasks.json:**
   - Parse JSON file
   - Flatten recursive subtasks into rows with `parent_id` relationships
   - Preserve all fields, map to appropriate columns
   - Set `archived_at = NULL` for all active tasks
3. **Migrate tasks-archive.json:**
   - Same flattening process
   - Set `archived_at` to original archive timestamp (or file mtime)
4. **Migrate memories.json:**
   - Direct field mapping to memories table
   - Rebuild FTS5 index via triggers
5. **Migrate state.json:**
   - Parse and insert into single-row state table
6. **Backup originals:**
   - Create `.taskmanager/backup-v1/` directory
   - Move all JSON files there
   - Move schemas/ directory there
7. **Log migration:**
   - Write to `decisions.log`: timestamp + "Migrated from JSON v1 to SQLite v2"

### Rollback Support

New command: `taskmanager:rollback`
- Exports current SQLite data back to JSON format (same structure as v1)
- Restores files from `.taskmanager/backup-v1/`
- Removes `taskmanager.db`
- For users who encounter issues or need JSON format

## Command Changes

### Commands Simplified by SQL

| Command | Before | After |
|---------|--------|-------|
| `stats` | 540-line bash/jq script | ~20 SQL queries |
| `get-task` | jq with flatten function | `SELECT * FROM tasks WHERE id = ?` |
| `update-status` | jq recursive update | `UPDATE tasks SET status = ? WHERE id IN (?)` |
| `next-task` | Complex jq priority sort | SQL ORDER BY with dependency subquery |
| `dashboard` | Full file parse + compute | Aggregation queries |
| `migrate-archive` | Copy to archive file, replace with stub | `UPDATE tasks SET archived_at = datetime('now')` |

### Commands with Modified Behavior

| Command | Changes |
|---------|---------|
| `init` | Creates `taskmanager.db` instead of JSON files, initializes schema |
| `plan` | Inserts tasks via SQL transactions, no full-file rewrite |
| `execute-task` | Updates single row, propagation via recursive CTE |
| `run-tasks` | Same logic, faster with SQL queries |
| `memory` | Uses FTS5 for search, SQL for CRUD |

### New Commands

| Command | Purpose |
|---------|---------|
| `sync` | Two-way sync with Claude Code native tasks |
| `rollback` | Revert to JSON format if needed |
| `export` | Export SQLite to JSON for inspection/sharing/portability |

### Removed

- `scripts/task-stats.sh` - Replaced by direct SQL queries
- `schemas/*.json` - SQLite schema is the source of truth

## File Changes Summary

### Files to Create

- `skills/taskmanager/db/schema.sql` - Full database schema
- `skills/taskmanager/db/migrations.sql` - Migration queries
- `skills/taskmanager/db/queries.sql` - Common query templates
- `commands/sync.md` - Native task sync command
- `commands/rollback.md` - Rollback to JSON command
- `commands/export.md` - Export to JSON command

### Files to Modify

- `commands/init.md` - SQLite initialization
- `commands/stats.md` - SQL-based statistics
- `commands/get-task.md` - SQL query
- `commands/update-status.md` - SQL update
- `commands/next-task.md` - SQL with priority/dependency logic
- `commands/dashboard.md` - SQL aggregations
- `commands/execute-task.md` - SQL CRUD + propagation
- `commands/plan.md` - SQL inserts
- `commands/run-tasks.md` - SQL-based task selection
- `commands/memory.md` - SQL + FTS5 search
- `commands/migrate-archive.md` - Simple UPDATE query
- `skills/taskmanager/SKILL.md` - Update data model documentation
- `skills/taskmanager-memory/SKILL.md` - Update for SQL
- `agents/taskmanager.md` - Update data contracts

### Files to Remove

- `scripts/task-stats.sh`
- `skills/taskmanager/template/.taskmanager/tasks.json`
- `skills/taskmanager/template/.taskmanager/tasks-archive.json`
- `skills/taskmanager/template/.taskmanager/memories.json`
- `skills/taskmanager/template/.taskmanager/state.json`
- `skills/taskmanager/template/.taskmanager/schemas/` (entire directory)

## Implementation Phases

### Phase 1: Core SQLite Foundation
- Create database schema files
- Implement database initialization in `init` command
- Implement JSON → SQLite migration logic
- Create backup/rollback mechanism
- Basic CRUD operations for tasks table

### Phase 2: Task Command Migration
- Port `stats` to SQL queries
- Port `get-task` to SQL
- Port `update-status` to SQL with propagation
- Port `next-task` to SQL with priority/dependency logic
- Port `dashboard` to SQL aggregations
- Remove `task-stats.sh` script

### Phase 3: Plan & Execute Migration
- Port `plan` command to SQL inserts
- Port `execute-task` to SQL with full propagation
- Port `run-tasks` to SQL-based workflow
- Port `migrate-archive` to simple UPDATE

### Phase 4: Memory System
- Port memories to SQLite with FTS5
- Update `memory` command for SQL operations
- Implement full-text search
- Update conflict detection for SQL

### Phase 5: Native Task Sync
- Implement `sync` command
- Create `sync_log` table
- Push workflow (taskmanager → native)
- Pull workflow (native → taskmanager)
- Session tracking

### Phase 6: Cleanup & Documentation
- Add `export` command
- Finalize `rollback` command
- Update all skill documentation
- Update agent specification
- Remove deprecated files
- Update plugin.json

## Testing Strategy

### Migration Tests
- Migrate sample projects with various task counts (10, 100, 1000 tasks)
- Verify all data preserved correctly
- Test rollback restores original state

### Query Tests
- Verify stats output matches JSON-based results
- Test status propagation correctness
- Test next-task selection logic

### Sync Tests
- Test push creates correct native tasks
- Test pull updates taskmanager correctly
- Test sync log tracking

### Performance Tests
- Benchmark queries on large datasets (1000+ tasks)
- Compare token usage vs JSON approach
- Measure status propagation time

## Success Criteria

1. **No token limit issues** - Commands work regardless of task count
2. **Correct migration** - All existing data preserved
3. **Faster operations** - Status updates, queries complete quickly
4. **Native integration** - Smooth two-way sync with Claude Code tasks
5. **Rollback safety** - Users can revert if issues arise
