#!/usr/bin/env bash
# Tick the heartbeat on the active session.
# Call this immediately after any browser/SSH/API tool invocation.
#
# Usage: bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh"
set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"
E2E_COMPONENT=heartbeat
e2e_heartbeat
