# Taskmanager SQLite Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate taskmanager plugin from JSON files to SQLite storage with native task sync.

**Architecture:** Single `taskmanager.db` SQLite database replaces all JSON files (tasks, memories, state, archive). FTS5 provides full-text search for memories. Two-way sync bridges taskmanager with Claude Code's native task system.

**Tech Stack:** SQLite 3 (with FTS5), Bash for commands, SQL for queries

---

## Phase 1: Core SQLite Foundation

### Task 1: Create Database Schema File

**Files:**
- Create: `taskmanager/skills/taskmanager/db/schema.sql`

**Step 1: Create the db directory**

```bash
mkdir -p taskmanager/skills/taskmanager/db
```

**Step 2: Write the complete schema file**

Create `taskmanager/skills/taskmanager/db/schema.sql` with:

```sql
-- Taskmanager SQLite Schema v2.0.0
-- This file defines the complete database structure

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Tasks table (replaces tasks.json and tasks-archive.json)
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    details TEXT,
    test_strategy TEXT,
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('draft', 'planned', 'in-progress', 'blocked', 'paused', 'done', 'canceled', 'duplicate', 'needs-review')),
    type TEXT NOT NULL DEFAULT 'feature'
        CHECK (type IN ('feature', 'bug', 'chore', 'analysis', 'spike')),
    priority TEXT NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    complexity_score INTEGER CHECK (complexity_score BETWEEN 0 AND 5),
    complexity_scale TEXT CHECK (complexity_scale IN ('XS', 'S', 'M', 'L', 'XL')),
    complexity_reasoning TEXT,
    complexity_expansion_prompt TEXT,
    estimate_seconds INTEGER,
    duration_seconds INTEGER,
    owner TEXT,

    -- Writing domain
    domain TEXT DEFAULT 'software' CHECK (domain IN ('software', 'writing')),
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
    archived_at TEXT,

    -- Flexible storage (JSON)
    tags TEXT DEFAULT '[]',
    dependencies TEXT DEFAULT '[]',
    dependency_analysis TEXT,
    meta TEXT DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_id);
CREATE INDEX IF NOT EXISTS idx_tasks_archived ON tasks(archived_at);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

-- Memories table (replaces memories.json)
CREATE TABLE IF NOT EXISTS memories (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    kind TEXT NOT NULL
        CHECK (kind IN ('constraint', 'decision', 'bugfix', 'workaround', 'convention', 'architecture', 'process', 'integration', 'anti-pattern', 'other')),
    why_important TEXT NOT NULL,
    body TEXT NOT NULL,

    -- Ownership
    source_type TEXT NOT NULL CHECK (source_type IN ('user', 'agent', 'command', 'hook', 'other')),
    source_name TEXT,
    source_via TEXT,
    auto_updatable INTEGER DEFAULT 1,

    -- Scoring
    importance INTEGER NOT NULL DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),
    confidence REAL NOT NULL DEFAULT 0.8 CHECK (confidence BETWEEN 0 AND 1),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deprecated', 'superseded', 'draft')),
    superseded_by TEXT REFERENCES memories(id),

    -- Scope (JSON)
    scope TEXT DEFAULT '{}',
    tags TEXT DEFAULT '[]',
    links TEXT DEFAULT '[]',

    -- Usage
    use_count INTEGER DEFAULT 0,
    last_used_at TEXT,
    last_conflict_at TEXT,
    conflict_resolutions TEXT DEFAULT '[]',

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Full-text search for memories
CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
    title, body, tags,
    content='memories',
    content_rowid='rowid'
);

-- FTS sync triggers
CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

-- State table (replaces state.json) - single row
CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_task_id TEXT REFERENCES tasks(id),
    current_subtask_path TEXT,
    current_step TEXT DEFAULT 'idle',
    mode TEXT DEFAULT 'interactive',
    started_at TEXT,
    last_update TEXT,

    -- JSON columns
    evidence TEXT DEFAULT '{}',
    verifications_passed TEXT DEFAULT '{}',
    task_memory TEXT DEFAULT '[]',
    applied_memories TEXT DEFAULT '[]',

    -- Logging
    debug_enabled INTEGER DEFAULT 0,
    session_id TEXT
);

-- Initialize state with single row
INSERT OR IGNORE INTO state (id) VALUES (1);

-- Sync log for native task integration
CREATE TABLE IF NOT EXISTS sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction TEXT NOT NULL CHECK (direction IN ('push', 'pull')),
    task_id TEXT NOT NULL,
    native_task_id TEXT,
    action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'completed', 'deleted')),
    synced_at TEXT DEFAULT (datetime('now')),
    session_id TEXT,
    details TEXT
);

CREATE INDEX IF NOT EXISTS idx_sync_task ON sync_log(task_id);
CREATE INDEX IF NOT EXISTS idx_sync_native ON sync_log(native_task_id);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO schema_version (version) VALUES ('2.0.0');
```

**Step 3: Commit**

```bash
git add taskmanager/skills/taskmanager/db/schema.sql
git commit -m "feat(taskmanager): add SQLite database schema v2.0.0"
```

---

### Task 2: Create Common SQL Queries File

**Files:**
- Create: `taskmanager/skills/taskmanager/db/queries.sql`

**Step 1: Write the queries file**

Create `taskmanager/skills/taskmanager/db/queries.sql` with commonly used queries:

```sql
-- Taskmanager Common SQL Queries
-- Reference file for commands to use via sqlite3

-- ============================================================================
-- TASK QUERIES
-- ============================================================================

-- Get task by ID
-- Usage: sqlite3 .taskmanager/taskmanager.db "SELECT * FROM tasks WHERE id = '1.2.3'"

-- Get all active (non-archived) tasks
-- SELECT * FROM tasks WHERE archived_at IS NULL;

-- Get task with subtasks count
-- SELECT t.*, (SELECT COUNT(*) FROM tasks c WHERE c.parent_id = t.id) as subtask_count
-- FROM tasks t WHERE t.id = ?;

-- Get all descendants of a task (recursive)
-- WITH RECURSIVE descendants AS (
--     SELECT * FROM tasks WHERE id = ?
--     UNION ALL
--     SELECT t.* FROM tasks t JOIN descendants d ON t.parent_id = d.id
-- )
-- SELECT * FROM descendants;

-- Get all ancestors of a task (for status propagation)
-- WITH RECURSIVE ancestors AS (
--     SELECT id, parent_id FROM tasks WHERE id = ?
--     UNION ALL
--     SELECT t.id, t.parent_id FROM tasks t JOIN ancestors a ON t.id = a.parent_id
-- )
-- SELECT id FROM ancestors WHERE id != ?;

-- ============================================================================
-- NEXT TASK SELECTION
-- ============================================================================

-- Find next available task (leaf, not done, dependencies satisfied)
-- WITH done_ids AS (
--     SELECT id FROM tasks
--     WHERE status IN ('done', 'canceled', 'duplicate')
-- )
-- SELECT t.* FROM tasks t
-- WHERE t.archived_at IS NULL
--   AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
--   AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
--   AND (
--       t.dependencies = '[]'
--       OR NOT EXISTS (
--           SELECT 1 FROM json_each(t.dependencies) d
--           WHERE d.value NOT IN (SELECT id FROM done_ids)
--       )
--   )
-- ORDER BY
--     CASE t.priority
--         WHEN 'critical' THEN 0
--         WHEN 'high' THEN 1
--         WHEN 'medium' THEN 2
--         ELSE 3
--     END,
--     COALESCE(t.complexity_score, 3)
-- LIMIT 1;

-- ============================================================================
-- STATISTICS
-- ============================================================================

-- Task counts by status
-- SELECT status, COUNT(*) as count FROM tasks WHERE archived_at IS NULL GROUP BY status;

-- Task counts by priority
-- SELECT priority, COUNT(*) as count FROM tasks WHERE archived_at IS NULL GROUP BY priority;

-- Completion stats
-- SELECT
--     COUNT(*) as total,
--     SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
--     SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END) as in_progress,
--     SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END) as blocked,
--     SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as remaining
-- FROM tasks WHERE archived_at IS NULL;

-- Time remaining (sum of leaf task estimates)
-- SELECT COALESCE(SUM(estimate_seconds), 0) as remaining_seconds
-- FROM tasks
-- WHERE archived_at IS NULL
--   AND status NOT IN ('done', 'canceled', 'duplicate')
--   AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);

-- ============================================================================
-- STATUS PROPAGATION
-- ============================================================================

-- Propagate status to a single parent based on children
-- UPDATE tasks SET
--     status = (
--         SELECT CASE
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress') THEN 'in-progress'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked') THEN 'blocked'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review') THEN 'needs-review'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned', 'draft', 'paused')) THEN 'planned'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done') THEN 'done'
--             ELSE 'canceled'
--         END
--     ),
--     updated_at = datetime('now')
-- WHERE id = ?;

-- ============================================================================
-- MEMORY QUERIES
-- ============================================================================

-- Full-text search in memories
-- SELECT m.* FROM memories m
-- JOIN memories_fts fts ON m.rowid = fts.rowid
-- WHERE memories_fts MATCH ?
-- ORDER BY rank;

-- Get active memories by importance
-- SELECT * FROM memories WHERE status = 'active' AND importance >= 3 ORDER BY importance DESC;

-- ============================================================================
-- ARCHIVAL
-- ============================================================================

-- Archive completed tasks
-- UPDATE tasks SET archived_at = datetime('now'), updated_at = datetime('now')
-- WHERE status IN ('done', 'canceled', 'duplicate') AND archived_at IS NULL;
```

