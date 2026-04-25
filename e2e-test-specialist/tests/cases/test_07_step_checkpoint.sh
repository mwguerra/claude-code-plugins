#!/usr/bin/env bash
# Verify step_executions checkpoints: begin creates an in-progress row, end
# moves it to terminal status with duration_ms populated.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Seed a minimal run + test + step
sqlite3 "$E2E_DB" "
    INSERT INTO test_runs (id, label, status) VALUES ('R-001', 'self-test', 'in-progress');
    INSERT INTO phases (id, title, phase_order) VALUES ('P00', 'phase 0', 0);
    INSERT INTO tests  (id, phase_id, title, test_kind, test_order)
        VALUES ('T-00.01', 'P00', 'test 1', 'browser', 1);
    INSERT INTO test_steps (id, test_id, step_order, action, expected)
        VALUES ('S-00.01.001', 'T-00.01', 1, 'do thing', 'expects thing');
    UPDATE state SET active_run_id = 'R-001' WHERE id=1;
"

# Open a session so set_pointer has somewhere to write
sid="$(e2e_session_start R-001)"

# checkpoint begin
ex="$(bash "$CLAUDE_PLUGIN_ROOT/scripts/checkpoint.sh" begin R-001 T-00.01 S-00.01.001 0 "")"
[[ -n "$ex" ]] || { echo "begin did not return id"; exit 1; }

status="$(sqlite3 "$E2E_DB" "SELECT status FROM step_executions WHERE id='$ex';")"
[[ "$status" == "in-progress" ]] || { echo "expected in-progress, got: $status"; exit 1; }

sleep 1

# checkpoint end
bash "$CLAUDE_PLUGIN_ROOT/scripts/checkpoint.sh" end "$ex" passed "did the thing" "" "" ""

row="$(sqlite3 -separator '|' "$E2E_DB" "SELECT status, duration_ms FROM step_executions WHERE id='$ex';")"
status="${row%%|*}"
dur="${row##*|}"
[[ "$status" == "passed" ]] || { echo "expected passed, got: $status"; exit 1; }
[[ "$dur" =~ ^[0-9]+$ ]] && (( dur >= 1 )) || { echo "expected duration_ms >= 1, got: $dur"; exit 1; }
