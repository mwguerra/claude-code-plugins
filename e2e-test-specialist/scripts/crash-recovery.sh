#!/usr/bin/env bash
# Crash detection + recovery hint. Prints a JSON summary of recoverable state.
#
# Output JSON shape:
#   {
#     "stale_reaped": <int>,
#     "active_run_id": <string|null>,
#     "crashed_session": { id, started_at, last_heartbeat, current_test_id, current_step_id } | null,
#     "next_pending_step": { test_id, step_id, action } | null
#   }

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"

E2E_COMPONENT=recovery
e2e_require_db

reaped="$(e2e_reap_stale_sessions)"
active_run="$(e2e_query_value "SELECT active_run_id FROM state WHERE id=1;")"

# Most recent crashed session for the active run (if any)
crashed_json='null'
if [[ -n "$active_run" ]]; then
    crashed_json="$(sqlite3 -bail -json "$E2E_DB" "
        SELECT id, started_at, last_heartbeat, current_test_id, current_step_id, current_execution_id
          FROM sessions
         WHERE run_id = $(e2e_sql_quote "$active_run") AND status='crashed'
         ORDER BY last_heartbeat DESC
         LIMIT 1;
    " || echo '[]')"
    [[ "$crashed_json" == "[]" ]] && crashed_json='null'
    [[ "$crashed_json" != 'null' ]] && crashed_json="$(echo "$crashed_json" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[0]))')"
fi

# Next pending step (first step in a test that has any non-terminal execution, OR first un-executed step)
next_json='null'
if [[ -n "$active_run" ]]; then
    next_json="$(sqlite3 -bail -json "$E2E_DB" "
        WITH terminal AS (
            SELECT step_id FROM step_executions
             WHERE run_id = $(e2e_sql_quote "$active_run")
               AND status IN ('passed','skipped')
        )
        SELECT t.id AS test_id, s.id AS step_id, s.action
          FROM tests t
          JOIN test_steps s ON s.test_id = t.id
         WHERE t.deprecated_at IS NULL
           AND s.id NOT IN (SELECT step_id FROM terminal)
         ORDER BY t.test_order, s.step_order
         LIMIT 1;
    " || echo '[]')"
    [[ "$next_json" == "[]" ]] && next_json='null'
    [[ "$next_json" != 'null' ]] && next_json="$(echo "$next_json" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[0]))')"
fi

python3 - "$reaped" "${active_run:-}" "$crashed_json" "$next_json" <<'PY'
import json, sys
reaped = int(sys.argv[1])
active_run = sys.argv[2] or None
crashed = json.loads(sys.argv[3]) if sys.argv[3] != 'null' else None
nxt     = json.loads(sys.argv[4]) if sys.argv[4] != 'null' else None
print(json.dumps({
    "stale_reaped": reaped,
    "active_run_id": active_run,
    "crashed_session": crashed,
    "next_pending_step": nxt,
}, indent=2))
PY
