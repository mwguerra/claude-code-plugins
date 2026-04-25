#!/usr/bin/env bash
# Verify session lifecycle: start → heartbeat → reap (when stale) → end.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Seed a run row to attach the session to
sqlite3 "$E2E_DB" "
    INSERT INTO test_runs (id, label, status) VALUES ('R-001', 'self-test', 'in-progress');
    UPDATE state SET active_run_id = 'R-001' WHERE id=1;
"

# Start session
sid="$(e2e_session_start "R-001")"
[[ -n "$sid" ]] || { echo "session_start did not return an id"; exit 1; }

# Should be active in DB
status="$(sqlite3 "$E2E_DB" "SELECT status FROM sessions WHERE id='$sid';")"
[[ "$status" == "active" ]] || { echo "expected active, got: $status"; exit 1; }

# Heartbeat tick
e2e_heartbeat
hb="$(sqlite3 "$E2E_DB" "SELECT last_heartbeat FROM sessions WHERE id='$sid';")"
[[ -n "$hb" ]] || { echo "heartbeat not recorded"; exit 1; }

# Manually backdate the heartbeat past the stale threshold to simulate crash
sqlite3 "$E2E_DB" "UPDATE sessions SET last_heartbeat=datetime('now', '-9999 seconds') WHERE id='$sid';"

# Reap stale sessions — should mark the session crashed
n="$(e2e_reap_stale_sessions)"
[[ "$n" -ge 1 ]] || { echo "expected at least 1 reaped, got $n"; exit 1; }

status_after="$(sqlite3 "$E2E_DB" "SELECT status FROM sessions WHERE id='$sid';")"
[[ "$status_after" == "crashed" ]] || { echo "expected crashed, got: $status_after"; exit 1; }
