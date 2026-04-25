#!/usr/bin/env bash
# Migrate v1.1.0 → v1.2.0.
# New tables: roles, integrations, sites, step_assertions, assertion_results,
#             test_dependencies, coverage_targets, coverage_hits, directive_violations.
# New columns: step_executions.metrics (default '{}').
# Real FK on step_executions.bug_id (was soft) — applied via table rebuild.
# New status value 'planned' on test_runs (CHECK rebuild).
# Three triggers + four views.
#
# Idempotent: safe to re-run.

set -euo pipefail
DB="${1:-.e2e-testing/e2e-tests.sqlite}"
[[ -f "$DB" ]] || { echo "error: db not found: $DB" >&2; exit 1; }

current="$(sqlite3 "$DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
case "$current" in
    1.1.0) echo "Migrating $DB from v1.1.0 to v1.2.0..." ;;
    1.2.0) echo "Already at v1.2.0; nothing to do."; exit 0 ;;
    *)     echo "error: unexpected schema version: $current" >&2; exit 1 ;;
esac

# Backup before destructive migration
mkdir -p "$(dirname "$DB")/_backups"
cp "$DB" "$(dirname "$DB")/_backups/pre-v1.2-migration-$(date -u +%Y%m%dT%H%M%SZ).sqlite"

sqlite3 "$DB" <<'SQL'
BEGIN;

