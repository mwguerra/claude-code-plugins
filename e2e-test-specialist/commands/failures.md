---
description: Show recent failed/skipped/blocked step executions for a run, with error message and context
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: [<run-id>] [--limit N] [--status failed,skipped,blocked] [--test T-04.03]
---

# /e2e-test-specialist:failures

List recent non-passing step executions. Defaults to the active run and the
three statuses that warrant investigation: `failed`, `skipped`, `blocked`.
Use this instead of writing ad-hoc SQL — the schema does not have
`step_executions.executed_at`; real timestamp columns are `started_at`,
`completed_at`, and `created_at`.

## Usage

| Form                              | Effect                                              |
|-----------------------------------|-----------------------------------------------------|
| (no args)                         | Last 10 failures for the active run                 |
| `<run-id>`                        | Failures for the named run (e.g., `R-2027`)         |
| `--limit N`                       | Cap output at N rows (default: 10)                  |
| `--status failed,skipped`         | Filter statuses (default: failed,skipped,blocked)   |
| `--test T-04.03`                  | Limit to one test_id                                |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

LIMIT="${LIMIT:-10}"
STATUSES="${STATUSES:-failed,skipped,blocked}"

# Build SQL IN-list from comma-separated statuses
STATUS_LIST="$(printf "%s" "$STATUSES" | awk -v RS=, '{printf "%s\"%s\"", (NR>1?",":""), $1}')"

if [[ -n "${RUN_ID:-}" ]]; then
    RUN_FILTER="se.run_id = $(e2e_sql_quote "$RUN_ID")"
    SCOPE="$RUN_ID"
else
    RUN_ID="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
    [[ -n "$RUN_ID" ]] || e2e_die "no active run; pass <run-id> explicitly"
    RUN_FILTER="se.run_id = $(e2e_sql_quote "$RUN_ID")"
    SCOPE="$RUN_ID (active)"
fi

TEST_FILTER=""
if [[ -n "${TEST_ID:-}" ]]; then
    TEST_FILTER="AND se.test_id = $(e2e_sql_quote "$TEST_ID")"
fi

e2e_section "Failures in $SCOPE  (statuses: $STATUSES)"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT se.test_id,
         se.step_id,
         se.status,
         COALESCE(substr(se.error_message,1,80), '(no message)') AS error_excerpt,
         se.started_at,
         se.completed_at,
         se.duration_ms,
         se.retry_attempt
    FROM step_executions se
   WHERE $RUN_FILTER
     AND se.status IN ($STATUS_LIST)
     $TEST_FILTER
   ORDER BY COALESCE(se.completed_at, se.started_at, se.created_at) DESC
   LIMIT $LIMIT;
"

e2e_section "Full error message for the most recent failure"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT se.test_id, se.step_id, se.status, se.error_message,
         substr(COALESCE(se.evidence_snapshot,''), 1, 400) AS evidence_excerpt
    FROM step_executions se
   WHERE $RUN_FILTER AND se.status IN ($STATUS_LIST) $TEST_FILTER
   ORDER BY COALESCE(se.completed_at, se.started_at, se.created_at) DESC
   LIMIT 1;
"

e2e_section "Open bugs from this run"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id, severity, substr(title,1,70) AS title, root_cause IS NOT NULL AS has_root_cause
    FROM bugs
   WHERE discovered_in_run = $(e2e_sql_quote "$RUN_ID")
   ORDER BY discovered_at DESC
   LIMIT 20;
"
```

## Schema reminder

The `step_executions` table columns are:
`id, run_id, test_id, step_id, subject_id, retry_attempt, status, started_at, completed_at, duration_ms, actual_result, error_message, evidence_snapshot, bug_id, metrics, notes, created_at`.

Status values: `pending`, `in-progress`, `passed`, `failed`, `skipped`, `blocked`.

There is **no** `executed_at` column.