**Step 2: Commit**

```bash
git add taskmanager/skills/taskmanager/db/queries.sql
git commit -m "docs(taskmanager): add common SQL queries reference"
```

---

### Task 3: Create Migration Script

**Files:**
- Create: `taskmanager/skills/taskmanager/db/migrate-v1-to-v2.sh`

**Step 1: Write the migration script**

Create `taskmanager/skills/taskmanager/db/migrate-v1-to-v2.sh`:

```bash
#!/bin/bash
# migrate-v1-to-v2.sh - Migrate taskmanager from JSON (v1) to SQLite (v2)
# Usage: ./migrate-v1-to-v2.sh [.taskmanager directory path]

set -e

TASKMANAGER_DIR="${1:-.taskmanager}"
DB_FILE="$TASKMANAGER_DIR/taskmanager.db"
BACKUP_DIR="$TASKMANAGER_DIR/backup-v1"
SCHEMA_FILE="$(dirname "$0")/schema.sql"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi

    if [[ ! -d "$TASKMANAGER_DIR" ]]; then
        log_error "Directory $TASKMANAGER_DIR does not exist"
        exit 1
    fi

    if [[ -f "$DB_FILE" ]]; then
        log_error "Database $DB_FILE already exists. Migration already completed or in progress."
        exit 1
    fi
}

# Create database with schema
create_database() {
    log_info "Creating database with schema..."

    if [[ ! -f "$SCHEMA_FILE" ]]; then
        log_error "Schema file not found: $SCHEMA_FILE"
        exit 1
    fi

    sqlite3 "$DB_FILE" < "$SCHEMA_FILE"
    log_info "Database created: $DB_FILE"
}

# Migrate tasks from JSON to SQLite
migrate_tasks() {
    local tasks_file="$TASKMANAGER_DIR/tasks.json"

    if [[ ! -f "$tasks_file" ]]; then
        log_warn "No tasks.json found, skipping task migration"
        return
    fi

    log_info "Migrating tasks from $tasks_file..."

    # Flatten tasks recursively and insert into SQLite
    jq -r '
    def flatten_task($parent):
        . as $t |
        {
            id: .id,
            parent_id: $parent,
            title: .title,
            description: .description,
            details: .details,
            test_strategy: .testStrategy,
            status: .status,
            type: .type,
            priority: .priority,
            complexity_score: .complexity.score,
            complexity_scale: .complexity.scale,
            complexity_reasoning: .complexity.reasoning,
            complexity_expansion_prompt: .complexity.expansionPrompt,
            estimate_seconds: .estimateSeconds,
            duration_seconds: .durationSeconds,
            owner: .owner,
            domain: (.domain // "software"),
            writing_type: .writingType,
            content_unit: .contentUnit,
            writing_stage: .writingStage,
            target_word_count: .targetWordCount,
            current_word_count: .currentWordCount,
            created_at: .createdAt,
            updated_at: .updatedAt,
            started_at: .startedAt,
            completed_at: .completedAt,
            archived_at: (if .archivedRef then "migrated" else null end),
            tags: (.tags // []) | tojson,
            dependencies: (.dependencies // []) | tojson,
            dependency_analysis: (.dependencyAnalysis // null) | tojson,
            meta: (.meta // {}) | tojson
        },
        ((.subtasks // [])[] | flatten_task(.id));

    [.tasks[] | flatten_task(null)]
    ' "$tasks_file" | jq -c '.[]' | while read -r task; do
        # Generate SQL INSERT from JSON
        sqlite3 "$DB_FILE" "INSERT INTO tasks (
            id, parent_id, title, description, details, test_strategy,
            status, type, priority, complexity_score, complexity_scale,
            complexity_reasoning, complexity_expansion_prompt,
            estimate_seconds, duration_seconds, owner, domain,
            writing_type, content_unit, writing_stage,
            target_word_count, current_word_count,
            created_at, updated_at, started_at, completed_at, archived_at,
            tags, dependencies, dependency_analysis, meta
        ) VALUES (
            $(echo "$task" | jq -r '.id | @sh'),
            $(echo "$task" | jq -r '.parent_id | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.title | @sh'),
            $(echo "$task" | jq -r '.description | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.details | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.test_strategy | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.status | @sh'),
            $(echo "$task" | jq -r '.type | @sh'),
            $(echo "$task" | jq -r '.priority | @sh'),
            $(echo "$task" | jq -r '.complexity_score | if . then . else "NULL" end'),
            $(echo "$task" | jq -r '.complexity_scale | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.complexity_reasoning | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.complexity_expansion_prompt | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.estimate_seconds | if . then . else "NULL" end'),
            $(echo "$task" | jq -r '.duration_seconds | if . then . else "NULL" end'),
            $(echo "$task" | jq -r '.owner | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.domain | @sh'),
            $(echo "$task" | jq -r '.writing_type | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.content_unit | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.writing_stage | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.target_word_count | if . then . else "NULL" end'),
            $(echo "$task" | jq -r '.current_word_count | if . then . else "NULL" end'),
            $(echo "$task" | jq -r '.created_at | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.updated_at | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.started_at | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.completed_at | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.archived_at | if . then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.tags | @sh'),
            $(echo "$task" | jq -r '.dependencies | @sh'),
            $(echo "$task" | jq -r '.dependency_analysis | if . != "null" then @sh else "NULL" end'),
            $(echo "$task" | jq -r '.meta | @sh')
        );"
    done

    local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks;")
    log_info "Migrated $count tasks"
}

# Migrate archive
migrate_archive() {
    local archive_file="$TASKMANAGER_DIR/tasks-archive.json"

    if [[ ! -f "$archive_file" ]]; then
        log_warn "No tasks-archive.json found, skipping archive migration"
        return
    fi

    log_info "Migrating archive from $archive_file..."

    # Similar to migrate_tasks but sets archived_at
    jq -r '
    [.tasks[] | {
        id: .id,
        parent_id: .parentId,
        title: .title,
        description: .description,
        details: .details,
        test_strategy: .testStrategy,
        status: .status,
        type: .type,
        priority: .priority,
        complexity_score: .complexity.score,
        complexity_scale: .complexity.scale,
        estimate_seconds: .estimateSeconds,
        duration_seconds: .durationSeconds,
        domain: (.domain // "software"),
        created_at: .createdAt,
        updated_at: .updatedAt,
        started_at: .startedAt,
        completed_at: .completedAt,
        archived_at: (.archivedAt // "migrated"),
        tags: (.tags // []) | tojson,
        dependencies: (.dependencies // []) | tojson,
        meta: (.meta // {}) | tojson
    }]
    ' "$archive_file" | jq -c '.[]' | while read -r task; do
        # Skip if already exists (from tasks.json stub)
        local id=$(echo "$task" | jq -r '.id')
        local exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE id = '$id';")

        if [[ "$exists" -gt 0 ]]; then
            # Update the stub with full archive data
            sqlite3 "$DB_FILE" "UPDATE tasks SET
                description = $(echo "$task" | jq -r '.description | if . then @sh else "NULL" end'),
                details = $(echo "$task" | jq -r '.details | if . then @sh else "NULL" end'),
                archived_at = $(echo "$task" | jq -r '.archived_at | @sh')
            WHERE id = '$id';"
        else
            # Insert new archive entry (orphaned archive)
            log_warn "Archived task $id not found in tasks.json, inserting as new"
        fi
    done

    log_info "Archive migration complete"
}

# Migrate memories
migrate_memories() {
    local memories_file="$TASKMANAGER_DIR/memories.json"

    if [[ ! -f "$memories_file" ]]; then
        log_warn "No memories.json found, skipping memories migration"
        return
    fi

    log_info "Migrating memories from $memories_file..."

    jq -c '.memories[]' "$memories_file" | while read -r memory; do
        sqlite3 "$DB_FILE" "INSERT INTO memories (
            id, title, kind, why_important, body,
            source_type, source_name, source_via, auto_updatable,
            importance, confidence, status, superseded_by,
            scope, tags, links,
            use_count, last_used_at, last_conflict_at, conflict_resolutions,
            created_at, updated_at
        ) VALUES (
            $(echo "$memory" | jq -r '.id | @sh'),
            $(echo "$memory" | jq -r '.title | @sh'),
            $(echo "$memory" | jq -r '.kind | @sh'),
            $(echo "$memory" | jq -r '.whyImportant | @sh'),
            $(echo "$memory" | jq -r '.body | @sh'),
            $(echo "$memory" | jq -r '.source.type | @sh'),
            $(echo "$memory" | jq -r '.source.name | if . then @sh else "NULL" end'),
            $(echo "$memory" | jq -r '.source.via | if . then @sh else "NULL" end'),
            $(echo "$memory" | jq -r 'if .source.type == "user" then 0 else 1 end'),
            $(echo "$memory" | jq -r '.importance'),
            $(echo "$memory" | jq -r '.confidence'),
            $(echo "$memory" | jq -r '.status | @sh'),
            $(echo "$memory" | jq -r '.supersededBy | if . then @sh else "NULL" end'),
            $(echo "$memory" | jq -r '.scope | tojson | @sh'),
            $(echo "$memory" | jq -r '.tags | tojson | @sh'),
            $(echo "$memory" | jq -r '(.links // []) | tojson | @sh'),
            $(echo "$memory" | jq -r '.useCount // 0'),
            $(echo "$memory" | jq -r '.lastUsedAt | if . then @sh else "NULL" end'),
            $(echo "$memory" | jq -r '.lastConflictAt | if . then @sh else "NULL" end'),
            $(echo "$memory" | jq -r '(.conflictResolutions // []) | tojson | @sh'),
            $(echo "$memory" | jq -r '.createdAt | @sh'),
            $(echo "$memory" | jq -r '.updatedAt | @sh')
        );"
    done

    local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM memories;")
    log_info "Migrated $count memories"
}

# Migrate state
migrate_state() {
    local state_file="$TASKMANAGER_DIR/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_warn "No state.json found, using defaults"
        return
    fi

    log_info "Migrating state from $state_file..."

    local state=$(cat "$state_file")

    sqlite3 "$DB_FILE" "UPDATE state SET
        current_task_id = $(echo "$state" | jq -r '.currentTaskId | if . then @sh else "NULL" end'),
        current_subtask_path = $(echo "$state" | jq -r '.currentSubtaskPath | if . then @sh else "NULL" end'),
        current_step = $(echo "$state" | jq -r '.currentStep | @sh'),
        mode = $(echo "$state" | jq -r '.mode | @sh'),
        started_at = $(echo "$state" | jq -r '.startedAt | if . then @sh else "NULL" end'),
        last_update = $(echo "$state" | jq -r '.lastUpdate | if . then @sh else "NULL" end'),
        evidence = $(echo "$state" | jq -r '.evidence | tojson | @sh'),
        verifications_passed = $(echo "$state" | jq -r '.verificationsPassed | tojson | @sh'),
        task_memory = $(echo "$state" | jq -r '(.taskMemory // []) | tojson | @sh'),
        applied_memories = $(echo "$state" | jq -r '(.appliedMemories // []) | tojson | @sh'),
        debug_enabled = $(echo "$state" | jq -r 'if .logging.debugEnabled then 1 else 0 end'),
        session_id = $(echo "$state" | jq -r '.logging.sessionId | if . then @sh else "NULL" end')
    WHERE id = 1;"

    log_info "State migration complete"
}

# Backup original files
backup_originals() {
    log_info "Backing up original JSON files to $BACKUP_DIR..."

    mkdir -p "$BACKUP_DIR"

    for file in tasks.json tasks-archive.json memories.json state.json; do
        if [[ -f "$TASKMANAGER_DIR/$file" ]]; then
            mv "$TASKMANAGER_DIR/$file" "$BACKUP_DIR/"
            log_info "Backed up $file"
        fi
    done

    if [[ -d "$TASKMANAGER_DIR/schemas" ]]; then
        mv "$TASKMANAGER_DIR/schemas" "$BACKUP_DIR/"
        log_info "Backed up schemas/"
    fi
}

# Log migration
log_migration() {
    local log_file="$TASKMANAGER_DIR/logs/decisions.log"
    mkdir -p "$(dirname "$log_file")"

    echo "$(date -Iseconds) [DECISION] [migration] Migrated from JSON v1 to SQLite v2" >> "$log_file"
    log_info "Migration logged to $log_file"
}

# Main
main() {
    log_info "Starting taskmanager migration v1 (JSON) -> v2 (SQLite)"
    log_info "Directory: $TASKMANAGER_DIR"

    check_prerequisites
    create_database
    migrate_tasks
    migrate_archive
    migrate_memories
    migrate_state
    backup_originals
    log_migration

    log_info "Migration complete!"
    log_info "Database: $DB_FILE"
    log_info "Backup: $BACKUP_DIR"
}

main "$@"
```

