#!/usr/bin/env bash
# migrate-v3.1-to-v4.sh - Migrate taskmanager from SQLite v3.1.0 to v4.0.0
#
# Usage: migrate-v3.1-to-v4.sh [TASKMANAGER_DIR]
#   TASKMANAGER_DIR: Path to .taskmanager directory (default: .taskmanager)
#
# This script:
#   - Backs up the v3.1.0 database to backup-v3.1/
#   - Creates milestones table
#   - Creates plan_analyses table
#   - Adds 5 new columns to tasks table (milestone_id, acceptance_criteria, moscow, business_value, dependency_types)
#   - Creates 4 new indexes
#   - Inserts schema version 4.0.0

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

TASKMANAGER_DIR="${1:-.taskmanager}"
DB_FILE="$TASKMANAGER_DIR/taskmanager.db"
BACKUP_DIR="$TASKMANAGER_DIR/backup-v3.1"

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
if [[ "$CURRENT_VERSION" != "3.1.0" ]]; then
    error "Expected schema version 3.1.0, found: $CURRENT_VERSION"
    error "This migration only works on v3.1.0 databases."
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

info "Backup complete."

# ============================================================================
# Migration
# ============================================================================

info "Starting migration v3.1.0 -> v4.0.0..."

sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- 1. Create milestones table
CREATE TABLE IF NOT EXISTS milestones (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    acceptance_criteria TEXT DEFAULT '[]',
    target_date TEXT,
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned', 'active', 'completed', 'canceled')),
    phase_order INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- 2. Create plan_analyses table
CREATE TABLE IF NOT EXISTS plan_analyses (
    id TEXT PRIMARY KEY,
    prd_source TEXT NOT NULL,
    prd_hash TEXT,
    tech_stack TEXT DEFAULT '[]',
    assumptions TEXT DEFAULT '[]',
    risks TEXT DEFAULT '[]',
    ambiguities TEXT DEFAULT '[]',
    nfrs TEXT DEFAULT '[]',
    scope_in TEXT,
    scope_out TEXT,
    cross_cutting TEXT DEFAULT '[]',
    decisions TEXT DEFAULT '[]',
    milestone_ids TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- 3. Add new columns to tasks table
ALTER TABLE tasks ADD COLUMN milestone_id TEXT REFERENCES milestones(id);
ALTER TABLE tasks ADD COLUMN acceptance_criteria TEXT DEFAULT '[]';
ALTER TABLE tasks ADD COLUMN moscow TEXT CHECK (moscow IN ('must', 'should', 'could', 'wont'));
ALTER TABLE tasks ADD COLUMN business_value INTEGER CHECK (business_value BETWEEN 1 AND 5);
ALTER TABLE tasks ADD COLUMN dependency_types TEXT DEFAULT '{}';

-- 4. Create new indexes
CREATE INDEX IF NOT EXISTS idx_milestones_status ON milestones(status);
CREATE INDEX IF NOT EXISTS idx_milestones_order ON milestones(phase_order);
CREATE INDEX IF NOT EXISTS idx_plan_analyses_hash ON plan_analyses(prd_hash);
CREATE INDEX IF NOT EXISTS idx_tasks_milestone ON tasks(milestone_id);

-- 5. Insert new schema version
INSERT OR REPLACE INTO schema_version (version) VALUES ('4.0.0');

COMMIT;
SQL

info "Database migration complete."

# ============================================================================
# Log entry
# ============================================================================

ACTIVITY_LOG="$TASKMANAGER_DIR/logs/activity.log"
if [[ -f "$ACTIVITY_LOG" ]]; then
    echo "$(date -Iseconds) [DECISION] [migrate-v3.1-to-v4] Migrated database from v3.1.0 to v4.0.0 (added milestones, plan_analyses, task enhancements)" >> "$ACTIVITY_LOG"
fi

# ============================================================================
# Config update
# ============================================================================

if [[ -f "$TASKMANAGER_DIR/config.json" ]] && command -v python3 &>/dev/null; then
    info "Updating config.json..."
    python3 -c "
import json
with open('$TASKMANAGER_DIR/config.json') as f:
    c = json.load(f)
c['version'] = '4.0.0'
c.setdefault('defaults', {})['moscow'] = 'must'
c['planning'] = {
    'require_prd_analysis': True,
    'ask_macro_questions': True
}
c['milestones'] = {
    'execution_mode': 'flexible'
}
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
if [[ "$NEW_VERSION" != "4.0.0" ]]; then
    error "Version check failed: expected 4.0.0, got $NEW_VERSION"
    exit 1
fi

TABLE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('tasks','memories','memories_fts','state','schema_version','deferrals','milestones','plan_analyses');")
if [[ "$TABLE_COUNT" != "8" ]]; then
    error "Table count check failed: expected 8, got $TABLE_COUNT"
    exit 1
fi

# Verify new columns on tasks
for COL in milestone_id acceptance_criteria moscow business_value dependency_types; do
    EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name = '$COL';")
    if [[ "$EXISTS" != "1" ]]; then
        error "Column '$COL' not found on tasks table"
        exit 1
    fi
done

# Verify new indexes
for IDX in idx_milestones_status idx_milestones_order idx_plan_analyses_hash idx_tasks_milestone; do
    EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='$IDX';")
    if [[ "$EXISTS" != "1" ]]; then
        error "Index '$IDX' not found"
        exit 1
    fi
done

echo ""
info "Migration complete! v3.1.0 -> v4.0.0"
info "Backup saved to: $BACKUP_DIR/"
info ""
info "Changes:"
info "  - Added milestones table (delivery phases with MoSCoW grouping)"
info "  - Added plan_analyses table (PRD analysis artifacts)"
info "  - Added tasks.milestone_id (FK to milestones)"
info "  - Added tasks.acceptance_criteria (JSON, product-view done criteria)"
info "  - Added tasks.moscow (must/should/could/wont classification)"
info "  - Added tasks.business_value (1-5 scale)"
info "  - Added tasks.dependency_types (JSON, hard/soft/informational)"
info "  - Added 4 new indexes"
info "  - Updated schema version to 4.0.0"
