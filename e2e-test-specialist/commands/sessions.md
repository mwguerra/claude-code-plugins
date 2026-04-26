---
description: List sessions for a run (active run by default) — id, status, heartbeat age, current step
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: [<run-id>] [--limit N] [--all]
---

# /e2e-test-specialist:sessions

Show sessions for a run. Defaults to the active run. Use this instead of
writing ad-hoc SQL against the `sessions` table — the schema does not have
`paused_at` or `paused_reason` columns; pause is encoded as `status='paused'`
and `last_heartbeat` records when the session went idle.

## Usage

| Form                        | Effect                                              |
|-----------------------------|-----------------------------------------------------|
| (no args)                   | Sessions for the active run                         |
| `<run-id>`                  | Sessions for the named run (e.g., `R-2027`)         |
| `--limit N`                 | Cap output at N rows (default: 10)                  |
| `--all`                     | All sessions across all runs                        |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# Reap stale sessions so heartbeat ages reflect reality.
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" >/dev/null

LIMIT="${LIMIT:-10}"

if [[ -n "${ALL:-}" ]]; then
    WHERE="1=1"
    SCOPE="all runs"
elif [[ -n "${RUN_ID:-}" ]]; then
    WHERE="run_id = $(e2e_sql_quote "$RUN_ID")"
    SCOPE="$RUN_ID"
else
    RUN_ID="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
    [[ -n "$RUN_ID" ]] || e2e_die "no active run; pass <run-id> or --all"
    WHERE="run_id = $(e2e_sql_quote "$RUN_ID")"
    SCOPE="$RUN_ID (active)"
fi

e2e_section "Sessions for $SCOPE"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id,
         status,
         started_at,
         last_heartbeat,
         CAST((julianday('now') - julianday(last_heartbeat)) * 86400 AS INTEGER)
             AS heartbeat_age_sec,
         ended_at,
         current_test_id AS test,
         current_step_id AS step
    FROM sessions
   WHERE $WHERE
   ORDER BY started_at DESC
   LIMIT $LIMIT;
"
```

## Schema reminder

The `sessions` table columns are:
`id, run_id, started_at, last_heartbeat, ended_at, status, current_test_id, current_step_id, current_execution_id, process_info, notes, created_at`.

Status values: `active`, `paused`, `completed`, `crashed`, `aborted`.

There is **no** `paused_at` or `paused_reason` column. If you need to know
when a session paused, look at `last_heartbeat` (the moment activity
stopped) or `ended_at` (if the session was closed in `paused` state).
