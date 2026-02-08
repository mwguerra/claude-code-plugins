#!/usr/bin/env bash
# migrate-v2-to-v3.sh - Migrate taskmanager from SQLite v2 to v3
#
# Usage: migrate-v2-to-v3.sh [TASKMANAGER_DIR]
#   TASKMANAGER_DIR: Path to .taskmanager directory (default: .taskmanager)
#
# This script:
#   - Backs up the v2 database to backup-v2/
#   - Recreates tasks table without writing domain columns or complexity_score
#   - Recreates state table with simplified columns
#   - Drops sync_log table
#   - Inserts schema version 3.0.0
#   - Consolidates log files into activity.log
#   - Updates config.json to v3.0.0

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

TASKMANAGER_DIR="${1:-.taskmanager}"
DB_FILE="$TASKMANAGER_DIR/taskmanager.db"
BACKUP_DIR="$TASKMANAGER_DIR/backup-v2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ============================================================================
# Prerequisites
# ============================================================================

if ! command -v sqlite3 &>/dev/null; then
    error "sqlite3 is required but not found. Please install it."
    exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
    error "Database not found at $DB_FILE"
    exit 1
fi

# Check current version
CURRENT_VERSION=$(sqlite3 "$DB_FILE" "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null || echo "unknown")
if [[ "$CURRENT_VERSION" != "2.0.0" ]]; then
    error "Expected schema version 2.0.0, found: $CURRENT_VERSION"
    error "This migration only works on v2.0.0 databases."
    exit 1
fi

# ============================================================================
# Backup
# ============================================================================

info "Backing up database to $BACKUP_DIR/"
mkdir -p "$BACKUP_DIR"
cp "$DB_FILE" "$BACKUP_DIR/taskmanager.db.bak"

if [[ -f "$TASKMANAGER_DIR/config.json" ]]; then
    cp "$TASKMANAGER_DIR/config.json" "$BACKUP_DIR/config.json.bak"
fi

for LOG in errors.log decisions.log debug.log; do
    if [[ -f "$TASKMANAGER_DIR/logs/$LOG" ]]; then
        cp "$TASKMANAGER_DIR/logs/$LOG" "$BACKUP_DIR/$LOG.bak"
    fi
done

info "Backup complete."

# ============================================================================
# Migration
# ============================================================================

info "Starting migration v2.0.0 -> v3.0.0..."

sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

-- 1. Recreate tasks table without writing domain columns and complexity_score
CREATE TABLE tasks_new (
    id TEXT PRIMARY KEY,
    parent_id TEXT REFERENCES tasks_new(id) ON DELETE CASCADE,
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
    complexity_scale TEXT CHECK (complexity_scale IN ('XS', 'S', 'M', 'L', 'XL')),
    complexity_reasoning TEXT,
    complexity_expansion_prompt TEXT,
    estimate_seconds INTEGER,
    duration_seconds INTEGER,
    owner TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    archived_at TEXT,
    tags TEXT DEFAULT '[]',
    dependencies TEXT DEFAULT '[]',
    dependency_analysis TEXT,
    meta TEXT DEFAULT '{}'
);

INSERT INTO tasks_new (
    id, parent_id, title, description, details, test_strategy,
    status, type, priority,
    complexity_scale, complexity_reasoning, complexity_expansion_prompt,
    estimate_seconds, duration_seconds, owner,
    created_at, updated_at, started_at, completed_at, archived_at,
    tags, dependencies, dependency_analysis, meta
)
SELECT
    id, parent_id, title, description, details, test_strategy,
    status, type, priority,
    complexity_scale, complexity_reasoning, complexity_expansion_prompt,
    estimate_seconds, duration_seconds, owner,
    created_at, updated_at, started_at, completed_at, archived_at,
    tags, dependencies, dependency_analysis, meta
FROM tasks;

DROP TABLE tasks;
ALTER TABLE tasks_new RENAME TO tasks;

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_id);
CREATE INDEX IF NOT EXISTS idx_tasks_archived ON tasks(archived_at);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

