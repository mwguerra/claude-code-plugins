---
description: Show what's left in the active run — pending tests count, next pending test, blocked tests
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: [<run-id>] [--limit N]
---

# /e2e-test-specialist:pending

Show what work the active run still has to do. Defaults to the active run.
Use this instead of writing ad-hoc SQL — there is no `tests.run_id` and no
`tests.status` column. The `tests` table is the catalog (test definitions
parsed from the ledger); per-run state lives in `step_executions`, joined
back to `tests` via `step_executions.test_id`.

## Usage

| Form               | Effect                                              |
|--------------------|-----------------------------------------------------|
| (no args)          | Pending summary for the active run                  |
| `<run-id>`         | Pending summary for the named run (e.g., `R-2027`)  |
| `--limit N`        | How many "next pending tests" to list (default: 5)  |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

LIMIT="${LIMIT:-5}"

if [[ -n "${RUN_ID:-}" ]]; then
    SCOPE="$RUN_ID"
else
    RUN_ID="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
    [[ -n "$RUN_ID" ]] || e2e_die "no active run; pass <run-id> explicitly"
    SCOPE="$RUN_ID (active)"
fi

# Pending step COUNT — definitive: a step is "pending" if it has no
# step_executions row for this run, or its latest execution is pending/in-progress.
e2e_section "Pending work for $SCOPE"
sqlite3 -bail -column -header "$E2E_DB" "
  WITH latest_exec AS (
      SELECT step_id,
             status,
             ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY created_at DESC) AS rn
        FROM step_executions
       WHERE run_id = $(e2e_sql_quote "$RUN_ID")
  )
  SELECT
    (SELECT COUNT(*) FROM test_steps s
       LEFT JOIN latest_exec le ON le.step_id = s.id AND le.rn = 1
      WHERE le.status IS NULL OR le.status IN ('pending','in-progress'))
        AS pending_steps,
    (SELECT COUNT(DISTINCT t.id) FROM tests t
       JOIN test_steps s ON s.test_id = t.id
       LEFT JOIN latest_exec le ON le.step_id = s.id AND le.rn = 1
      WHERE le.status IS NULL OR le.status IN ('pending','in-progress'))
        AS pending_tests,
    (SELECT COUNT(*) FROM step_executions
      WHERE run_id = $(e2e_sql_quote "$RUN_ID") AND status = 'blocked')
        AS blocked_steps,
    (SELECT COUNT(*) FROM step_executions
      WHERE run_id = $(e2e_sql_quote "$RUN_ID") AND status = 'passed')
        AS passed_steps,
    (SELECT COUNT(*) FROM step_executions
      WHERE run_id = $(e2e_sql_quote "$RUN_ID") AND status = 'failed')
        AS failed_steps;
"

e2e_section "Next $LIMIT pending tests (in execution order)"
sqlite3 -bail -column -header "$E2E_DB" "
  WITH latest_exec AS (
      SELECT step_id,
             status,
             ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY created_at DESC) AS rn
        FROM step_executions
       WHERE run_id = $(e2e_sql_quote "$RUN_ID")
  ),
  pending_test_ids AS (
      SELECT DISTINCT t.id, t.title, t.test_order, p.id AS phase_id, p.phase_order
        FROM tests t
        JOIN phases p ON p.id = t.phase_id
        JOIN test_steps s ON s.test_id = t.id
        LEFT JOIN latest_exec le ON le.step_id = s.id AND le.rn = 1
       WHERE (le.status IS NULL OR le.status IN ('pending','in-progress'))
         AND t.deprecated_at IS NULL
  )
  SELECT phase_id, id AS test_id, substr(title,1,70) AS title
    FROM pending_test_ids
   ORDER BY phase_order, test_order
   LIMIT $LIMIT;
"

e2e_section "Blocked tests (fix budget exhausted by autopilot, etc.)"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT DISTINCT se.test_id, t.title
    FROM step_executions se
    JOIN tests t ON t.id = se.test_id
   WHERE se.run_id = $(e2e_sql_quote "$RUN_ID")
     AND se.status = 'blocked'
   ORDER BY se.test_id;
"

e2e_section "Per-test rollup (top 20 with any failure or block)"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT test_id, subject_id, steps_passed, steps_failed, steps_skipped,
         steps_blocked, steps_in_progress
    FROM v_test_results_by_subject
   WHERE run_id = $(e2e_sql_quote "$RUN_ID")
     AND (steps_failed > 0 OR steps_blocked > 0)
   ORDER BY steps_failed DESC, steps_blocked DESC
   LIMIT 20;
"
```

## Schema reminder

`tests` is a **catalog** (test definitions). It does **not** have a
`run_id` or `status` column — those concepts live in `step_executions`.

To answer "what's pending for run X?" you must:
1. Start from `test_steps` (every step that exists in the plan).
2. LEFT JOIN to `step_executions` filtered by `run_id = X`.
3. Where the join is NULL OR status is `pending`/`in-progress`, the step is
   still pending for that run.

The view `v_test_results_by_subject` aggregates this per (run, test, subject).
