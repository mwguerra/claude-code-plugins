---
description: Rollup of skipped steps grouped by skip_reason — "record what /authorize to recover N tests"
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: [<run-id>] [--explain]
---

# /e2e-test-specialist:skipped

Aggregate skipped step_executions in a run by `skip_reason` (schema v1.4.0
column). Defaults to the most recent run. Pass `--explain` to also print
the test_ids and the suggested action for each reason.

The skip-reason enum values:

| skip_reason          | Meaning                                                       |
|----------------------|---------------------------------------------------------------|
| `needs-infra`        | Infra missing AND no procedure / authorization to create it   |
| `cross-run-coverage` | Covered by another test in this or prior run (see test_coverage_links) |
| `future-impl`        | Ledger marks as future / not-yet-implemented                  |
| `no-authorization`   | Required authorization memory missing                          |
| `dependency-failed`  | A test_dependencies parent failed                              |
| `manual-decision`    | Operator marked skip explicitly                                |
| `flake-quarantine`   | Quarantined as flaky (see v_flaky_steps)                       |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

if [[ -z "${RUN_ID:-}" ]]; then
    RUN_ID="$(e2e_query_value 'SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1;')"
    [[ -n "$RUN_ID" ]] || e2e_die "no runs in DB"
fi

e2e_section "Skipped rollup for $RUN_ID"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT skip_reason, test_count, step_count
    FROM v_skip_rollup
   WHERE run_id = $(e2e_sql_quote "$RUN_ID")
   ORDER BY test_count DESC;
"

if [[ -n "${EXPLAIN:-}" ]]; then
    e2e_section "Per-reason action hints"

    # no-authorization → suggest /authorize
    sqlite3 -bail "$E2E_DB" "
      SELECT 'no-authorization → record an /e2e-test-specialist:authorize entry covering: ' ||
             COALESCE(GROUP_CONCAT(DISTINCT t.phase_id), '(none)') AS hint
        FROM step_executions e
        JOIN tests t ON t.id = e.test_id
       WHERE e.run_id=$(e2e_sql_quote "$RUN_ID") AND e.status='skipped' AND e.skip_reason='no-authorization';
    "

    # needs-infra → suggest /before-all hook
    sqlite3 -bail "$E2E_DB" "
      SELECT 'needs-infra → register an /e2e-test-specialist:before-all hook for: ' ||
             COALESCE(GROUP_CONCAT(DISTINCT t.phase_id), '(none)') AS hint
        FROM step_executions e
        JOIN tests t ON t.id = e.test_id
       WHERE e.run_id=$(e2e_sql_quote "$RUN_ID") AND e.status='skipped' AND e.skip_reason='needs-infra';
    "

    # dependency-failed → suggest /fix-failures on the parents
    sqlite3 -bail "$E2E_DB" "
      SELECT 'dependency-failed → run /e2e-test-specialist:fix-failures to address parents (then re-run children)' AS hint
       WHERE EXISTS (SELECT 1 FROM step_executions e
                      WHERE e.run_id=$(e2e_sql_quote "$RUN_ID") AND e.status='skipped' AND e.skip_reason='dependency-failed');
    "

    # cross-run-coverage → check test_coverage_links
    sqlite3 -bail "$E2E_DB" "
      SELECT 'cross-run-coverage → verified via test_coverage_links; promote to active=0 if no longer applicable' AS hint
       WHERE EXISTS (SELECT 1 FROM step_executions e
                      WHERE e.run_id=$(e2e_sql_quote "$RUN_ID") AND e.status='skipped' AND e.skip_reason='cross-run-coverage');
    "

    e2e_section "Tests skipped per reason (top 30)"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT e.skip_reason,
             e.test_id,
             substr(t.title,1,70) AS title,
             COALESCE(substr(e.notes,1,80),'') AS note
        FROM step_executions e
        JOIN tests t ON t.id = e.test_id
       WHERE e.run_id = $(e2e_sql_quote "$RUN_ID") AND e.status='skipped'
       ORDER BY e.skip_reason, e.test_id
       LIMIT 30;
    "
fi
```

## Why this matters

After R-2027's 251 skipped steps, manual triage was painful because the
skips lived in free-form `notes`. With v1.4.0's `skip_reason` enum
populated, `/skipped --explain` collapses 251 rows into 4–6 buckets and
tells you which single `/authorize` or `/before-all` recovers each bucket.