-- 2. Recreate state table with simplified columns
CREATE TABLE state_new (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_task_id TEXT REFERENCES tasks(id),
    task_memory TEXT DEFAULT '[]',
    debug_enabled INTEGER DEFAULT 0,
    session_id TEXT,
    started_at TEXT,
    last_update TEXT
);

INSERT INTO state_new (id, current_task_id, task_memory, debug_enabled, session_id, started_at, last_update)
SELECT id, current_task_id, task_memory, debug_enabled, session_id, started_at, last_update
FROM state;

DROP TABLE state;
ALTER TABLE state_new RENAME TO state;

-- 3. Drop sync_log table
DROP TABLE IF EXISTS sync_log;

-- 4. Insert new schema version
INSERT OR REPLACE INTO schema_version (version) VALUES ('3.0.0');

COMMIT;
PRAGMA foreign_keys = ON;
SQL

info "Database migration complete."

# ============================================================================
# Log file consolidation
# ============================================================================

info "Consolidating log files..."

# Merge existing logs into activity.log
ACTIVITY_LOG="$TASKMANAGER_DIR/logs/activity.log"
touch "$ACTIVITY_LOG"

for LOG in errors.log decisions.log debug.log; do
    if [[ -f "$TASKMANAGER_DIR/logs/$LOG" && -s "$TASKMANAGER_DIR/logs/$LOG" ]]; then
        echo "# --- Migrated from $LOG ---" >> "$ACTIVITY_LOG"
        cat "$TASKMANAGER_DIR/logs/$LOG" >> "$ACTIVITY_LOG"
        echo "" >> "$ACTIVITY_LOG"
    fi
    rm -f "$TASKMANAGER_DIR/logs/$LOG"
done

echo "$(date -Iseconds) [DECISION] [migrate-v2-to-v3] Migrated database from v2.0.0 to v3.0.0" >> "$ACTIVITY_LOG"

info "Logs consolidated into activity.log"

# ============================================================================
# Config update
# ============================================================================

if [[ -f "$TASKMANAGER_DIR/config.json" ]] && command -v python3 &>/dev/null; then
    info "Updating config.json..."
    python3 -c "
import json
with open('$TASKMANAGER_DIR/config.json') as f:
    c = json.load(f)
c['version'] = '3.0.0'
c.get('defaults', {}).pop('domain', None)
with open('$TASKMANAGER_DIR/config.json', 'w') as f:
    json.dump(c, f, indent=2)
    f.write('\n')
"
    info "Config updated."
fi

# ============================================================================
# Verification
# ============================================================================

info "Verifying migration..."

NEW_VERSION=$(sqlite3 "$DB_FILE" "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;")
if [[ "$NEW_VERSION" != "3.0.0" ]]; then
    error "Version check failed: expected 3.0.0, got $NEW_VERSION"
    exit 1
fi

TABLE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('tasks','memories','memories_fts','state','schema_version');")
if [[ "$TABLE_COUNT" != "5" ]]; then
    error "Table count check failed: expected 5, got $TABLE_COUNT"
    exit 1
fi

SYNC_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='sync_log';")
if [[ "$SYNC_EXISTS" != "0" ]]; then
    error "sync_log table still exists after migration"
    exit 1
fi

TASK_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks;")
info "Tasks preserved: $TASK_COUNT"

MEMORY_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM memories;")
info "Memories preserved: $MEMORY_COUNT"

echo ""
info "Migration complete! v2.0.0 -> v3.0.0"
info "Backup saved to: $BACKUP_DIR/"
info ""
info "Changes:"
info "  - Removed writing domain columns (domain, writing_type, content_unit, writing_stage, word counts)"
info "  - Removed complexity_score column (use complexity_scale CASE expression instead)"
info "  - Simplified state table (removed mode, evidence, verifications, applied_memories, etc.)"
info "  - Dropped sync_log table"
info "  - Consolidated logs into activity.log"
info "  - Updated config.json to v3.0.0"
