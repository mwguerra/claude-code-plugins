#!/usr/bin/env bash
# Plugin self-tests. Verifies:
#   - Fresh schema.sql compiles
#   - Migration paths v1.0 → v1.4 produce a v1.4.0 DB with all tables/views
#   - Migrations are idempotent
#   - Importer parses the sample ledger and produces non-zero counts
#   - lifecycle_hooks / notifications / resource_ledger inserts work
#
# Usage:
#   CLAUDE_PLUGIN_ROOT=$(pwd)/e2e-test-specialist bash e2e-test-specialist/tests/run-self-tests.sh

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo "=== self-test: workspace = $WORK ==="

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ✓ $*"; }

# 1. Fresh schema compiles
echo "--- 1. Fresh schema.sql ---"
sqlite3 fresh.sqlite < "$PLUGIN_ROOT/schemas/schema.sql"
v="$(sqlite3 fresh.sqlite 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
[[ "$v" == "1.4.0" ]] || fail "fresh schema version = '$v', expected 1.4.0"
pass "fresh schema → v1.4.0"

# Verify all v1.4 tables exist
for t in directives lifecycle_hooks test_coverage_links notifications resource_ledger; do
    n="$(sqlite3 fresh.sqlite "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$t';")"
    [[ "$n" -eq 1 ]] || fail "missing table: $t"
done
pass "all v1.4 tables present"

# Verify all v1.4 views exist
for vw in v_run_progress v_test_results_by_subject v_flaky_steps v_skip_rollup v_latest_step_status v_latest_test_status; do
    n="$(sqlite3 fresh.sqlite "SELECT COUNT(*) FROM sqlite_master WHERE type='view' AND name='$vw';")"
    [[ "$n" -eq 1 ]] || fail "missing view: $vw"
done
pass "all v1.4 views present"

# 2. v1.3 → v1.4 migration on a synthetic v1.3.0 DB
echo "--- 2. Migration v1.3.0 → v1.4.0 ---"
# Build a synthetic v1.3.0 DB by taking the fresh v1.4.0 schema and undoing
# the v1.4-specific deltas (drop new tables/views, drop new columns).
cp fresh.sqlite mig.sqlite
sqlite3 mig.sqlite "
  DELETE FROM schema_version;
  INSERT INTO schema_version(version, applied_at) VALUES ('1.3.0', datetime('now','-1 hour'));
  DROP INDEX IF EXISTS idx_exec_skip;
  DROP VIEW IF EXISTS v_skip_rollup;
  DROP VIEW IF EXISTS v_latest_step_status;
  DROP VIEW IF EXISTS v_latest_test_status;
  DROP TABLE IF EXISTS test_coverage_links;
  DROP TABLE IF EXISTS notifications;
  DROP TABLE IF EXISTS resource_ledger;
  ALTER TABLE step_executions DROP COLUMN skip_reason;
  ALTER TABLE step_executions DROP COLUMN fix_attempt_index;
  ALTER TABLE test_steps DROP COLUMN idempotent;
  ALTER TABLE bugs DROP COLUMN affected_tests;
" 2>/dev/null  # SQLite versions older than 3.35 don't support DROP COLUMN; tolerate.
bash "$PLUGIN_ROOT/schemas/migrate-v1.3-to-v1.4.sh" mig.sqlite
final="$(sqlite3 mig.sqlite 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
[[ "$final" == "1.4.0" ]] || fail "v1.3→v1.4 migration ended at '$final', expected 1.4.0"
pass "v1.3 → v1.4 migration reaches 1.4.0"

# 3. Idempotent migration
echo "--- 3. Migration idempotency ---"
bash "$PLUGIN_ROOT/schemas/migrate-v1.3-to-v1.4.sh" mig.sqlite | grep -q "Already at v1.4.0" \
    || fail "v1.3→v1.4 migration not idempotent"
pass "v1.3→v1.4 migration is idempotent"

# 4. Importer
echo "--- 4. Importer on sample ledger ---"
mkdir -p .e2e-testing
cp fresh.sqlite .e2e-testing/e2e-tests.sqlite
python3 "$PLUGIN_ROOT/scripts/import-ledger.py" "$PLUGIN_ROOT/tests/fixtures/sample-ledger.md" \
    --db .e2e-testing/e2e-tests.sqlite > import.out
phases="$(sqlite3 .e2e-testing/e2e-tests.sqlite 'SELECT COUNT(*) FROM phases;')"
tests="$(sqlite3 .e2e-testing/e2e-tests.sqlite 'SELECT COUNT(*) FROM tests;')"
[[ "$phases" -ge 2 ]] || fail "import produced $phases phases, expected ≥ 2"
[[ "$tests" -ge 3 ]] || fail "import produced $tests tests, expected ≥ 3"
pass "import → $phases phases, $tests tests"

# 5. Inserts on new tables
echo "--- 5. Inserts on v1.4 tables ---"
sqlite3 .e2e-testing/e2e-tests.sqlite "
  INSERT INTO lifecycle_hooks (id, phase, title, body, enforcement, active)
  VALUES ('lh-pre-test', 'pre-run', 'Test hook', 'Do thing', 'advisory', 1);

  INSERT INTO test_coverage_links (id, covered_test_id, covering_test_id, rationale, active)
  SELECT 'tcl-test', a.id, b.id, 'cross-coverage', 1
    FROM tests a, tests b WHERE a.id != b.id LIMIT 1;

  INSERT INTO notifications (id, kind, severity, title)
  VALUES ('ntf-test', 'manual', 'info', 'Self-test notification');

  INSERT INTO resource_ledger (id, provider, resource_id, resource_kind, action)
  VALUES ('rl-test', 'do', 'test-droplet-1', 'droplet', 'created');
"
for t in lifecycle_hooks test_coverage_links notifications resource_ledger; do
    n="$(sqlite3 .e2e-testing/e2e-tests.sqlite "SELECT COUNT(*) FROM $t;")"
    [[ "$n" -ge 1 ]] || fail "$t empty after insert"
done
pass "inserts on lifecycle_hooks / test_coverage_links / notifications / resource_ledger"

# 6. v_skip_rollup with synthetic skipped row
echo "--- 6. v_skip_rollup ---"
sqlite3 .e2e-testing/e2e-tests.sqlite "
  INSERT INTO test_runs (id, status) VALUES ('R-self-test', 'completed');
  INSERT INTO step_executions (id, run_id, test_id, step_id, status, skip_reason)
  SELECT 'se-test', 'R-self-test', t.id, s.id, 'skipped', 'no-authorization'
    FROM tests t JOIN test_steps s ON s.test_id = t.id LIMIT 1;
"
n="$(sqlite3 .e2e-testing/e2e-tests.sqlite "SELECT test_count FROM v_skip_rollup WHERE run_id='R-self-test' AND skip_reason='no-authorization';")"
[[ "$n" == "1" ]] || fail "v_skip_rollup returned '$n', expected 1"
pass "v_skip_rollup aggregates skip_reason"

echo ""
echo "=== all self-tests passed ==="
