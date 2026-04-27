---
description: Translate current state into actionable next moves — open bugs, untouched tests, stale memories, missing authorizations
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: (no arguments)
---

# /e2e-test-specialist:recommend

Reads `state`, `test_runs`, `step_executions`, `bugs`, `memories`,
`lifecycle_hooks`, `notifications` — and tells you what to do next, ranked
by leverage. Closes the "I see the status, now what?" loop.

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" >/dev/null

ACTIVE_RUN="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
LATEST_RUN="$(e2e_query_value "SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1;")"

e2e_section "Recommendations (ranked by impact)"

# 1. Crashed session?
CRASHED="$(e2e_query_value "
  SELECT COUNT(*) FROM sessions
   WHERE status='crashed' AND ended_at IS NULL;
")"
if [[ "$CRASHED" -gt 0 ]]; then
    echo "  [HIGH] $CRASHED crashed session(s) waiting → /e2e-test-specialist:resume"
fi

# 2. Active run with pending work?
if [[ -n "$ACTIVE_RUN" ]]; then
    PEND="$(e2e_query_value "
      WITH latest AS (
          SELECT step_id, status,
                 ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY created_at DESC) AS rn
            FROM step_executions WHERE run_id=$(e2e_sql_quote "$ACTIVE_RUN")
      )
      SELECT COUNT(*) FROM test_steps s
        LEFT JOIN latest le ON le.step_id=s.id AND le.rn=1
       WHERE le.status IS NULL OR le.status IN ('pending','in-progress');
    ")"
    if [[ "$PEND" -gt 0 ]]; then
        echo "  [HIGH] $ACTIVE_RUN has $PEND pending step(s) → /e2e-test-specialist:autopilot  (or /test --batch 9999)"
    fi
fi

# 3. Failed steps in the most recent run?
if [[ -n "$LATEST_RUN" ]]; then
    FAIL="$(e2e_query_value "
      SELECT COUNT(*) FROM v_latest_step_status WHERE run_id=$(e2e_sql_quote "$LATEST_RUN") AND status='failed';
    " 2>/dev/null || echo 0)"
    if [[ "$FAIL" -gt 0 ]]; then
        echo "  [HIGH] $FAIL failed step(s) in $LATEST_RUN → /e2e-test-specialist:fix-failures $LATEST_RUN"
    fi
fi

# 4. Skips that an /authorize could recover?
SKIPS_NO_AUTH="$(e2e_query_value "
  SELECT COUNT(*) FROM v_skip_rollup
   WHERE skip_reason='no-authorization';
" 2>/dev/null || echo 0)"
if [[ "$SKIPS_NO_AUTH" -gt 0 ]]; then
    echo "  [MED]  $SKIPS_NO_AUTH skipped step(s) blocked on missing authorization → /e2e-test-specialist:skipped --explain  then  /e2e-test-specialist:authorize"
fi

# 5. Open critical/high bugs?
BUGS="$(e2e_query_value "
  SELECT COUNT(*) FROM bugs WHERE status='open' AND severity IN ('critical','high');
")"
if [[ "$BUGS" -gt 0 ]]; then
    echo "  [MED]  $BUGS open critical/high bug(s) → /e2e-test-specialist:bugs"
fi

# 6. Pending notifications?
NOTIFS="$(e2e_query_value "
  SELECT COUNT(*) FROM notifications WHERE status='pending';
" 2>/dev/null || echo 0)"
if [[ "$NOTIFS" -gt 0 ]]; then
    echo "  [LOW]  $NOTIFS pending notification(s) → /e2e-test-specialist:notify --send"
fi

# 7. No authorizations on file but a recent run had skips → suggest seed grant.
AUTH_COUNT="$(e2e_query_value "
  SELECT COUNT(*) FROM memories
   WHERE status='active' AND importance >= 4
     AND (tags LIKE '%\"authorization\"%' OR tags LIKE '%\"standing-grant\"%');
")"
if [[ "$AUTH_COUNT" -eq 0 && "$SKIPS_NO_AUTH" -gt 0 ]]; then
    echo "  [LOW]  no authorizations on file → consider /e2e-test-specialist:authorize 'Provision E2E infra'"
fi

# 8. Stale flaky steps? (passed AND failed across runs — not yet quarantined)
FLAKY="$(e2e_query_value "
  SELECT COUNT(*) FROM v_flaky_steps;
" 2>/dev/null || echo 0)"
if [[ "$FLAKY" -gt 5 ]]; then
    echo "  [LOW]  $FLAKY flaky step(s) → review v_flaky_steps and quarantine the worst with skip_reason='flake-quarantine'"
fi

# 9. No backups in 7 days?
BACKUP_DIR="$E2E_ROOT_DIR/_backups"
if [[ -d "$BACKUP_DIR" ]]; then
    NEWEST="$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)"
    if [[ -n "$NEWEST" ]]; then
        AGE_DAYS="$(stat -f '%m' "$BACKUP_DIR/$NEWEST" 2>/dev/null || stat -c '%Y' "$BACKUP_DIR/$NEWEST" 2>/dev/null)"
        NOW="$(date +%s)"
        DAYS=$(( (NOW - AGE_DAYS) / 86400 ))
        if [[ "$DAYS" -gt 7 ]]; then
            echo "  [LOW]  no backup in $DAYS days → /e2e-test-specialist run scripts/backup-db.sh manual"
        fi
    fi
fi

# 10. Schema upgrade pending?
v="$(e2e_query_value 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
if [[ "$v" != "1.4.0" ]]; then
    echo "  [HIGH] schema $v < 1.4.0 → /e2e-test-specialist:init   (will migrate)"
fi

# Done
COUNT="$(echo -e "$CRASHED\n$PEND\n$FAIL\n$SKIPS_NO_AUTH\n$BUGS\n$NOTIFS\n$FLAKY" | grep -v '^0$' | wc -l)"
if [[ "${COUNT:-0}" -eq 0 ]]; then
    echo "  ✓ nothing pressing — start a new round when ready: /e2e-test-specialist:autopilot"
fi
```

## See also

- `/e2e-test-specialist:status` — raw state snapshot
- `/e2e-test-specialist:doctor` — health check
- `/e2e-test-specialist:diff` — what changed between runs
