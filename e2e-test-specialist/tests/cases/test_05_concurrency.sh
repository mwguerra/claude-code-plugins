#!/usr/bin/env bash
# Verify two parallel inserts via e2e_alloc_and_insert both succeed without
# colliding on ID. WAL + BEGIN IMMEDIATE should serialize them.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Race two batches of 5 inserts in parallel
(
    for i in $(seq 1 5); do
        e2e_alloc_and_insert directives DIR \
            "id, title, body, enforcement, active" \
            "'__NEXT_ID__', $(e2e_sql_quote "A-$i"), $(e2e_sql_quote "from-A"), 'warning', 1" \
            >/dev/null
    done
) &
PID_A=$!

(
    for i in $(seq 1 5); do
        e2e_alloc_and_insert directives DIR \
            "id, title, body, enforcement, active" \
            "'__NEXT_ID__', $(e2e_sql_quote "B-$i"), $(e2e_sql_quote "from-B"), 'warning', 1" \
            >/dev/null
    done
) &
PID_B=$!

wait "$PID_A" || { echo "batch A failed"; exit 1; }
wait "$PID_B" || { echo "batch B failed"; exit 1; }

count="$(sqlite3 "$E2E_DB" "SELECT COUNT(*) FROM directives;")"
[[ "$count" == "10" ]] || {
    echo "expected 10 rows, got $count (lost writes from contention)"
    sqlite3 "$E2E_DB" "SELECT id, title FROM directives;"
    exit 1
}

# All IDs unique?
distinct="$(sqlite3 "$E2E_DB" "SELECT COUNT(DISTINCT id) FROM directives;")"
[[ "$distinct" == "10" ]] || {
    echo "duplicate IDs detected:"
    sqlite3 "$E2E_DB" "SELECT id, COUNT(*) FROM directives GROUP BY id HAVING COUNT(*) > 1;"
    exit 1
}

# IDs are DIR-001 .. DIR-010 (no gaps)
ids="$(sqlite3 "$E2E_DB" "SELECT id FROM directives ORDER BY id;" | tr '\n' ',')"
[[ "$ids" == "DIR-001,DIR-002,DIR-003,DIR-004,DIR-005,DIR-006,DIR-007,DIR-008,DIR-009,DIR-010," ]] || {
    echo "id sequence has gaps: $ids"
    exit 1
}