-- New tables
CREATE TABLE IF NOT EXISTS roles (
    id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
    permissions TEXT NOT NULL DEFAULT '[]',
    credential_id TEXT REFERENCES credentials(id) ON DELETE SET NULL,
    panel TEXT, notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS integrations (
    id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, kind TEXT NOT NULL,
    base_url TEXT,
    credential_id TEXT REFERENCES credentials(id) ON DELETE SET NULL,
    last_synced_at TEXT, last_error TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sites (
    id TEXT PRIMARY KEY,
    app_id TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    infra_id TEXT NOT NULL REFERENCES infrastructure(id) ON DELETE CASCADE,
    domain TEXT NOT NULL,
    services_override TEXT NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned','provisioning','live','degraded','decommissioned')),
    deployed_at TEXT,
    metadata TEXT NOT NULL DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    UNIQUE (app_id, infra_id)
);
CREATE INDEX IF NOT EXISTS idx_sites_status ON sites(status);
CREATE INDEX IF NOT EXISTS idx_sites_app ON sites(app_id);
CREATE INDEX IF NOT EXISTS idx_sites_infra ON sites(infra_id);

CREATE TABLE IF NOT EXISTS step_assertions (
    id TEXT PRIMARY KEY,
    step_id TEXT NOT NULL REFERENCES test_steps(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN (
        'visible','hidden','text-match','text-not-match',
        'status-code','console-clean','console-error',
        'network-ok','network-error','element-count',
        'value-equals','value-contains','custom')),
    selector TEXT, expected_value TEXT,
    is_critical INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_assertions_step ON step_assertions(step_id);

CREATE TABLE IF NOT EXISTS assertion_results (
    execution_id TEXT NOT NULL REFERENCES step_executions(id) ON DELETE CASCADE,
    assertion_id TEXT NOT NULL REFERENCES step_assertions(id) ON DELETE CASCADE,
    passed INTEGER NOT NULL,
    actual_value TEXT, error_message TEXT,
    captured_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (execution_id, assertion_id)
);
CREATE INDEX IF NOT EXISTS idx_assertion_results_pass ON assertion_results(passed);

CREATE TABLE IF NOT EXISTS test_dependencies (
    test_id TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    depends_on TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    kind TEXT NOT NULL DEFAULT 'soft' CHECK (kind IN ('hard','soft','informational')),
    notes TEXT,
    PRIMARY KEY (test_id, depends_on)
);

CREATE TABLE IF NOT EXISTS coverage_targets (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('menu-item','action','link','route','feature','custom')),
    label TEXT NOT NULL, url_path TEXT,
    visible_to TEXT NOT NULL DEFAULT '[]',
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_coverage_targets_kind ON coverage_targets(kind);

CREATE TABLE IF NOT EXISTS coverage_hits (
    target_id TEXT NOT NULL REFERENCES coverage_targets(id) ON DELETE CASCADE,
    execution_id TEXT NOT NULL REFERENCES step_executions(id) ON DELETE CASCADE,
    captured_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (target_id, execution_id)
);

CREATE TABLE IF NOT EXISTS directive_violations (
    id TEXT PRIMARY KEY,
    run_id TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    execution_id TEXT REFERENCES step_executions(id) ON DELETE SET NULL,
    directive_id TEXT REFERENCES directives(id) ON DELETE SET NULL,
    enforcement TEXT NOT NULL CHECK (enforcement IN ('blocking','warning','advisory')),
    action_kind TEXT NOT NULL,
    description TEXT NOT NULL,
    user_decision TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_violations_run ON directive_violations(run_id, created_at);

-- New column: step_executions.metrics
ALTER TABLE step_executions ADD COLUMN metrics TEXT NOT NULL DEFAULT '{}';

-- bug_id soft-FK → real FK: rebuild step_executions table
-- (SQLite has no ALTER TABLE ... ADD CONSTRAINT; we rebuild.)
CREATE TABLE step_executions_new (
    id                   TEXT PRIMARY KEY,
    run_id               TEXT NOT NULL REFERENCES test_runs(id) ON DELETE CASCADE,
    test_id              TEXT NOT NULL REFERENCES tests(id),
    step_id              TEXT NOT NULL REFERENCES test_steps(id),
    subject_id           TEXT,
    retry_attempt        INTEGER NOT NULL DEFAULT 0,
    status               TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','in-progress','passed','failed','skipped','blocked')),
    started_at           TEXT,
    completed_at         TEXT,
    duration_ms          INTEGER,
    actual_result        TEXT,
    error_message        TEXT,
    evidence_snapshot    TEXT,
    bug_id               TEXT REFERENCES bugs(id) ON DELETE SET NULL,
    metrics              TEXT NOT NULL DEFAULT '{}',
    notes                TEXT,
    created_at           TEXT DEFAULT (datetime('now'))
);
INSERT INTO step_executions_new SELECT
    id, run_id, test_id, step_id, subject_id, retry_attempt, status,
    started_at, completed_at, duration_ms, actual_result, error_message,
    evidence_snapshot, bug_id, metrics, notes, created_at
FROM step_executions;
DROP TABLE step_executions;
ALTER TABLE step_executions_new RENAME TO step_executions;
CREATE INDEX IF NOT EXISTS idx_exec_run ON step_executions(run_id, status);
CREATE INDEX IF NOT EXISTS idx_exec_step ON step_executions(step_id, run_id);
CREATE INDEX IF NOT EXISTS idx_exec_test ON step_executions(test_id, run_id);

-- test_runs.status enum: add 'planned' (rebuild)
CREATE TABLE test_runs_new (
    id              TEXT PRIMARY KEY,
    label           TEXT,
    base_url        TEXT,
    started_at      TEXT DEFAULT (datetime('now')),
    ended_at        TEXT,
    status          TEXT NOT NULL DEFAULT 'in-progress'
        CHECK (status IN ('planned','in-progress','paused','completed','aborted')),
    target_phases   TEXT NOT NULL DEFAULT '[]',
    target_tags     TEXT NOT NULL DEFAULT '[]',
    skip_tags       TEXT NOT NULL DEFAULT '[]',
    context         TEXT,
    final_state     TEXT,
    metrics         TEXT NOT NULL DEFAULT '{}',
    created_at      TEXT DEFAULT (datetime('now'))
);
INSERT INTO test_runs_new SELECT * FROM test_runs;
DROP TABLE test_runs;
ALTER TABLE test_runs_new RENAME TO test_runs;
CREATE INDEX IF NOT EXISTS idx_runs_status ON test_runs(status, started_at);

-- v1.2 views
DROP VIEW IF EXISTS v_subjects_resolved;
CREATE VIEW v_subjects_resolved AS
  SELECT a.id, 'app' AS kind, a.name,
         json_object('id',a.id,'name',a.name,'app_type',a.app_type,
                     'target_domain',a.target_domain,
                     'services',json(a.services),'metadata',json(a.metadata)) AS fields
    FROM apps a
UNION ALL
  SELECT i.id, 'infrastructure', i.name,
         json_object('id',i.id,'name',i.name,'kind',i.kind,'ip',i.ip,
                     'ssh_port',i.ssh_port,'wildcard_domain',i.wildcard_domain,
                     'wireguard_ip',i.wireguard_ip,'metadata',json(i.metadata)) AS fields
    FROM infrastructure i
UNION ALL
  SELECT s.id, 'site', s.domain,
         json_object('id',s.id,'name',s.domain,'domain',s.domain,
                     'app_id',s.app_id,'infra_id',s.infra_id,'status',s.status,
                     'services_override',json(s.services_override),
                     'metadata',json(s.metadata)) AS fields
    FROM sites s
UNION ALL
  SELECT r.id, 'role', r.name,
         json_object('id',r.id,'name',r.name,
                     'permissions',json(r.permissions),'panel',r.panel) AS fields
    FROM roles r;

DROP VIEW IF EXISTS v_test_results_by_subject;
CREATE VIEW v_test_results_by_subject AS
SELECT
    e.run_id, e.test_id, COALESCE(e.subject_id,'_none_') AS subject_id,
    SUM(CASE WHEN e.status='passed'      THEN 1 ELSE 0 END) AS steps_passed,
    SUM(CASE WHEN e.status='failed'      THEN 1 ELSE 0 END) AS steps_failed,
    SUM(CASE WHEN e.status='skipped'     THEN 1 ELSE 0 END) AS steps_skipped,
    SUM(CASE WHEN e.status='blocked'     THEN 1 ELSE 0 END) AS steps_blocked,
    SUM(CASE WHEN e.status='in-progress' THEN 1 ELSE 0 END) AS steps_in_progress,
    MIN(e.started_at) AS started_at, MAX(e.completed_at) AS completed_at
FROM step_executions e
GROUP BY e.run_id, e.test_id, COALESCE(e.subject_id,'_none_');

DROP VIEW IF EXISTS v_flaky_steps;
CREATE VIEW v_flaky_steps AS
SELECT e.step_id, e.test_id,
       SUM(CASE WHEN e.status='passed' THEN 1 ELSE 0 END) AS pass_count,
       SUM(CASE WHEN e.status='failed' THEN 1 ELSE 0 END) AS fail_count,
       COUNT(DISTINCT e.run_id) AS run_count,
       MAX(e.completed_at) AS last_seen
  FROM step_executions e
 GROUP BY e.step_id, e.test_id
HAVING pass_count > 0 AND fail_count > 0;

DROP VIEW IF EXISTS v_coverage;
CREATE VIEW v_coverage AS
SELECT ct.id, ct.kind, ct.label, ct.url_path,
       COUNT(ch.execution_id) AS hit_count,
       MIN(ch.captured_at) AS first_hit_at,
       MAX(ch.captured_at) AS last_hit_at,
       GROUP_CONCAT(DISTINCT e.test_id) AS hitting_tests
  FROM coverage_targets ct
  LEFT JOIN coverage_hits ch ON ch.target_id = ct.id
  LEFT JOIN step_executions e ON e.id = ch.execution_id
 GROUP BY ct.id;

-- Triggers: applies_to integrity
DROP TRIGGER IF EXISTS trg_tests_applies_to_validate_insert;
CREATE TRIGGER trg_tests_applies_to_validate_insert
AFTER INSERT ON tests
WHEN json_array_length(NEW.applies_to) > 0
BEGIN
    SELECT CASE WHEN EXISTS(
        SELECT 1 FROM json_each(NEW.applies_to) j
        WHERE j.value NOT IN (SELECT id FROM v_subjects_resolved)
          AND j.value NOT LIKE 'VP-%'
    ) THEN RAISE(ABORT, 'tests.applies_to references unknown subject id') END;
END;

DROP TRIGGER IF EXISTS trg_tests_applies_to_validate_update;
CREATE TRIGGER trg_tests_applies_to_validate_update
AFTER UPDATE OF applies_to ON tests
WHEN json_array_length(NEW.applies_to) > 0
BEGIN
    SELECT CASE WHEN EXISTS(
        SELECT 1 FROM json_each(NEW.applies_to) j
        WHERE j.value NOT IN (SELECT id FROM v_subjects_resolved)
          AND j.value NOT LIKE 'VP-%'
    ) THEN RAISE(ABORT, 'tests.applies_to references unknown subject id') END;
END;

INSERT INTO schema_version (version) VALUES ('1.2.0');
COMMIT;
SQL

echo "Migration to v1.2.0 complete."
