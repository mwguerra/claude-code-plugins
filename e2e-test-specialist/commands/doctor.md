---
description: Plugin health-check — schema version, table integrity, dangling references, stale sessions, backup state
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(ls:*), Read(*)
argument-hint: [--fix-stale-sessions] [--verbose]
---

# /e2e-test-specialist:doctor

Single-shot health check against `.e2e-testing/`. Run after upgrades, before
big changes, or whenever something feels off. The doctor reports — it does
not fix things by default. Pass `--fix-stale-sessions` to reap obviously-dead
sessions; everything else is informational.

## What it checks

- **Schema version** vs. expected (`1.4.0` for plugin v2.6.0+).
- **Required tables** present (`directives`, `phases`, `tests`, `test_steps`,
  `test_runs`, `step_executions`, `sessions`, `state`, `memories`,
  `lifecycle_hooks`, `test_coverage_links`, `notifications`, `resource_ledger`).
- **Required views** present (`v_run_progress`, `v_test_results_by_subject`,
  `v_flaky_steps`, `v_skip_rollup`, `v_latest_step_status`,
  `v_latest_test_status`).
- **Dangling JSON refs** — `tests.applies_to` IDs that no longer resolve
  (deleted apps / infrastructure / sites / roles).
- **Stale sessions** — heartbeat older than `crash_detection.heartbeat_stale_seconds`.
- **Orphan executions** — `step_executions` whose `step_id`/`test_id` no
  longer exist (would only happen with manual deletes).
- **Backup state** — count, total size, oldest/newest under `_backups/`.
- **Concurrent runs** — should be at most one `in-progress` row.
- **Importable ledger sections** — checks taxonomy file is readable.
- **Suspicious counts** — phases with 0 tests, tests with 0 steps,
  authorization memories with `tags` not parseable as JSON.

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

EXPECTED_SCHEMA="1.4.0"
ISSUES=0

e2e_section "Schema"
v="$(e2e_query_value 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
e2e_kv "version" "$v"
if [[ "$v" != "$EXPECTED_SCHEMA" ]]; then
    echo "  ✗ expected $EXPECTED_SCHEMA — run /e2e-test-specialist:init to migrate"
    ISSUES=$((ISSUES+1))
else
    echo "  ✓ matches expected"
fi

# --- required objects ---
check_object() {
    local kind="$1" name="$2"
    local n
    n="$(e2e_query_value "SELECT COUNT(*) FROM sqlite_master WHERE type='$kind' AND name='$name';")"
    if [[ "$n" -eq 1 ]]; then
        echo "  ✓ $kind: $name"
    else
        echo "  ✗ MISSING $kind: $name"
        ISSUES=$((ISSUES+1))
    fi
}

e2e_section "Tables"
for t in directives phases tests test_steps test_runs step_executions sessions state memories lifecycle_hooks test_coverage_links notifications resource_ledger; do
    check_object table "$t"
done

e2e_section "Views"
for v in v_run_progress v_test_results_by_subject v_flaky_steps v_skip_rollup v_latest_step_status v_latest_test_status; do
    check_object view "$v"
done

e2e_section "Dangling subject references in tests.applies_to"
DANGLING="$(e2e_query "
  SELECT t.id, t.applies_to
    FROM tests t, json_each(t.applies_to) j
   WHERE t.deprecated_at IS NULL
     AND j.value NOT LIKE 'ROLE-%'
     AND j.value NOT LIKE 'VP-%'
     AND j.value NOT IN (SELECT id FROM apps)
     AND j.value NOT IN (SELECT id FROM infrastructure)
     AND j.value NOT IN (SELECT id FROM sites);
")"
if [[ -z "$DANGLING" ]]; then
    echo "  ✓ none"
else
    echo "$DANGLING"
    ISSUES=$((ISSUES+1))
fi