**Step 2: Make the script executable**

```bash
chmod +x taskmanager/skills/taskmanager/db/migrate-v1-to-v2.sh
```

**Step 3: Commit**

```bash
git add taskmanager/skills/taskmanager/db/migrate-v1-to-v2.sh
git commit -m "feat(taskmanager): add JSON to SQLite migration script"
```

---

### Task 4: Update init Command for SQLite

**Files:**
- Modify: `taskmanager/commands/init.md`

**Step 1: Read current init.md**

Read the file to understand current structure.

**Step 2: Rewrite init.md for SQLite**

Replace content with:

```markdown
---
allowed-tools: Bash, Read, Write
description: Initialize a .taskmanager directory in the project if it does not exist
---

# Init Command

You are implementing `taskmanager:init`.

## Purpose

Initialize a new `.taskmanager/` directory with SQLite database for task management.

## Behavior

### 1. Check for existing installation

```bash
if [[ -d ".taskmanager" ]]; then
    if [[ -f ".taskmanager/taskmanager.db" ]]; then
        echo "Taskmanager already initialized (SQLite v2)"
        exit 0
    elif [[ -f ".taskmanager/tasks.json" ]]; then
        echo "Found JSON v1 installation. Run migration."
        # Trigger auto-migration
    fi
fi
```

### 2. Check for JSON files needing migration

If `.taskmanager/tasks.json` exists but `taskmanager.db` does not:
1. Inform user: "Found existing JSON-based taskmanager. Migrating to SQLite..."
2. Run the migration script from the plugin's db/ directory
3. Verify migration succeeded

### 3. Create fresh installation

If no `.taskmanager/` exists:

```bash
# Create directory structure
mkdir -p .taskmanager/logs
mkdir -p .taskmanager/docs

