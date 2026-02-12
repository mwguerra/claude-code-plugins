#!/usr/bin/env bash
# migrate-v3-to-v3.1.sh - Migrate taskmanager from SQLite v3.0.0 to v3.1.0
#
# Usage: migrate-v3-to-v3.1.sh [TASKMANAGER_DIR]
#   TASKMANAGER_DIR: Path to .taskmanager directory (default: .taskmanager)
#
# This script:
#   - Backs up the v3.0.0 database to backup-v3/
#   - Creates the deferrals table with FK constraints
#   - Creates indexes for deferrals
#   - Inserts schema version 3.1.0

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

TASKMANAGER_DIR="${1:-.taskmanager}"
DB_FILE="$TASKMANAGER_DIR/taskmanager.db"
BACKUP_DIR="$TASKMANAGER_DIR/backup-v3"

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
if [[ "$CURRENT_VERSION" != "3.0.0" ]]; then
    error "Expected schema version 3.0.0, found: $CURRENT_VERSION"
    error "This migration only works on v3.0.0 databases."
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

info "Starting migration v3.0.0 -> v3.1.0..."

sqlite3 "$DB_FILE" <<'SQL'
PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- 1. Create deferrals table
CREATE TABLE IF NOT EXISTS deferrals (
    id TEXT PRIMARY KEY,
    source_task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE RESTRICT,
    target_task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'applied', 'reassigned', 'canceled')),
    applied_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- 2. Create indexes
CREATE INDEX IF NOT EXISTS idx_deferrals_target ON deferrals(target_task_id, status);
CREATE INDEX IF NOT EXISTS idx_deferrals_source ON deferrals(source_task_id);
CREATE INDEX IF NOT EXISTS idx_deferrals_status ON deferrals(status);

-- 3. Insert new schema version
INSERT OR REPLACE INTO schema_version (version) VALUES ('3.1.0');

COMMIT;
SQL

info "Database migration complete."

# ============================================================================
# Log entry
# ============================================================================

ACTIVITY_LOG="$TASKMANAGER_DIR/logs/activity.log"
if [[ -f "$ACTIVITY_LOG" ]]; then
    echo "$(date -Iseconds) [DECISION] [migrate-v3-to-v3.1] Migrated database from v3.0.0 to v3.1.0 (added deferrals table)" >> "$ACTIVITY_LOG"
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
c['version'] = '3.1.0'
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
if [[ "$NEW_VERSION" != "3.1.0" ]]; then
    error "Version check failed: expected 3.1.0, got $NEW_VERSION"
    exit 1
fi

TABLE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('tasks','memories','memories_fts','state','schema_version','deferrals');")
if [[ "$TABLE_COUNT" != "6" ]]; then
    error "Table count check failed: expected 6, got $TABLE_COUNT"
    exit 1
fi

DEFERRAL_EXISTS=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='deferrals';")
if [[ "$DEFERRAL_EXISTS" != "1" ]]; then
    error "deferrals table was not created"
    exit 1
fi

echo ""
info "Migration complete! v3.0.0 -> v3.1.0"
info "Backup saved to: $BACKUP_DIR/"
info ""
info "Changes:"
info "  - Added deferrals table for tracking deferred work"
info "  - Added indexes for deferral lookups (target, source, status)"
info "  - Updated schema version to 3.1.0"
