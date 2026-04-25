#!/usr/bin/env bash
# Verify import-ledger.py against a small fixture markdown file: parses
# directives, infrastructure, credentials, apps, phases, tests, steps.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null

python3 "$CLAUDE_PLUGIN_ROOT/scripts/import-ledger.py" \
    "$CLAUDE_PLUGIN_ROOT/tests/fixtures/mini-ledger.md" >/tmp/import.out 2>&1 \
    || { echo "importer failed"; cat /tmp/import.out; exit 1; }

# Counts after import — minimum thresholds; importer may add tags etc.
assert_count() {
    local table="$1" expected="$2"
    local n
    n="$(sqlite3 "$E2E_DB" "SELECT COUNT(*) FROM $table;")"
    [[ "$n" -ge "$expected" ]] || {
        echo "expected at least $expected in $table, got $n"
        exit 1
    }
}

assert_count directives 1
assert_count infrastructure 1
assert_count credentials 1
assert_count apps 1
assert_count phases 2
assert_count tests 2
assert_count test_steps 4

# Tests should have at least one auto-tag from the taxonomy
tag_links="$(sqlite3 "$E2E_DB" "SELECT COUNT(*) FROM test_tags;")"
[[ "$tag_links" -ge 1 ]] || { echo "no auto-tags applied (got $tag_links)"; exit 1; }

# Re-importing should be idempotent for tests/phases/steps (INSERT OR REPLACE)
python3 "$CLAUDE_PLUGIN_ROOT/scripts/import-ledger.py" \
    "$CLAUDE_PLUGIN_ROOT/tests/fixtures/mini-ledger.md" >/dev/null 2>&1

phase_count_2="$(sqlite3 "$E2E_DB" "SELECT COUNT(*) FROM phases;")"
[[ "$phase_count_2" -ge 2 ]] || { echo "phases lost on re-import: $phase_count_2"; exit 1; }