# Create database with schema
sqlite3 .taskmanager/taskmanager.db < "$PLUGIN_DIR/skills/taskmanager/db/schema.sql"

# Create default PRD file
cat > .taskmanager/docs/prd.md << 'EOF'
# Project Requirements Document

## Overview

Describe your project here.

## Features

1. Feature one
2. Feature two

## Technical Requirements

- Requirement one
- Requirement two
EOF

# Initialize empty log files
touch .taskmanager/logs/decisions.log
touch .taskmanager/logs/errors.log
touch .taskmanager/logs/debug.log

# Log initialization
echo "$(date -Iseconds) [DECISION] [init] Initialized taskmanager v2 (SQLite)" >> .taskmanager/logs/decisions.log
```

### 4. Verify installation

```bash
# Check database is valid
sqlite3 .taskmanager/taskmanager.db "SELECT version FROM schema_version;"
# Should output: 2.0.0

# Check tables exist
sqlite3 .taskmanager/taskmanager.db ".tables"
# Should output: memories memories_fts schema_version state sync_log tasks
```

### 5. Report to user

```
Taskmanager initialized successfully!

Created:
  .taskmanager/
  ├── taskmanager.db    # SQLite database (tasks, memories, state)
  ├── docs/
  │   └── prd.md        # Project requirements template
  └── logs/
      ├── decisions.log
      ├── errors.log
      └── debug.log

Next steps:
  1. Edit .taskmanager/docs/prd.md with your project requirements
  2. Run taskmanager:plan to generate tasks from the PRD
  3. Run taskmanager:next-task to see what to work on
```

## Notes

- SQLite WAL mode is enabled for better concurrent access
- The schema enforces data integrity via CHECK constraints
- Full-text search is available for memories via FTS5
```

**Step 3: Commit**

```bash
git add taskmanager/commands/init.md
git commit -m "feat(taskmanager): update init command for SQLite v2"
```

---

### Task 5: Update Template Directory

**Files:**
- Remove: `taskmanager/skills/taskmanager/template/.taskmanager/tasks.json`
- Remove: `taskmanager/skills/taskmanager/template/.taskmanager/tasks-archive.json`
- Remove: `taskmanager/skills/taskmanager/template/.taskmanager/memories.json`
- Remove: `taskmanager/skills/taskmanager/template/.taskmanager/state.json`
- Remove: `taskmanager/skills/taskmanager/template/.taskmanager/schemas/` (directory)

**Step 1: Remove deprecated template files**

```bash
rm -f taskmanager/skills/taskmanager/template/.taskmanager/tasks.json
rm -f taskmanager/skills/taskmanager/template/.taskmanager/tasks-archive.json
rm -f taskmanager/skills/taskmanager/template/.taskmanager/memories.json
rm -f taskmanager/skills/taskmanager/template/.taskmanager/state.json
rm -rf taskmanager/skills/taskmanager/template/.taskmanager/schemas/
```

**Step 2: Update template to just have logs and docs**

The template should now only contain:
```
template/.taskmanager/
├── docs/
│   └── prd.md
└── logs/
    ├── decisions.log
    ├── debug.log
    └── errors.log
```

**Step 3: Commit**

```bash
git add -A taskmanager/skills/taskmanager/template/
git commit -m "refactor(taskmanager): remove JSON template files, SQLite created at runtime"
```

---

## Phase 2: Task Command Migration

### Task 6: Update stats Command

**Files:**
- Modify: `taskmanager/commands/stats.md`

**Step 1: Rewrite stats.md for SQL**

Replace the content to use sqlite3 directly instead of the bash/jq script:

```markdown
---
allowed-tools: Bash
description: Get quick task statistics without loading entire database - saves tokens and context
---

# Task Statistics Command

You are implementing `taskmanager:stats`.

## Purpose

Provides quick, efficient access to task statistics via SQL queries.

## Arguments

- `[mode]` (optional): The type of statistics to retrieve. Defaults to `--summary`.

Available modes:

**Read-only statistics:**
- `--summary` - Full text summary with all statistics
- `--json` - Full JSON output for programmatic use
- `--next` - Next recommended task only
- `--next5` - Next 5 recommended tasks
- `--status` - Task counts by status
- `--priority` - Task counts by priority
- `--levels` - Task counts by level/depth
- `--remaining` - Count of remaining tasks
- `--time` - Estimated time remaining
- `--completion` - Completion statistics

## Behavior

### 1. Verify database exists

```bash
if [[ ! -f ".taskmanager/taskmanager.db" ]]; then
    echo "Error: Taskmanager not initialized. Run taskmanager:init first."
    exit 1
fi
```

### 2. Execute appropriate query based on mode

**--summary (default):**

```bash
echo "=== Task Statistics ==="
echo ""

# Completion stats
sqlite3 -column -header .taskmanager/taskmanager.db "
SELECT
    COUNT(*) as total,
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
    SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END) as in_progress,
    SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END) as blocked,
    SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as remaining,
    ROUND(100.0 * SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) / COUNT(*), 0) as completion_pct
FROM tasks WHERE archived_at IS NULL;
"

echo ""
echo "--- By Status ---"
sqlite3 .taskmanager/taskmanager.db "
SELECT status || ': ' || COUNT(*) FROM tasks
WHERE archived_at IS NULL GROUP BY status ORDER BY status;
"

echo ""
echo "--- By Priority ---"
sqlite3 .taskmanager/taskmanager.db "
SELECT priority || ': ' || COUNT(*) FROM tasks
WHERE archived_at IS NULL GROUP BY priority
ORDER BY CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END;
"

echo ""
echo "--- By Level ---"
sqlite3 .taskmanager/taskmanager.db "
SELECT 'Level ' || (LENGTH(id) - LENGTH(REPLACE(id, '.', '')) + 1) || ': ' || COUNT(*) || ' tasks'
FROM tasks WHERE archived_at IS NULL
GROUP BY (LENGTH(id) - LENGTH(REPLACE(id, '.', '')) + 1)
ORDER BY 1;
"

echo ""
# Time remaining
sqlite3 .taskmanager/taskmanager.db "
SELECT 'Estimated remaining: ' || COALESCE(SUM(estimate_seconds), 0) || ' seconds (' ||
       ROUND(COALESCE(SUM(estimate_seconds), 0) / 3600.0, 1) || ' hours)'
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);
"
```

**--next:**

```bash
echo "=== Next Recommended Task ==="
sqlite3 -column -header .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    'ID: ' || id,
    'Title: ' || title,
    'Status: ' || status,
    'Priority: ' || priority,
    'Complexity: ' || COALESCE(complexity_scale, 'N/A') || ' (' || COALESCE(complexity_score, 'N/A') || ')',
    'Estimate: ' || ROUND(COALESCE(estimate_seconds, 0) / 3600.0, 1) || ' hours'
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
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    COALESCE(t.complexity_score, 3)
LIMIT 1;
"
```

**--next5:**

```bash
echo "=== Next 5 Recommended Tasks ==="
sqlite3 .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    ROW_NUMBER() OVER () || '. [' || id || '] ' || title || ' (' || priority || ', ' || COALESCE(complexity_scale, 'N/A') || ')'
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
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    COALESCE(t.complexity_score, 3)
LIMIT 5;
"
```

**--json:**

```bash
sqlite3 -json .taskmanager/taskmanager.db "
WITH done_ids AS (SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')),
available AS (
    SELECT * FROM tasks t
    WHERE t.archived_at IS NULL
      AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
      AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
      AND (t.dependencies = '[]' OR NOT EXISTS (
          SELECT 1 FROM json_each(t.dependencies) d WHERE d.value NOT IN (SELECT id FROM done_ids)
      ))
    ORDER BY CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
             COALESCE(t.complexity_score, 3)
)
SELECT json_object(
    'summary', (SELECT json_object(
        'total', COUNT(*),
        'done', SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END),
        'in_progress', SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END),
        'blocked', SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END),
        'remaining', SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END)
    ) FROM tasks WHERE archived_at IS NULL),
    'next_task', (SELECT json_object('id', id, 'title', title, 'priority', priority) FROM available LIMIT 1)
);
"
```

## Notes

- All queries run directly via sqlite3, no intermediate scripts needed
- Indexes on status, priority, parent_id ensure fast queries
- JSON output mode uses SQLite's json functions
```

