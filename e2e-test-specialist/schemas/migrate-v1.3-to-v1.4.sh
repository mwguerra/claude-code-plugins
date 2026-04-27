#!/usr/bin/env bash
# Migrate v1.3.0 → v1.4.0.
#
# New columns:
#   step_executions.skip_reason          (CHECK enum, NULL allowed)
#   step_executions.fix_attempt_index    (INTEGER NOT NULL DEFAULT 0)
#   test_steps.idempotent                (INTEGER NOT NULL DEFAULT 1, CHECK 0|1)
#   bugs.affected_tests                  (TEXT NOT NULL DEFAULT '[]')
# New tables:
#   test_coverage_links                  (cross-run-coverage citations)
#   notifications                        (outbound dispatch queue)
#   resource_ledger                      (cost / resource accounting)
# New views:
#   v_skip_rollup
#   v_latest_step_status
#   v_latest_test_status
# New index:
#   idx_exec_skip
#
# Idempotent: safe to re-run.

set -euo pipefail
DB="${1:-.e2e-testing/e2e-tests.sqlite}"
[[ -f "$DB" ]] || { echo "error: db not found: $DB" >&2; exit 1; }

current="$(sqlite3 "$DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
case "$current" in
    1.3.0) echo "Migrating $DB from v1.3.0 to v1.4.0..." ;;
    1.4.0) echo "Already at v1.4.0; nothing to do."; exit 0 ;;
    *)     echo "error: unexpected schema version: $current" >&2; exit 1 ;;
esac

# Backup before destructive migration (we use ALTER TABLE which is non-destructive,
# but keep the safety net since CHECK constraints can fail in surprising ways).
mkdir -p "$(dirname "$DB")/_backups"
cp "$DB" "$(dirname "$DB")/_backups/pre-v1.4-migration-$(date -u +%Y%m%dT%H%M%SZ).sqlite"

# Helper — does column already exist? (sqlite3 ALTER TABLE ADD COLUMN is idempotent
# only via this guard; SQLite has no native IF NOT EXISTS for columns.)
column_exists() {
    local table="$1" col="$2"
    sqlite3 "$DB" "PRAGMA table_info('$table');" | awk -F'|' '{print $2}' | grep -qx "$col"
}

# step_executions.skip_reason
if ! column_exists step_executions skip_reason; then
    sqlite3 "$DB" "
        ALTER TABLE step_executions ADD COLUMN skip_reason TEXT
            CHECK (skip_reason IS NULL OR skip_reason IN
                ('needs-infra','cross-run-coverage','future-impl','no-authorization',
                 'dependency-failed','manual-decision','flake-quarantine'));
    "
fi

# step_executions.fix_attempt_index
if ! column_exists step_executions fix_attempt_index; then
    sqlite3 "$DB" "ALTER TABLE step_executions ADD COLUMN fix_attempt_index INTEGER NOT NULL DEFAULT 0;"
fi

# test_steps.idempotent
if ! column_exists test_steps idempotent; then
    sqlite3 "$DB" "ALTER TABLE test_steps ADD COLUMN idempotent INTEGER NOT NULL DEFAULT 1 CHECK (idempotent IN (0,1));"
fi

# bugs.affected_tests
if ! column_exists bugs affected_tests; then
    sqlite3 "$DB" "ALTER TABLE bugs ADD COLUMN affected_tests TEXT NOT NULL DEFAULT '[]';"
fi

# New tables, indices, views.
sqlite3 "$DB" <<'SQL'
BEGIN;

CREATE TABLE IF NOT EXISTS test_coverage_links (
    id                TEXT PRIMARY KEY,
    covered_test_id   TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    covering_test_id  TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    rationale         TEXT,
    declared_in_run   TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    valid_from_run    TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    valid_until_run   TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at        TEXT DEFAULT (datetime('now')),
    updated_at        TEXT DEFAULT (datetime('now')),
    UNIQUE (covered_test_id, covering_test_id)
);

CREATE INDEX IF NOT EXISTS idx_coverage_links_covered
    ON test_coverage_links(covered_test_id, active);
