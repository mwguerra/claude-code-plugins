#!/usr/bin/env bash
# Background heartbeat watcher for long-blocking steps.
#
# Spawn this BEFORE entering a step that may exceed crash_detection.heartbeat_stale_seconds
# (apt locks, image transfers, multi-region DO provisioning, etc.). It ticks the
# heartbeat every N seconds until /tmp/e2e-step-active-{pid} is removed.
#
# Usage in /test:
#     bash long-step-heartbeat.sh start         → echoes a watcher PID
#     # ... run the long step ...
#     bash long-step-heartbeat.sh stop <pid>    → cleans up
#
# The watcher is short-circuit-safe: if the parent dies, the sentinel file
# remains for at most one tick interval before the watcher self-terminates
# (it checks the parent's existence each tick).

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"
E2E_COMPONENT=watcher

mode="${1:-}"

case "$mode" in
    start)
        interval="$(e2e_config_get crash_detection.warn_seconds 600)"
        # Tick at half the warn threshold; minimum 30s, max 300s
        tick=$((interval / 2))
        (( tick < 30 ))  && tick=30
        (( tick > 300 )) && tick=300

        parent_pid=$$
        sentinel="/tmp/e2e-watcher-${parent_pid}-$$"
        touch "$sentinel"

        ( while [[ -e "$sentinel" ]]; do
              # Parent dead? Self-terminate.
              kill -0 "$parent_pid" 2>/dev/null || break
              bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh" 2>/dev/null || true
              sleep "$tick"
          done ) &
        watcher_pid=$!
        disown "$watcher_pid" 2>/dev/null || true

        # Echo "<pid>:<sentinel>" so the caller can stop us cleanly
        printf '%d:%s' "$watcher_pid" "$sentinel"
        ;;
    stop)
        spec="${2:-}"
        [[ -n "$spec" ]] || e2e_die "stop requires <pid:sentinel> from start"
        watcher_pid="${spec%%:*}"
        sentinel="${spec#*:}"
        rm -f "$sentinel" 2>/dev/null || true
        kill "$watcher_pid" 2>/dev/null || true
        ;;
    *)
        e2e_die "unknown mode '$mode' (expected: start | stop)"
        ;;
esac
