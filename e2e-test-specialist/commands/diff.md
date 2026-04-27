---
description: Compare two runs at the test level — regressions, fixes, new skips, status changes
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: <run-a> <run-b> [--limit N] [--include-unchanged]
---

# /e2e-test-specialist:diff

Compare two runs and surface what changed at the test level. The most
valuable nightly question is "what regressed and what fixed?" Built on top
of `v_latest_test_status` from schema v1.4.0.

## Usage

| Form                                 | Effect                                         |
|--------------------------------------|------------------------------------------------|
| `<run-a> <run-b>`                    | Diff run-a vs run-b (b is "newer" semantically)|
| `--limit N`                          | Cap each section at N rows (default: 30)       |
| `--include-unchanged`                | Also list tests with the same status in both   |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

[[ -n "${RUN_A:-}" && -n "${RUN_B:-}" ]] || e2e_die "usage: /e2e-test-specialist:diff <run-a> <run-b>"
LIMIT="${LIMIT:-30}"

# Sanity: both runs must exist
for r in "$RUN_A" "$RUN_B"; do
    n="$(e2e_query_value "SELECT COUNT(*) FROM test_runs WHERE id=$(e2e_sql_quote "$r");")"
    [[ "$n" -eq 1 ]] || e2e_die "no such run: $r"
done

# Build a temp comparison via UNION of latest statuses.
DIFF_SQL="
  WITH a AS (SELECT test_id, test_status FROM v_latest_test_status WHERE run_id=$(e2e_sql_quote "$RUN_A")),
       b AS (SELECT test_id, test_status FROM v_latest_test_status WHERE run_id=$(e2e_sql_quote "$RUN_B"))
  SELECT
      COALESCE(a.test_id, b.test_id)               AS test_id,
      COALESCE(a.test_status, '(absent)')          AS status_a,
      COALESCE(b.test_status, '(absent)')          AS status_b
    FROM a FULL OUTER JOIN b ON a.test_id = b.test_id
"

# SQLite doesn't have FULL OUTER JOIN before 3.39 — emulate with two LEFT JOINs UNION.
DIFF_SQL="
  WITH a AS (SELECT test_id, test_status FROM v_latest_test_status WHERE run_id=$(e2e_sql_quote "$RUN_A")),
       b AS (SELECT test_id, test_status FROM v_latest_test_status WHERE run_id=$(e2e_sql_quote "$RUN_B")),
       merged AS (
         SELECT a.test_id AS test_id, a.test_status AS status_a, b.test_status AS status_b
           FROM a LEFT JOIN b ON a.test_id = b.test_id
         UNION
         SELECT b.test_id AS test_id, a.test_status AS status_a, b.test_status AS status_b
           FROM b LEFT JOIN a ON a.test_id = b.test_id
       )
  SELECT test_id, COALESCE(status_a,'(absent)') AS status_a, COALESCE(status_b,'(absent)') AS status_b
    FROM merged
"

e2e_section "Run A: $RUN_A   →   Run B: $RUN_B"

e2e_section "Regressions  (passed → failed/blocked)  — top $LIMIT"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL
  WHERE status_a='passed' AND status_b IN ('failed','blocked')
  ORDER BY test_id LIMIT $LIMIT;
"

e2e_section "Fixes  (failed/blocked → passed)  — top $LIMIT"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL
  WHERE status_a IN ('failed','blocked') AND status_b='passed'
  ORDER BY test_id LIMIT $LIMIT;
"

e2e_section "Newly skipped  (passed/failed → skipped)  — top $LIMIT"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL
  WHERE status_a IN ('passed','failed','blocked') AND status_b='skipped'
  ORDER BY test_id LIMIT $LIMIT;
"

e2e_section "Newly executed  (skipped/absent → passed/failed)  — top $LIMIT"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL
  WHERE status_a IN ('skipped','(absent)') AND status_b IN ('passed','failed','blocked')
  ORDER BY test_id LIMIT $LIMIT;
"

e2e_section "Disappeared from run B  (present in A, absent in B)"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL WHERE status_b='(absent)' ORDER BY test_id LIMIT $LIMIT;
"

e2e_section "New in run B  (absent in A)"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL WHERE status_a='(absent)' ORDER BY test_id LIMIT $LIMIT;
"

if [[ -n "${INCLUDE_UNCHANGED:-}" ]]; then
    e2e_section "Unchanged status  — top $LIMIT"
    sqlite3 -bail -column -header "$E2E_DB" "
      $DIFF_SQL WHERE status_a = status_b ORDER BY status_a, test_id LIMIT $LIMIT;
    "
fi

e2e_section "Counts"
sqlite3 -bail -column -header "$E2E_DB" "
  $DIFF_SQL,
  classified AS (
      SELECT
          CASE
              WHEN status_a='passed' AND status_b IN ('failed','blocked') THEN 'regression'
              WHEN status_a IN ('failed','blocked') AND status_b='passed' THEN 'fix'
              WHEN status_a IN ('passed','failed','blocked') AND status_b='skipped' THEN 'newly_skipped'
              WHEN status_a IN ('skipped','(absent)') AND status_b IN ('passed','failed','blocked') THEN 'newly_executed'
              WHEN status_b='(absent)' THEN 'disappeared'
              WHEN status_a='(absent)' THEN 'new'
              WHEN status_a = status_b THEN 'unchanged'
              ELSE 'other'
          END AS bucket
        FROM (SELECT test_id, status_a, status_b FROM ($DIFF_SQL))
  )
  SELECT bucket, COUNT(*) AS n FROM classified GROUP BY bucket ORDER BY n DESC;
"
```

## Tip

Pair with `/e2e-test-specialist:report` for the full picture. The diff
surfaces *change*; the report surfaces *state*.