**Step 2: Commit**

```bash
git add taskmanager/commands/stats.md
git commit -m "refactor(taskmanager): rewrite stats command for SQLite"
```

---

### Task 7: Update get-task Command

**Files:**
- Modify: `taskmanager/commands/get-task.md`

**Step 1: Rewrite get-task.md for SQL**

```markdown
---
allowed-tools: Bash
description: Get task details or specific property by ID without loading full database
argument-hint: "<id> [key] | Examples: 1.2.3 | 1.2.3 status | 1.2.3 complexity_scale"
---

# Get Task Command

You are implementing `taskmanager:get-task`.

## Purpose

Retrieve task information by ID efficiently via SQL.

## Arguments

- `$1` (required): The task ID to retrieve
- `$2` (optional): A specific column to extract

## Behavior

### 1. Validate arguments

```bash
if [[ -z "$1" ]]; then
    echo "Usage: taskmanager:get-task <id> [column]"
    echo "Examples:"
    echo "  taskmanager:get-task 1.2.3"
    echo "  taskmanager:get-task 1.2.3 status"
    echo "  taskmanager:get-task 1.2.3 title"
    exit 1
fi
```

### 2. Query the task

**Get full task (no column specified):**

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks WHERE id = '$1';
" | jq '.[0] // empty'
```

If no result, output:
```
Error: Task '$1' not found
```

**Get specific column:**

```bash
sqlite3 .taskmanager/taskmanager.db "
SELECT $2 FROM tasks WHERE id = '$1';
"
```

## Available Columns

| Column | Description |
|--------|-------------|
| `id` | Task ID |
| `title` | Task title |
| `status` | Current status |
| `priority` | Task priority |
| `type` | Task type |
| `description` | Task description |
| `details` | Implementation details |
| `complexity_score` | Complexity score (0-5) |
| `complexity_scale` | Complexity scale (XS-XL) |
| `estimate_seconds` | Estimated time |
| `started_at` | Start timestamp |
| `completed_at` | Completion timestamp |
| `duration_seconds` | Actual duration |
| `dependencies` | JSON array of dependency IDs |
| `parent_id` | Parent task ID |
| `tags` | JSON array of tags |

## Examples

**Get full task:**
```bash
sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM tasks WHERE id = '1.2.3';"
```

**Get task status:**
```bash
sqlite3 .taskmanager/taskmanager.db "SELECT status FROM tasks WHERE id = '1.2.3';"
```

**Get task with subtask count:**
```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT t.*, (SELECT COUNT(*) FROM tasks c WHERE c.parent_id = t.id) as subtask_count
FROM tasks t WHERE t.id = '1.2.3';
"
```

## Notes

- This command is **read-only**
- Uses direct SQL queries, very efficient
- Returns JSON for full task, plain text for single column
```

**Step 2: Commit**

```bash
git add taskmanager/commands/get-task.md
git commit -m "refactor(taskmanager): rewrite get-task command for SQLite"
```

---

### Task 8: Update update-status Command

**Files:**
- Modify: `taskmanager/commands/update-status.md`

**Step 1: Rewrite update-status.md for SQL**

```markdown
---
allowed-tools: Bash
description: Update task status by ID or list of IDs without loading the full database
argument-hint: "<status> <id1> [id2...] | Examples: done 1.2.3 | in-progress 1.2.3 1.2.4"
---

# Update Status Command

You are implementing `taskmanager:update-status`.

## Purpose

Batch update task status via SQL. This command does NOT propagate status to parent tasks - use `execute-task` for that.

## Arguments

- `$1` (required): New status value
- `$2+` (required): One or more task IDs

## Valid Statuses

- `draft`, `planned`, `in-progress`, `blocked`, `paused`, `done`, `canceled`, `duplicate`, `needs-review`

## Behavior

### 1. Validate arguments

```bash
VALID_STATUSES="draft planned in-progress blocked paused done canceled duplicate needs-review"
NEW_STATUS="$1"
shift
TASK_IDS=("$@")

if [[ -z "$NEW_STATUS" ]] || [[ ${#TASK_IDS[@]} -eq 0 ]]; then
    echo "Usage: taskmanager:update-status <status> <id1> [id2...]"
    exit 1
fi

if ! echo "$VALID_STATUSES" | grep -qw "$NEW_STATUS"; then
    echo "Error: Invalid status '$NEW_STATUS'"
    echo "Valid: $VALID_STATUSES"
    exit 1
fi
```

### 2. Build and execute UPDATE query

```bash
# Build ID list for SQL IN clause
ID_LIST=$(printf "'%s'," "${TASK_IDS[@]}" | sed 's/,$//')

# Update with appropriate timestamps
sqlite3 .taskmanager/taskmanager.db "
UPDATE tasks SET
    status = '$NEW_STATUS',
    updated_at = datetime('now'),
    started_at = CASE
        WHEN '$NEW_STATUS' = 'in-progress' AND started_at IS NULL
        THEN datetime('now')
        ELSE started_at
    END,
    completed_at = CASE
        WHEN '$NEW_STATUS' IN ('done', 'canceled', 'duplicate') AND completed_at IS NULL
        THEN datetime('now')
        ELSE completed_at
    END,
    duration_seconds = CASE
        WHEN '$NEW_STATUS' IN ('done', 'canceled', 'duplicate') AND started_at IS NOT NULL
        THEN CAST((julianday(datetime('now')) - julianday(started_at)) * 86400 AS INTEGER)
        ELSE duration_seconds
    END
WHERE id IN ($ID_LIST);
"

# Report results
UPDATED=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE id IN ($ID_LIST) AND status = '$NEW_STATUS';")
echo "Updated $UPDATED task(s) to status '$NEW_STATUS'"
```

### 3. Log the change

```bash
echo "$(date -Iseconds) [DECISION] [update-status] Set status=$NEW_STATUS for tasks: ${TASK_IDS[*]}" >> .taskmanager/logs/decisions.log
```

## Examples

**Mark single task done:**
```bash
sqlite3 .taskmanager/taskmanager.db "UPDATE tasks SET status = 'done', completed_at = datetime('now'), updated_at = datetime('now') WHERE id = '1.2.3';"
```

**Mark multiple tasks in-progress:**
```bash
sqlite3 .taskmanager/taskmanager.db "UPDATE tasks SET status = 'in-progress', started_at = COALESCE(started_at, datetime('now')), updated_at = datetime('now') WHERE id IN ('1.2.3', '1.2.4');"
```

## Notes

- This command does **NOT** propagate status to parent tasks
- Use `taskmanager:execute-task` for proper status propagation
- Timestamps are set automatically based on status transitions
- Changes are logged to decisions.log
```

**Step 2: Commit**

```bash
git add taskmanager/commands/update-status.md
git commit -m "refactor(taskmanager): rewrite update-status command for SQLite"
```

---

### Task 9: Update next-task Command

**Files:**
- Modify: `taskmanager/commands/next-task.md`

**Step 1: Rewrite next-task.md for SQL**

```markdown
---
allowed-tools: Bash
description: Find and display the next task ready for execution based on dependencies and priority
argument-hint: "[--debug]"
---

# Next Task Command

You are implementing `taskmanager:next-task`.

## Purpose

Find the next available task based on:
1. Not already completed (done/canceled/duplicate)
2. Is a leaf task (no subtasks)
3. All dependencies satisfied
4. Sorted by priority (critical > high > medium > low)
5. Then by complexity (lower first)

## Behavior

### 1. Query next available task

```bash
sqlite3 -column -header .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    t.id,
    t.title,
    t.status,
    t.priority,
    t.complexity_scale,
    t.complexity_score,
    ROUND(COALESCE(t.estimate_seconds, 0) / 3600.0, 1) as estimate_hours,
    t.description
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
"
```