e2e_section "Concurrent in-progress runs (should be ≤ 1)"
NRUN="$(e2e_query_value "SELECT COUNT(*) FROM test_runs WHERE status='in-progress';")"
echo "  in-progress runs: $NRUN"
[[ "$NRUN" -le 1 ]] || { echo "  ✗ multiple in-progress runs — pick one to /restart, abort the others"; ISSUES=$((ISSUES+1)); }

e2e_section "Stale sessions"
STALE_SEC="$(e2e_config_get crash_detection.heartbeat_stale_seconds 1200)"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id, run_id, status, last_heartbeat,
         CAST((julianday('now') - julianday(last_heartbeat)) * 86400 AS INTEGER) AS age_sec
    FROM sessions
   WHERE status IN ('active','crashed','paused')
     AND CAST((julianday('now') - julianday(last_heartbeat)) * 86400 AS INTEGER) > $STALE_SEC
   ORDER BY age_sec DESC;
"
if [[ -n "${FIX_STALE:-}" ]]; then
    echo "  reaping stale sessions per --fix-stale-sessions..."
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" >/dev/null
fi

e2e_section "Orphan step_executions (FK should prevent these but in case of manual deletes)"
ORPHANS="$(e2e_query_value "
  SELECT COUNT(*) FROM step_executions e
   WHERE NOT EXISTS (SELECT 1 FROM tests t WHERE t.id = e.test_id)
      OR NOT EXISTS (SELECT 1 FROM test_steps s WHERE s.id = e.step_id);
")"
echo "  orphan rows: $ORPHANS"
[[ "$ORPHANS" -eq 0 ]] || ISSUES=$((ISSUES+1))

e2e_section "Suspicious counts"
EMPTY_PHASES="$(e2e_query_value 'SELECT COUNT(*) FROM phases p WHERE NOT EXISTS (SELECT 1 FROM tests t WHERE t.phase_id = p.id);')"
EMPTY_TESTS="$(e2e_query_value "SELECT COUNT(*) FROM tests t WHERE t.deprecated_at IS NULL AND NOT EXISTS (SELECT 1 FROM test_steps s WHERE s.test_id = t.id);")"
echo "  phases with 0 tests: $EMPTY_PHASES"
echo "  tests with 0 steps : $EMPTY_TESTS"

e2e_section "Authorization memories"
AUTHS="$(e2e_query_value "
  SELECT COUNT(*) FROM memories
   WHERE status='active' AND importance >= 4
     AND (tags LIKE '%\"authorization\"%' OR tags LIKE '%\"standing-grant\"%');
")"
BADJSON="$(e2e_query_value "SELECT COUNT(*) FROM memories WHERE json_valid(tags)=0;")"
echo "  active authorization memories: $AUTHS"
echo "  memories with malformed tags JSON: $BADJSON"
[[ "$BADJSON" -eq 0 ]] || ISSUES=$((ISSUES+1))

e2e_section "Backups"
BACKUP_DIR="$E2E_ROOT_DIR/_backups"
if [[ -d "$BACKUP_DIR" ]]; then
    NB="$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l | tr -d ' ')"
    echo "  count: $NB"
    if [[ "$NB" -gt 0 ]]; then
        echo "  newest: $(ls -1t "$BACKUP_DIR" | head -1)"
        echo "  oldest: $(ls -1t "$BACKUP_DIR" | tail -1)"
        SIZE="$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')"
        echo "  total size: $SIZE"
        [[ "$NB" -le 50 ]] || echo "  → consider /e2e-test-specialist running scripts/prune-backups.sh"
    fi
else
    echo "  (no _backups/ yet)"
fi

e2e_section "Verdict"
if [[ "$ISSUES" -eq 0 ]]; then
    echo "  ✓ healthy"
    exit 0
else
    echo "  ✗ $ISSUES issue(s) found — see above"
    exit 1
fi
```

## Exit code

`0` healthy, `1` one or more issues. Useful in cron/CI gating.

## See also

- `/e2e-test-specialist:status` — runtime state (what's happening now)
- `/e2e-test-specialist:schema` — column/view discoverability
