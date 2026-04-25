#!/usr/bin/env bash
# Step execution checkpoint helper. Two modes:
#
#   begin <run_id> <test_id> <step_id> [retry] [subject_id]   → emits execution_id
#   end   <execution_id> <status> [actual] [error] [evidence] [bug_id]
#
# Use begin BEFORE the action (so even an immediate crash leaves an in-progress row),
# and end AFTER the observation. Both write through to disk before returning.

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"

E2E_COMPONENT=checkpoint
mode="${1:-}"; shift || true

case "$mode" in
    begin)
        [[ $# -ge 3 ]] || e2e_die "begin requires <run_id> <test_id> <step_id> [retry] [subject_id]"
        e2e_step_begin "$@"
        ;;
    end)
        [[ $# -ge 2 ]] || e2e_die "end requires <execution_id> <status> [actual] [error] [evidence] [bug_id]"
        e2e_step_end "$@"
        ;;
    *)
        e2e_die "unknown mode '$mode' (expected: begin | end)"
        ;;
esac