### 2. Handle no available tasks

If query returns no results:

```
No available tasks found.

Possible reasons:
- All tasks are completed
- Remaining tasks are blocked by dependencies
- Remaining tasks have subtasks (not leaf tasks)

Run taskmanager:dashboard for full status overview.
```

### 3. Format output

```
=== Next Recommended Task ===

ID: 1.2.3
Title: Implement user authentication
Status: planned
Priority: high
Complexity: M (3)
Estimate: 4 hours

Description:
Add JWT-based authentication with login/logout endpoints...

To start working on this task:
  taskmanager:execute-task 1.2.3
```

## Debug Mode

With `--debug` flag, also show:
- Total tasks checked
- Tasks filtered by each criterion
- Dependency resolution details

## Notes

- Uses SQL subqueries for efficient dependency checking
- json_each() parses the dependencies JSON array
- Results are deterministic (ORDER BY includes id as tiebreaker)
```

**Step 2: Commit**

```bash
git add taskmanager/commands/next-task.md
git commit -m "refactor(taskmanager): rewrite next-task command for SQLite"
```

---

### Task 10: Update dashboard Command

**Files:**
- Modify: `taskmanager/commands/dashboard.md`

**Step 1: Rewrite dashboard.md for SQL**

```markdown
---
allowed-tools: Bash
description: Display task progress dashboard with status counts, completion stats, and critical path
---

# Dashboard Command

You are implementing `taskmanager:dashboard`.

## Purpose

Display a comprehensive progress dashboard using SQL aggregations.

## Behavior

### 1. Header and completion stats

```bash
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    TASKMANAGER DASHBOARD                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    COUNT(*) as 'Total Tasks',
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as 'Done',
    SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END) as 'In Progress',
    SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END) as 'Blocked',
    SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as 'Remaining',
    ROUND(100.0 * SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) / COUNT(*), 1) || '%' as 'Complete'
FROM tasks WHERE archived_at IS NULL;
"
```

### 2. Progress bar

```bash
# Calculate completion percentage
DONE=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'done';")
TOTAL=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL;")
PCT=$((DONE * 100 / TOTAL))
FILLED=$((PCT / 2))
EMPTY=$((50 - FILLED))

echo ""
printf "Progress: ["
printf '█%.0s' $(seq 1 $FILLED)
printf '░%.0s' $(seq 1 $EMPTY)
printf "] %d%%\n" $PCT
echo ""
```

### 3. Status breakdown

```bash
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Status Breakdown                                             │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    status as 'Status',
    COUNT(*) as 'Count',
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL), 1) || '%' as 'Percentage'
FROM tasks
WHERE archived_at IS NULL
GROUP BY status
ORDER BY CASE status
    WHEN 'in-progress' THEN 1
    WHEN 'blocked' THEN 2
    WHEN 'needs-review' THEN 3
    WHEN 'planned' THEN 4
    WHEN 'draft' THEN 5
    WHEN 'done' THEN 6
    ELSE 7
END;
"
```

### 4. Priority breakdown

```bash
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Priority Breakdown                                           │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    priority as 'Priority',
    COUNT(*) as 'Total',
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as 'Done',
    SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as 'Remaining'
FROM tasks
WHERE archived_at IS NULL
GROUP BY priority
ORDER BY CASE priority
    WHEN 'critical' THEN 0
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2
    ELSE 3
END;
"
```

### 5. Time estimates

```bash
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Time Estimates                                               │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
SELECT
    ROUND(COALESCE(SUM(CASE WHEN status = 'done' THEN duration_seconds ELSE 0 END), 0) / 3600.0, 1) as 'Completed (hrs)',
    ROUND(COALESCE(SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN estimate_seconds ELSE 0 END), 0) / 3600.0, 1) as 'Remaining (hrs)',
    ROUND(COALESCE(SUM(estimate_seconds), 0) / 3600.0, 1) as 'Total Estimated (hrs)'
FROM tasks
WHERE archived_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);
"
```

### 6. Next tasks

```bash
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ Next Up                                                      │"
echo "└─────────────────────────────────────────────────────────────┘"

sqlite3 -box .taskmanager/taskmanager.db "
WITH done_ids AS (
    SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT
    t.id as 'ID',
    SUBSTR(t.title, 1, 40) as 'Title',
    t.priority as 'Priority',
    t.complexity_scale as 'Size',
    ROUND(COALESCE(t.estimate_seconds, 0) / 3600.0, 1) || 'h' as 'Est'
FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (t.dependencies = '[]' OR NOT EXISTS (
      SELECT 1 FROM json_each(t.dependencies) d WHERE d.value NOT IN (SELECT id FROM done_ids)
  ))
ORDER BY
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    COALESCE(t.complexity_score, 3)
LIMIT 5;
"
```

### 7. Writing domain (if applicable)

```bash
# Check if any writing tasks exist
WRITING_COUNT=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE domain = 'writing' AND archived_at IS NULL;")

if [[ "$WRITING_COUNT" -gt 0 ]]; then
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Writing Progress                                            │"
    echo "└─────────────────────────────────────────────────────────────┘"

    sqlite3 -box .taskmanager/taskmanager.db "
    SELECT
        writing_stage as 'Stage',
        COUNT(*) as 'Tasks',
        SUM(COALESCE(target_word_count, 0)) as 'Target Words',
        SUM(COALESCE(current_word_count, 0)) as 'Current Words'
    FROM tasks
    WHERE domain = 'writing' AND archived_at IS NULL
    GROUP BY writing_stage
    ORDER BY CASE writing_stage
        WHEN 'idea' THEN 1
        WHEN 'outline' THEN 2
        WHEN 'research' THEN 3
        WHEN 'draft' THEN 4
        WHEN 'rewrite' THEN 5
        WHEN 'edit' THEN 6
        WHEN 'copyedit' THEN 7
        WHEN 'proofread' THEN 8
        WHEN 'ready-to-publish' THEN 9
        WHEN 'published' THEN 10
        ELSE 11
    END;
    "
fi
```

## Notes

- Uses SQLite's -box format for pretty tables
- All calculations done in SQL for efficiency
- Writing section only shown if writing tasks exist
```

**Step 2: Commit**

```bash
git add taskmanager/commands/dashboard.md
git commit -m "refactor(taskmanager): rewrite dashboard command for SQLite"
```

---

### Task 11: Remove task-stats.sh Script

**Files:**
- Remove: `taskmanager/scripts/task-stats.sh`

**Step 1: Remove the script**

```bash
rm taskmanager/scripts/task-stats.sh
rmdir taskmanager/scripts 2>/dev/null || true
```

**Step 2: Commit**

```bash
git add -A taskmanager/scripts/
git commit -m "refactor(taskmanager): remove task-stats.sh, replaced by SQL queries"
```

---

## Phase 3: Plan & Execute Migration

### Task 12: Update plan Command

**Files:**
- Modify: `taskmanager/commands/plan.md`

**Step 1: Rewrite plan.md for SQL inserts**

The plan command needs to INSERT tasks into SQLite instead of writing JSON. Key changes:

1. Parse PRD content (same as before)
2. Generate tasks with the taskmanager skill (same as before)
3. INSERT tasks via SQL instead of writing JSON file
4. Use transactions for atomicity

Add this SQL insertion pattern to the command:

```bash
# Insert a task
sqlite3 .taskmanager/taskmanager.db "
INSERT INTO tasks (id, parent_id, title, description, status, type, priority, complexity_score, complexity_scale, estimate_seconds, tags, dependencies)
VALUES ('1.2.3', '1.2', 'Task title', 'Description', 'planned', 'feature', 'high', 3, 'M', 7200, '[]', '[]');
"

