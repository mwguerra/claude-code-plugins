#!/usr/bin/env bash
# Check whether a proposed action violates an active blocking directive.
#
# Called before any "risky" tool invocation during /e2e-test-specialist:test.
# Common cases this catches in the PrimeForge ledger:
#   - SSH-into-server-to-fix-state during E2E (directive: "no manual SSH fixes")
#   - Running `php artisan tinker` to patch DB rows (directive: "no tinker patches")
#   - Modifying production config through ssh (directive: "no manual fixes")
#
# Inputs: positional args
#   $1 action_kind  (ssh-write | ssh-read | tinker | sql-write | api-call | browser | other)
#   $2 description  (free-form what you're about to do, used for matching directives)
#
# Outputs:
#   exit 0  → action allowed
#   exit 1  → action BLOCKED (a blocking directive matched)
#   exit 2  → action allowed but warned (a warning directive matched; caller may
#             choose to confirm with the user)
#
# This file is a Learning Mode contribution point. Edit the TODO block below.

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"
E2E_COMPONENT=directive-check

action_kind="${1:-other}"
description="${2:-}"

# Quick deny for known dangerous actions, regardless of directives.
# These are sentinels — if you really need to do these, override at the test/run level.
case "$action_kind" in
    ssh-write|tinker|sql-write)
        block_destructive="$(e2e_config_get directives.block_destructive_ssh true)"
        block_tinker="$(e2e_config_get directives.block_db_tinker_patches true)"
        if [[ "$action_kind" == "tinker" && "$block_tinker" == "true" ]]; then
            e2e_log WARN directives "BLOCKED tinker action: $description"
            echo "directive-check: BLOCKED — tinker patches are forbidden during E2E (config: directives.block_db_tinker_patches)" >&2
            exit 1
        fi
        if [[ "$action_kind" == "ssh-write" && "$block_destructive" == "true" ]]; then
            e2e_log WARN directives "BLOCKED ssh-write action: $description"
            echo "directive-check: BLOCKED — destructive SSH actions are forbidden during E2E" >&2
            exit 1
        fi
        ;;
esac

# Match against active directives table. Naive substring match against title + body.
hit_block=""
hit_warn=""
matches="$(e2e_query "
    SELECT id, title, enforcement
      FROM directives
     WHERE active = 1
       AND (
            instr(lower(body),  lower($(e2e_sql_quote "$action_kind"))) > 0
         OR instr(lower(title), lower($(e2e_sql_quote "$action_kind"))) > 0
         OR instr(lower(body),  lower($(e2e_sql_quote "$description"))) > 0
       );
")"

if [[ -n "$matches" ]]; then
    if echo "$matches" | grep -q '"enforcement":"blocking"'; then
        hit_block=1
    elif echo "$matches" | grep -q '"enforcement":"warning"'; then
        hit_warn=1
    fi
fi

# ----------------------------------------------------------------------------
# TODO (you, the project owner): decide what BLOCKING and WARNING mean.
#
#   Options for a blocking match:
#     A) Hard refuse (exit 1)               — safest; caller must abandon action
#     B) Refuse + offer alternative path    — caller proposes a different fix
#     C) Refuse unless --override flag set  — escape hatch for one-off operator action
#
#   Options for a warning match:
#     a) Continue silently (log only)
#     b) Continue + emit one-line warning to the test report
#     c) Pause and ask the user via AskUserQuestion before continuing
#
#   The default below is (A) for blocking, (b) for warning. Change to taste.
# ----------------------------------------------------------------------------

if [[ -n "$hit_block" ]]; then
    e2e_log WARN directives "BLOCKED by directive: $action_kind | $description"
    echo "directive-check: BLOCKED by an active blocking directive. Investigate and fix the underlying cause; don't bypass." >&2
    exit 1
fi

if [[ -n "$hit_warn" ]]; then
    e2e_log INFO directives "WARNING from directive: $action_kind | $description"
    echo "directive-check: WARNING — an active directive flags this action. Continuing." >&2
    exit 2
fi

exit 0
