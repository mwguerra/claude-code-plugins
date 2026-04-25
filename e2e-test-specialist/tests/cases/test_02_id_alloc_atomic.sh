#!/usr/bin/env bash
# Verify e2e_alloc_and_insert is atomic under serial allocations and produces
# monotonically increasing IDs.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Insert 10 directives via the alloc helper.
ids=()
for i in $(seq 1 10); do
    id="$(e2e_alloc_and_insert directives DIR \
        "id, title, body, enforcement, active" \
        "'__NEXT_ID__', $(e2e_sql_quote "title-$i"), $(e2e_sql_quote "body-$i"), 'warning', 1")"
    ids+=("$id")
done

# Expect DIR-001 .. DIR-010 in order.
expected=("DIR-001" "DIR-002" "DIR-003" "DIR-004" "DIR-005"
          "DIR-006" "DIR-007" "DIR-008" "DIR-009" "DIR-010")

for i in "${!expected[@]}"; do
    [[ "${ids[$i]}" == "${expected[$i]}" ]] || {
        echo "ID at index $i: expected ${expected[$i]}, got ${ids[$i]}"
        exit 1
    }
done

count="$(sqlite3 "$E2E_DB" "SELECT COUNT(*) FROM directives;")"
[[ "$count" == "10" ]] || { echo "expected 10 directives, got $count"; exit 1; }