# Insert multiple tasks in a transaction
sqlite3 .taskmanager/taskmanager.db "
BEGIN TRANSACTION;
INSERT INTO tasks (...) VALUES (...);
INSERT INTO tasks (...) VALUES (...);
INSERT INTO tasks (...) VALUES (...);
COMMIT;
"
```

**Step 2: Commit**

```bash
git add taskmanager/commands/plan.md
git commit -m "refactor(taskmanager): update plan command for SQLite inserts"
```

---

### Task 13: Update execute-task Command

**Files:**
- Modify: `taskmanager/commands/execute-task.md`

**Step 1: Update execute-task.md for SQL**

Key changes needed:

1. Load task via SQL instead of JSON parse
2. Check dependencies via SQL
3. Update status via SQL
4. Status propagation via recursive CTE

Add these SQL patterns:

```bash
# Load task
TASK=$(sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM tasks WHERE id = '$TASK_ID';" | jq '.[0]')

# Check dependencies
UNMET=$(sqlite3 .taskmanager/taskmanager.db "
SELECT d.value FROM tasks t, json_each(t.dependencies) d
WHERE t.id = '$TASK_ID'
  AND d.value NOT IN (SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate'));
")

# Update status with propagation
sqlite3 .taskmanager/taskmanager.db "
-- Update the leaf task
UPDATE tasks SET status = 'done', completed_at = datetime('now'), updated_at = datetime('now')
WHERE id = '$TASK_ID';

-- Propagate to ancestors
WITH RECURSIVE ancestors AS (
    SELECT parent_id as id FROM tasks WHERE id = '$TASK_ID' AND parent_id IS NOT NULL
    UNION ALL
    SELECT t.parent_id FROM tasks t JOIN ancestors a ON t.id = a.id WHERE t.parent_id IS NOT NULL
)
UPDATE tasks SET
    status = (
        SELECT CASE
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress') THEN 'in-progress'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked') THEN 'blocked'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review') THEN 'needs-review'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned', 'draft', 'paused')) THEN 'planned'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done') THEN 'done'
            ELSE 'canceled'
        END
    ),
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors);
"
```

**Step 2: Commit**

```bash
git add taskmanager/commands/execute-task.md
git commit -m "refactor(taskmanager): update execute-task command for SQLite with propagation"
```

---

### Task 14: Update run-tasks Command

**Files:**
- Modify: `taskmanager/commands/run-tasks.md`

**Step 1: Update run-tasks.md for SQL**

Similar to execute-task, but for batch execution. The main loop remains the same, but task selection and status updates use SQL.

**Step 2: Commit**

```bash
git add taskmanager/commands/run-tasks.md
git commit -m "refactor(taskmanager): update run-tasks command for SQLite"
```

---

### Task 15: Update migrate-archive Command

**Files:**
- Modify: `taskmanager/commands/migrate-archive.md`

**Step 1: Simplify migrate-archive.md**

With SQLite, archiving is just setting a timestamp:

```markdown
---
allowed-tools: Bash
description: Archive existing completed tasks to reduce active task count
argument-hint: "[--dry-run]"
---

# Migrate Archive Command

You are implementing `taskmanager:migrate-archive`.

## Purpose

Mark completed tasks as archived. In SQLite, this sets the `archived_at` timestamp rather than moving to a separate file.

## Behavior

### 1. Dry run mode

```bash
if [[ "$1" == "--dry-run" ]]; then
    echo "=== Dry Run - Tasks that would be archived ==="
    sqlite3 -box .taskmanager/taskmanager.db "
    SELECT id, title, status, completed_at
    FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
      AND archived_at IS NULL
    ORDER BY completed_at;
    "

    COUNT=$(sqlite3 .taskmanager/taskmanager.db "SELECT COUNT(*) FROM tasks WHERE status IN ('done', 'canceled', 'duplicate') AND archived_at IS NULL;")
    echo ""
    echo "Would archive $COUNT tasks"
    exit 0
fi
```

### 2. Archive completed tasks

```bash
sqlite3 .taskmanager/taskmanager.db "
UPDATE tasks
SET archived_at = datetime('now'), updated_at = datetime('now')
WHERE status IN ('done', 'canceled', 'duplicate')
  AND archived_at IS NULL;
"

COUNT=$(sqlite3 .taskmanager/taskmanager.db "SELECT changes();")
echo "Archived $COUNT tasks"
```

### 3. Log the action

```bash
echo "$(date -Iseconds) [DECISION] [migrate-archive] Archived $COUNT completed tasks" >> .taskmanager/logs/decisions.log
```

## Notes

- Archived tasks remain in the database but are filtered out of most queries
- Use `WHERE archived_at IS NULL` to exclude archived tasks
- Much simpler than JSON approach (no file splitting needed)
```

**Step 2: Commit**

```bash
git add taskmanager/commands/migrate-archive.md
git commit -m "refactor(taskmanager): simplify migrate-archive for SQLite"
```

---

## Phase 4: Memory System

### Task 16: Update memory Command

**Files:**
- Modify: `taskmanager/commands/memory.md`

**Step 1: Rewrite memory.md for SQL with FTS5**

Key additions:

```bash
# Full-text search
sqlite3 -json .taskmanager/taskmanager.db "
SELECT m.* FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH '$SEARCH_TERM'
ORDER BY rank
LIMIT 10;
"

# Add memory
sqlite3 .taskmanager/taskmanager.db "
INSERT INTO memories (id, title, kind, why_important, body, source_type, importance, status, scope, tags)
VALUES ('M-0001', 'Memory title', 'decision', 'Why this matters', 'Full body text', 'user', 4, 'active', '{}', '[]');
"

# List active memories
sqlite3 -box .taskmanager/taskmanager.db "
SELECT id, title, kind, importance, status
FROM memories
WHERE status = 'active'
ORDER BY importance DESC, created_at DESC;
"
```

**Step 2: Commit**

```bash
git add taskmanager/commands/memory.md
git commit -m "refactor(taskmanager): update memory command for SQLite with FTS5 search"
```

---

### Task 17: Update taskmanager-memory Skill

**Files:**
- Modify: `taskmanager/skills/taskmanager-memory/SKILL.md`

**Step 1: Update skill for SQL operations**

Update all JSON references to SQL patterns. The conflict detection and resolution logic remains the same, just the storage mechanism changes.

**Step 2: Commit**

```bash
git add taskmanager/skills/taskmanager-memory/SKILL.md
git commit -m "refactor(taskmanager): update taskmanager-memory skill for SQLite"
```

---

## Phase 5: Native Task Sync

### Task 18: Create sync Command

**Files:**
- Create: `taskmanager/commands/sync.md`

**Step 1: Write sync.md**

```markdown
---
allowed-tools: Bash, TaskCreate, TaskList, TaskUpdate
description: Two-way sync with Claude Code native tasks
argument-hint: "[--push | --pull | --status | --clear]"
---

# Sync Command

You are implementing `taskmanager:sync`.

## Purpose

Synchronize taskmanager tasks with Claude Code's native task system for session-based tracking.

## Arguments

- `--push` - Push taskmanager tasks to native task list
- `--pull` - Pull completed native tasks back to taskmanager
- `--status` - Show sync status without making changes
- `--clear` - Clear sync mappings
- (no args) - Two-way sync (push then pull)

## Behavior

### Push Workflow

1. Query next N available tasks from taskmanager:

```bash
sqlite3 -json .taskmanager/taskmanager.db "
WITH done_ids AS (SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate'))
SELECT id, title, description, priority, complexity_scale, estimate_seconds
FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (t.dependencies = '[]' OR NOT EXISTS (
      SELECT 1 FROM json_each(t.dependencies) d WHERE d.value NOT IN (SELECT id FROM done_ids)
  ))
ORDER BY CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END
LIMIT 5;
"
```

2. For each task, use TaskCreate:

```
TaskCreate with:
  subject: [task.title]
  description: [task.description]
  activeForm: "Working on [task.title]"
```

3. Log the sync mapping:

```bash
sqlite3 .taskmanager/taskmanager.db "
INSERT INTO sync_log (direction, task_id, native_task_id, action, session_id)
VALUES ('push', '$TASK_ID', '$NATIVE_TASK_ID', 'created', '$SESSION_ID');
"
```

### Pull Workflow

1. Call TaskList to get all native tasks
2. Match against sync_log by native_task_id
3. For completed native tasks:

```bash
sqlite3 .taskmanager/taskmanager.db "
-- Update taskmanager task
UPDATE tasks SET
    status = 'done',
    completed_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = '$TASK_ID';

-- Log the sync
INSERT INTO sync_log (direction, task_id, native_task_id, action, session_id)
VALUES ('pull', '$TASK_ID', '$NATIVE_TASK_ID', 'completed', '$SESSION_ID');
"
```

4. Run status propagation for each completed task

### Status Mode

```bash
echo "=== Sync Status ==="

# Tasks pushed this session
sqlite3 -box .taskmanager/taskmanager.db "
SELECT task_id, native_task_id, action, synced_at
FROM sync_log
WHERE direction = 'push'
ORDER BY synced_at DESC
LIMIT 10;
"

# Tasks pulled this session
sqlite3 -box .taskmanager/taskmanager.db "
SELECT task_id, native_task_id, action, synced_at
FROM sync_log
WHERE direction = 'pull'
ORDER BY synced_at DESC
LIMIT 10;
"
```

### Clear Mode

```bash
sqlite3 .taskmanager/taskmanager.db "DELETE FROM sync_log;"
echo "Sync mappings cleared"
```

## Notes

- Sync is session-scoped - mappings track which tasks were pushed in this session
- Native tasks are ephemeral; taskmanager tasks are persistent
- Push creates native tasks for tracking; pull captures completions
```

**Step 2: Commit**

```bash
git add taskmanager/commands/sync.md
git commit -m "feat(taskmanager): add sync command for native task integration"
```

---

## Phase 6: Cleanup & Documentation

### Task 19: Create export Command

**Files:**
- Create: `taskmanager/commands/export.md`

**Step 1: Write export.md**

```markdown
---
allowed-tools: Bash
description: Export SQLite database to JSON for inspection or sharing
argument-hint: "[--tasks | --memories | --all] [output-file]"
---

# Export Command

You are implementing `taskmanager:export`.

## Purpose

Export taskmanager data to JSON format for inspection, sharing, or backup.

## Arguments

- `--tasks` - Export tasks only
- `--memories` - Export memories only
- `--all` - Export everything (default)
- `[output-file]` - Output file path (default: stdout)

## Behavior

### Export tasks

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks ORDER BY id;
" | jq '{
    version: "2.0.0",
    exported_at: (now | todate),
    tasks: .
}'
```

### Export memories

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM memories ORDER BY id;
" | jq '{
    version: "2.0.0",
    exported_at: (now | todate),
    memories: .
}'
```

### Export all

```bash
{
    echo '{"version": "2.0.0", "exported_at": "'$(date -Iseconds)'",'
    echo '"tasks": '
    sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM tasks ORDER BY id;"
    echo ','
    echo '"memories": '
    sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM memories ORDER BY id;"
    echo ','
    echo '"state": '
    sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM state;"
    echo '}'
} | jq '.'
```

## Notes

- Useful for debugging, sharing project state, or creating backups
- Output is valid JSON that could be re-imported if needed
```

**Step 2: Commit**

```bash
git add taskmanager/commands/export.md
git commit -m "feat(taskmanager): add export command for JSON output"
```

---

### Task 20: Create rollback Command

**Files:**
- Create: `taskmanager/commands/rollback.md`

**Step 1: Write rollback.md**

```markdown
---
allowed-tools: Bash
description: Revert to JSON format if SQLite migration caused issues
---

# Rollback Command

You are implementing `taskmanager:rollback`.

## Purpose

Revert from SQLite back to JSON format. This restores the backup created during migration.

## Behavior

### 1. Check for backup

```bash
if [[ ! -d ".taskmanager/backup-v1" ]]; then
    echo "Error: No backup found at .taskmanager/backup-v1"
    echo "Rollback is only possible if you migrated from JSON v1"
    exit 1
fi
```

### 2. Confirm with user

```
WARNING: This will:
1. Delete the current SQLite database
2. Restore JSON files from backup
3. Restore the schemas directory

Are you sure? (yes/no)
```

### 3. Perform rollback

```bash
# Remove SQLite database
rm -f .taskmanager/taskmanager.db

# Restore JSON files
cp .taskmanager/backup-v1/*.json .taskmanager/

# Restore schemas if present
if [[ -d ".taskmanager/backup-v1/schemas" ]]; then
    cp -r .taskmanager/backup-v1/schemas .taskmanager/
fi

# Log rollback
echo "$(date -Iseconds) [DECISION] [rollback] Reverted from SQLite v2 to JSON v1" >> .taskmanager/logs/decisions.log
```

### 4. Report

```
Rollback complete. Restored:
- tasks.json
- tasks-archive.json
- memories.json
- state.json
- schemas/

The backup remains at .taskmanager/backup-v1 for safety.
```

## Notes

- Only available if migration backup exists
- Does NOT export current SQLite data - use `export` command first if needed
- Backup is preserved after rollback for safety
```

**Step 2: Commit**

```bash
git add taskmanager/commands/rollback.md
git commit -m "feat(taskmanager): add rollback command for SQLite reversion"
```

---

### Task 21: Update Main SKILL.md

**Files:**
- Modify: `taskmanager/skills/taskmanager/SKILL.md`

**Step 1: Update skill documentation for SQLite**

Major sections to update:
1. Data model section - describe SQLite tables instead of JSON structure
2. Query examples - SQL instead of jq
3. Status propagation - recursive CTE instead of JSON tree walking
4. Remove references to task-stats.sh script

**Step 2: Commit**

```bash
git add taskmanager/skills/taskmanager/SKILL.md
git commit -m "docs(taskmanager): update main skill documentation for SQLite v2"
```

---

### Task 22: Update Agent Specification

**Files:**
- Modify: `taskmanager/agents/taskmanager.md`

**Step 1: Update agent spec for SQLite**

Update the data contracts section to reflect SQLite schema instead of JSON structures.

**Step 2: Commit**

```bash
git add taskmanager/agents/taskmanager.md
git commit -m "docs(taskmanager): update agent specification for SQLite v2"
```

---

### Task 23: Update plugin.json

**Files:**
- Modify: `taskmanager/.claude-plugin/plugin.json`

**Step 1: Update plugin metadata**

- Bump version to 2.0.0
- Update description to mention SQLite
- Add new commands (sync, export, rollback)

**Step 2: Commit**

```bash
git add taskmanager/.claude-plugin/plugin.json
git commit -m "chore(taskmanager): bump version to 2.0.0 for SQLite release"
```

---

### Task 24: Final Integration Test

**Step 1: Test fresh initialization**

```bash
cd /tmp
mkdir test-project && cd test-project
# Run init command and verify database created
```

**Step 2: Test migration from JSON**

```bash
# Create mock JSON files
# Run init to trigger migration
# Verify data migrated correctly
```

**Step 3: Test all commands**

```bash
# stats, get-task, update-status, next-task, dashboard
# plan, execute-task
# memory commands
# sync, export, rollback
```

**Step 4: Commit any fixes**

---

### Task 25: Merge to Main

**Step 1: Ensure all tests pass**

**Step 2: Create PR or merge directly**

```bash
git checkout main
git merge feature/taskmanager-sqlite-refactor
git push origin main
```

**Step 3: Clean up worktree**

```bash
git worktree remove .worktrees/taskmanager-sqlite
git branch -d feature/taskmanager-sqlite-refactor
```

---

## Summary

**Total tasks:** 25
**Estimated effort:** ~4-6 hours of implementation time

**Key files created:**
- `db/schema.sql` - Complete SQLite schema
- `db/queries.sql` - Common query reference
- `db/migrate-v1-to-v2.sh` - Migration script
- `commands/sync.md` - Native task sync
- `commands/export.md` - JSON export
- `commands/rollback.md` - Revert to JSON

**Key files modified:**
- All 11 existing commands updated for SQL
- Both skills updated for SQL
- Agent spec updated
- Plugin.json version bump

**Files removed:**
- `scripts/task-stats.sh`
- Template JSON files
- Template schemas directory
