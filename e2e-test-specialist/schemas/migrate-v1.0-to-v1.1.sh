#!/usr/bin/env bash
# Migrate an existing v1.0.0 database to v1.1.0 (parametrization columns).
#
# Adds:
#   tests.applies_to              JSON array of subject ids, default '[]'
#   test_steps.action_template    Jinja-style template, NULL means use action verbatim
#   test_steps.expected_template  same for expected
#   step_executions.subject_id    NULL when the test has no applies_to
# Plus two views: v_test_subjects and v_subjects_resolved.
#
# Idempotent: safe to re-run.

set -euo pipefail

DB="${1:-.e2e-testing/e2e-tests.sqlite}"
[[ -f "$DB" ]] || { echo "error: db not found: $DB" >&2; exit 1; }

current="$(sqlite3 "$DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"

case "$current" in
    1.0.0)
        echo "Migrating $DB from v1.0.0 to v1.1.0..."
        ;;
    1.1.0)
        echo "Already at v1.1.0; nothing to do."
        exit 0
        ;;
    *)
        echo "error: unexpected schema version: $current" >&2
        exit 1
        ;;
esac

sqlite3 "$DB" <<'SQL'
BEGIN;

-- Tests: parametrization
ALTER TABLE tests       ADD COLUMN applies_to        TEXT NOT NULL DEFAULT '[]';
ALTER TABLE test_steps  ADD COLUMN action_template   TEXT;
ALTER TABLE test_steps  ADD COLUMN expected_template TEXT;
ALTER TABLE step_executions ADD COLUMN subject_id    TEXT;

-- Views
DROP VIEW IF EXISTS v_test_subjects;
CREATE VIEW v_test_subjects AS
SELECT t.id AS test_id, t.phase_id, t.test_order, NULL AS subject_id
  FROM tests t
 WHERE t.deprecated_at IS NULL
   AND json_array_length(COALESCE(NULLIF(t.applies_to,''), '[]')) = 0
UNION ALL
SELECT t.id, t.phase_id, t.test_order, j.value
  FROM tests t, json_each(t.applies_to) j
 WHERE t.deprecated_at IS NULL
   AND json_array_length(t.applies_to) > 0;

DROP VIEW IF EXISTS v_subjects_resolved;
CREATE VIEW v_subjects_resolved AS
  SELECT a.id, 'app' AS kind, a.name,
         json_object('id', a.id, 'name', a.name, 'app_type', a.app_type,
                     'target_domain', a.target_domain,
                     'services', json(a.services), 'metadata', json(a.metadata)) AS fields
    FROM apps a
UNION ALL
  SELECT i.id, 'infrastructure', i.name,
         json_object('id', i.id, 'name', i.name, 'kind', i.kind, 'ip', i.ip,
                     'ssh_port', i.ssh_port, 'wildcard_domain', i.wildcard_domain,
                     'wireguard_ip', i.wireguard_ip, 'metadata', json(i.metadata)) AS fields
    FROM infrastructure i;

INSERT INTO schema_version (version) VALUES ('1.1.0');
COMMIT;
SQL

echo "Migration to v1.1.0 complete."
