#!/usr/bin/env bash
# Decide whether a failed step should be retried.
#
# Called by /e2e-test-specialist:test after each failed step. Outputs:
#   exit 0  → retry  (caller waits scripts/retry-policy.sh BACKOFF_SECONDS, then re-runs)
#   exit 1  → do not retry; mark failed (or escalate to bug)
#
# Inputs: positional args
#   $1 step_kind     (browser | ssh | api | cli | mixed | stress | ...)
#   $2 error_kind    (timeout | network | assertion | http-5xx | http-4xx | not-found |
#                     auth-required | rate-limit | unknown)
#   $3 attempt       (current attempt count, 0 = first try)
#
# Stdout: backoff seconds to wait before next attempt (only meaningful when exit 0).
#
# This file is a Learning Mode contribution point. Edit the marked TODO block to
# match your project's failure characteristics. The defaults below are conservative.

set -euo pipefail

step_kind="${1:-mixed}"
error_kind="${2:-unknown}"
attempt="${3:-0}"

# Clamp attempt
[[ "$attempt" =~ ^[0-9]+$ ]] || attempt=0

# ----------------------------------------------------------------------------
# TODO (you, the project owner): tune the policy below.
#
#   The decision is "should we retry, and if so how long to wait?"
#   The tradeoff is: retrying transient errors is good, retrying assertion
#   failures hides bugs. Use your knowledge of your stack:
#
#   - WireGuard mesh setup can take 30-60s after both servers are Ready.
#   - Let's Encrypt cert can take 30-90s on first request after HTTPS.
#   - Reverb WebSocket connect retries are appropriate for intermittent broker.
#   - DO droplet cloud-init is unpredictable in the first ~60s.
#   - apt locks on a fresh Ubuntu can hold for 900s+ legitimately.
#
#   Edit the case statement to reflect your real failure modes.
#
# CRITICAL — interaction with the agent's "Ultrathink Root Cause" directive:
#
#   This script returns 0 ONLY for genuine transient infrastructure flakes.
#   For everything else (assertion failures, 4xx outside auth, structural
#   errors, unexpected behaviors) it returns 1, and the /test command's
#   step 7 takes over: capture evidence → form hypothesis → verify → fix
#   in source → re-run.
#
#   When in doubt, prefer to return 1 (no retry, force root-cause loop)
#   over returning 0 (retry, possibly hiding a real bug). A spurious
#   root-cause investigation costs minutes; a hidden assertion bug that
#   the test suite glosses over costs hours of confusion later.
# ----------------------------------------------------------------------------

# Helpful aliases — feel free to use or ignore in your custom logic.
is_transient_error() {
    case "$error_kind" in
        timeout|network|http-5xx|rate-limit) return 0 ;;
        *) return 1 ;;
    esac
}

is_assertion_error() {
    case "$error_kind" in
        assertion|http-4xx|not-found|auth-required) return 0 ;;
        *) return 1 ;;
    esac
}

# === Default policy =========================================================

# Assertion failures are bugs, not flakes — never retry.
if is_assertion_error; then
    exit 1
fi

# Browser-class transient failures: retry up to 3x with backoff.
if [[ "$step_kind" == "browser" ]] && is_transient_error; then
    case "$attempt" in
        0) echo 5;  exit 0 ;;
        1) echo 15; exit 0 ;;
        2) echo 45; exit 0 ;;
        *) exit 1 ;;
    esac
fi

# SSH/API transient: retry up to 2x.
if [[ "$step_kind" == "ssh" || "$step_kind" == "api" ]] && is_transient_error; then
    case "$attempt" in
        0) echo 10; exit 0 ;;
        1) echo 30; exit 0 ;;
        *) exit 1 ;;
    esac
fi

# Stress tests: don't retry — the failure IS the data.
if [[ "$step_kind" == "stress" ]]; then
    exit 1
fi

# Unknown error_kind: do NOT auto-retry. An unclassified failure is exactly
# the case where the agent should drop into the root-cause loop instead of
# papering over a new failure shape with a quick retry that might hide it.
# (Previous behavior was a single 5s retry on unknown — removed because it
#  conflicts with the Ultrathink Root Cause directive.)

exit 1
