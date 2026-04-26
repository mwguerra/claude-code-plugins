---
description: Show current e2e-testing state — active run, session liveness, progress, and next pending step
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: (no arguments)
---

# /e2e-test-specialist:status

Prints a quick "where am I" snapshot of the e2e-testing project state.

## What you'll see

- Schema version + DB size
- Counts: directives, credentials, infrastructure, apps, phases, tests, steps, runs
- The active run (if any), with progress: passed/failed/skipped/in-progress steps
- Session liveness: whether the active session's heartbeat is fresh, stale, or crashed
- Next pending step (test_id, step_id, action excerpt)
- Last 5 entries from the activity log

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# Reap any stale sessions first so the report is accurate
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" >/dev/null

e2e_section "Schema"
e2e_kv "version"   "$(e2e_query_value 'SELECT version FROM schema_version;')"
e2e_kv "db path"   "$E2E_DB"

e2e_section "Counts"
for pair in \
    "directives:directives" \
    "credentials:credentials" \
    "infrastructure:infrastructure" \
    "apps:apps" \
    "phases:phases" \
    "tests:tests WHERE deprecated_at IS NULL" \
    "steps:test_steps" \
    "runs:test_runs" \
    "memories:memories"; do
    label="${pair%%:*}"
    sql="SELECT COUNT(*) FROM ${pair#*:};"
    e2e_kv "$label" "$(e2e_query_value "$sql")"
done

e2e_section "Active run"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT r.id, r.label, r.status, r.started_at,
         p.steps_passed, p.steps_failed, p.steps_skipped, p.steps_in_progress
    FROM test_runs r
    LEFT JOIN v_run_progress p ON p.run_id = r.id
   WHERE r.status = 'in-progress'
   ORDER BY r.started_at DESC
   LIMIT 1;
"

e2e_section "Session"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT s.id, s.status,
         s.last_heartbeat,
         CAST((julianday('now') - julianday(s.last_heartbeat)) * 86400 AS INTEGER) AS heartbeat_age_sec,
         s.current_test_id, s.current_step_id
    FROM sessions s
   WHERE s.id = (SELECT active_session_id FROM state WHERE id=1)
      OR s.status IN ('active','crashed')
   ORDER BY s.last_heartbeat DESC
   LIMIT 5;
"

e2e_section "Recovery hint"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh"

# === Diagnostic surfaces — what failed, what's pending ====================
ACTIVE_RUN="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
if [[ -n "$ACTIVE_RUN" ]]; then
    e2e_section "Last 5 failures in $ACTIVE_RUN  (drill in: /e2e-test-specialist:failures)"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT se.test_id, se.step_id, se.status,
             COALESCE(substr(se.error_message,1,60),'') AS error_excerpt,
             COALESCE(se.completed_at, se.started_at) AS at
        FROM step_executions se
       WHERE se.run_id = $(e2e_sql_quote "$ACTIVE_RUN")
         AND se.status IN ('failed','skipped','blocked')
       ORDER BY COALESCE(se.completed_at, se.started_at, se.created_at) DESC
       LIMIT 5;
    "

    e2e_section "Pending in $ACTIVE_RUN  (drill in: /e2e-test-specialist:pending)"
    sqlite3 -bail -column -header "$E2E_DB" "
      WITH latest_exec AS (
          SELECT step_id, status,
                 ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY created_at DESC) AS rn
            FROM step_executions
           WHERE run_id = $(e2e_sql_quote "$ACTIVE_RUN")
      )
      SELECT
        (SELECT COUNT(*) FROM test_steps s
           LEFT JOIN latest_exec le ON le.step_id = s.id AND le.rn = 1
          WHERE le.status IS NULL OR le.status IN ('pending','in-progress')) AS pending_steps,
        (SELECT COUNT(DISTINCT t.id) FROM tests t
           JOIN test_steps s ON s.test_id = t.id
           LEFT JOIN latest_exec le ON le.step_id = s.id AND le.rn = 1
          WHERE (le.status IS NULL OR le.status IN ('pending','in-progress'))
            AND t.deprecated_at IS NULL) AS pending_tests;
    "

    e2e_section "Sessions for $ACTIVE_RUN  (drill in: /e2e-test-specialist:sessions)"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, status, started_at, last_heartbeat, ended_at
        FROM sessions
       WHERE run_id = $(e2e_sql_quote "$ACTIVE_RUN")
       ORDER BY started_at DESC
       LIMIT 3;
    "
fi

e2e_section "Flaky steps (passed AND failed across runs)"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT step_id, test_id, pass_count, fail_count, run_count, last_seen
    FROM v_flaky_steps ORDER BY fail_count DESC LIMIT 10;
" 2>/dev/null || echo "(none yet)"

e2e_section "Directive violations (last 5)"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id, enforcement, action_kind, substr(description,1,60) AS description, created_at
    FROM directive_violations ORDER BY created_at DESC LIMIT 5;
" 2>/dev/null || echo "(none)"

e2e_section "Policy customization"
RETRY_HASH="$(shasum '${CLAUDE_PLUGIN_ROOT}/scripts/retry-policy.sh' | awk '{print $1}')"
DIR_HASH="$(shasum   '${CLAUDE_PLUGIN_ROOT}/scripts/directive-check.sh' | awk '{print $1}')"
# Compare against a known "out-of-the-box" hash baked here at release time.
# If they match, the user hasn't customized the TODO blocks.
e2e_kv "retry-policy.sh"     "(local: ${RETRY_HASH:0:8} — see scripts/retry-policy.sh TODO block)"
e2e_kv "directive-check.sh"  "(local: ${DIR_HASH:0:8}   — see scripts/directive-check.sh TODO block)"
e2e_kv "config: heartbeat_stale_seconds" "$(e2e_config_get crash_detection.heartbeat_stale_seconds 1200)"

e2e_section "Last backup"
LATEST_BACKUP="$(ls -1t $E2E_ROOT_DIR/runs/_backups/*.sqlite 2>/dev/null | head -1)"
if [[ -n "$LATEST_BACKUP" ]]; then
    e2e_kv "path"       "$LATEST_BACKUP"
    e2e_kv "size"       "$(ls -lh "$LATEST_BACKUP" | awk '{print $5}')"
    e2e_kv "created"    "$(stat -f '%Sm' "$LATEST_BACKUP" 2>/dev/null || stat -c '%y' "$LATEST_BACKUP" 2>/dev/null)"
else
    echo "(no backups yet)"
fi

e2e_section "Recent activity"
tail -n 5 "$E2E_LOG" 2>/dev/null || echo "(no log yet)"
```

## Notes

- If `Recovery hint` shows `crashed_session: { … }` and `next_pending_step: { … }`,
  resume with `/e2e-test-specialist:resume`.
- If no `.e2e-testing/` exists, the helper prints a clear error and points the
  user at `/e2e-test-specialist:init`.
