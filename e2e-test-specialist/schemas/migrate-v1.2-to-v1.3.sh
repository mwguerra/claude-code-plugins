#!/usr/bin/env bash
# Migrate v1.2.0 → v1.3.0.
# New table: lifecycle_hooks  (pre-run / post-run agent instructions for autopilot)
#
# Idempotent: safe to re-run.

set -euo pipefail
DB="${1:-.e2e-testing/e2e-tests.sqlite}"
[[ -f "$DB" ]] || { echo "error: db not found: $DB" >&2; exit 1; }

current="$(sqlite3 "$DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
case "$current" in
    1.2.0) echo "Migrating $DB from v1.2.0 to v1.3.0..." ;;
    1.3.0) echo "Already at v1.3.0; nothing to do."; exit 0 ;;
    *)     echo "error: unexpected schema version: $current" >&2; exit 1 ;;
esac

# Backup before migration (additive only, but keep the safety net).
mkdir -p "$(dirname "$DB")/_backups"
cp "$DB" "$(dirname "$DB")/_backups/pre-v1.3-migration-$(date -u +%Y%m%dT%H%M%SZ).sqlite"

sqlite3 "$DB" <<'SQL'
BEGIN;

CREATE TABLE IF NOT EXISTS lifecycle_hooks (
    id           TEXT PRIMARY KEY,
    phase        TEXT NOT NULL CHECK (phase IN ('pre-run','post-run')),
    title        TEXT NOT NULL,
    body         TEXT NOT NULL,
    enforcement  TEXT NOT NULL DEFAULT 'advisory'
                 CHECK (enforcement IN ('blocking','advisory')),
    active       INTEGER NOT NULL DEFAULT 1,
    order_idx    INTEGER NOT NULL DEFAULT 100,
    source       TEXT,
    created_at   TEXT DEFAULT (datetime('now')),
    updated_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lifecycle_hooks_active
    ON lifecycle_hooks(phase, active, order_idx);

INSERT OR IGNORE INTO schema_version (version) VALUES ('1.3.0');

COMMIT;
SQL

echo "Migration complete: $DB is now at v1.3.0."