CREATE INDEX IF NOT EXISTS idx_coverage_links_covering
    ON test_coverage_links(covering_test_id, active);

CREATE TABLE IF NOT EXISTS notifications (
    id           TEXT PRIMARY KEY,
    kind         TEXT NOT NULL CHECK (kind IN (
        'run-completed','run-failed','hook-blocking-failed',
        'critical-failure','wall-time-hit','cascade-detected',
        'kill-switch-triggered','manual'
    )),
    severity     TEXT NOT NULL DEFAULT 'info'
                 CHECK (severity IN ('info','warning','critical')),
    title        TEXT NOT NULL,
    body         TEXT,
    related_run  TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    related_test TEXT REFERENCES tests(id) ON DELETE SET NULL,
    related_bug  TEXT REFERENCES bugs(id) ON DELETE SET NULL,
    status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','sent','failed','suppressed')),
    sent_at      TEXT,
    target       TEXT,
    created_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_status
    ON notifications(status, severity, created_at);

CREATE TABLE IF NOT EXISTS resource_ledger (
    id           TEXT PRIMARY KEY,
    run_id       TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    provider     TEXT NOT NULL,
    resource_id  TEXT NOT NULL,
    resource_kind TEXT NOT NULL,
    label        TEXT,
    action       TEXT NOT NULL CHECK (action IN ('created','destroyed','tagged','noted')),
    estimated_cost_cents INTEGER,
    metadata     TEXT NOT NULL DEFAULT '{}',
    created_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_resource_run    ON resource_ledger(run_id, action);
CREATE INDEX IF NOT EXISTS idx_resource_lookup ON resource_ledger(provider, resource_id, action);

CREATE INDEX IF NOT EXISTS idx_exec_skip
    ON step_executions(run_id, skip_reason)
    WHERE skip_reason IS NOT NULL;

DROP VIEW IF EXISTS v_skip_rollup;
CREATE VIEW v_skip_rollup AS
SELECT
    e.run_id,
    COALESCE(e.skip_reason, 'unspecified') AS skip_reason,
    COUNT(DISTINCT e.test_id)              AS test_count,
    COUNT(*)                                AS step_count,
    GROUP_CONCAT(DISTINCT e.test_id)        AS test_ids
FROM step_executions e
WHERE e.status = 'skipped'
GROUP BY e.run_id, COALESCE(e.skip_reason, 'unspecified');

DROP VIEW IF EXISTS v_latest_step_status;
CREATE VIEW v_latest_step_status AS
SELECT run_id, step_id, test_id, status, error_message, completed_at, started_at,
       skip_reason, fix_attempt_index, retry_attempt
FROM step_executions
WHERE id IN (
    SELECT id FROM step_executions
    GROUP BY run_id, step_id
    HAVING MAX(created_at)
);

DROP VIEW IF EXISTS v_latest_test_status;
CREATE VIEW v_latest_test_status AS
SELECT
    run_id,
    test_id,
    CASE
        WHEN SUM(CASE WHEN status='failed' THEN 1 ELSE 0 END)  > 0 THEN 'failed'
        WHEN SUM(CASE WHEN status='blocked' THEN 1 ELSE 0 END) > 0 THEN 'blocked'
        WHEN SUM(CASE WHEN status='skipped' THEN 1 ELSE 0 END) > 0
             AND SUM(CASE WHEN status='passed' THEN 1 ELSE 0 END) = 0 THEN 'skipped'
        WHEN SUM(CASE WHEN status='in-progress' THEN 1 ELSE 0 END) > 0 THEN 'in-progress'
        WHEN SUM(CASE WHEN status='passed' THEN 1 ELSE 0 END) > 0 THEN 'passed'
        ELSE 'pending'
    END AS test_status,
    COUNT(*) AS execution_count
FROM v_latest_step_status
GROUP BY run_id, test_id;

INSERT OR IGNORE INTO schema_version (version) VALUES ('1.4.0');

COMMIT;
SQL

echo "Migration complete: $DB is now at v1.4.0."
