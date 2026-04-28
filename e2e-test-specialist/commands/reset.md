---
description: Reset for a fresh end-to-end run — execute after-all hooks (teardown), abort active run, optionally clear history, optionally hard-wipe and re-import
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(rm:*), Bash(ls:*), Bash(cat:*), Read(*), Write(*)
argument-hint: [--clear-history] [--hard --ledger <path>] [--no-after-all] [--yes]
---

# /e2e-test-specialist:reset

Reset runtime state so the next `/autopilot` starts a fresh run from the
absolute beginning. Executes the active `after-all` lifecycle hooks first
(so any external infra — DO droplets, Forge servers, LBs — gets cleaned up
**before** state is discarded), then resets the run pointer and (optionally)
deeper state.

The catalog is **always preserved** unless you pass `--hard`. That means:

- `credentials`, `infrastructure`, `apps`, `sites`, `roles`, `integrations`
- `phases`, `tests`, `test_steps`, `step_assertions`, `test_dependencies`
- `directives`, `memories` (including authorizations), `lifecycle_hooks`
- `tags`, `test_tags`, `test_coverage_links`, `coverage_targets`

The next `/autopilot` will see the same authorizations, the same pre-run
hooks, the same test catalog — only the *run-level* state is gone.

## Modes (pick one)

### 1. Default — soft reset, history kept
```bash
/e2e-test-specialist:reset
```
- Run all active `after-all` hooks (teardown).
- Mark the active run `completed` (or leave the most-recent terminal run
  alone if there's no active run).
- Close any active session.
- Clear `state.active_run_id` / `state.active_session_id`.
- **Preserve everything else** — including `test_runs`, `step_executions`,
  `bugs`, `screenshots`. Useful as the standard "between-rounds" reset.

### 2. `--clear-history` — soft reset + delete run-level rows
```bash
/e2e-test-specialist:reset --clear-history --yes
```
Everything from default, then DELETE rows from:

- `assertion_results`, `coverage_hits` (cascades from step_executions, but
  done first to avoid lock contention)
- `bugs` (no FK cascade to test_runs → must delete before test_runs)
- `step_executions`, `screenshots` (cascades from test_runs)
- `sessions`, `directive_violations`, `resource_ledger`, `notifications`
- `test_runs`

Also wipes `.e2e-testing/runs/*` (per-run artifacts directory).

Catalog still preserved. The next `/autopilot` allocates `R-001` again.

### 3. `--hard --ledger <path>` — nuclear wipe + re-init + re-import
```bash
/e2e-test-specialist:reset --hard --ledger docs/e2e-testing.md --yes
```
Sequence:

1. Run `after-all` hooks (so infra is torn down before we lose state).
2. Delete `.e2e-testing/e2e-tests.sqlite` (+ `-wal`, `-shm`),
   `.e2e-testing/runs/`, `.e2e-testing/_backups/`.
3. Run `init-db.sh` to recreate the schema.
4. Run `import-ledger.py` against the provided ledger to repopulate.

**Catalog is gone after `--hard`.** Use this only when re-importing the
ledger from a clean slate is the explicit intent.

### Other flags

- `--no-after-all` — skip the after-all hook execution (e.g. when infra is
  already torn down or you just want to reset DB state without touching
  external systems).
- `--yes` — bypass the confirmation gate for `--clear-history` and `--hard`.
  The default mode never prompts.

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# Reap stale sessions so subsequent reads are accurate.
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" >/dev/null

# Resolve the run we'll wind down. Prefer the active run; fall back to the
# most-recent in-progress one (e.g. if state pointer is stale).
RUN_ID="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
if [[ -z "$RUN_ID" ]]; then
    RUN_ID="$(e2e_query_value "SELECT id FROM test_runs WHERE status='in-progress' ORDER BY started_at DESC LIMIT 1;")"
fi
if [[ -z "$RUN_ID" ]]; then
    RUN_ID="$(e2e_query_value "SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1;")"
fi

e2e_section "Reset target"
e2e_kv "run_id"   "${RUN_ID:-(none — fresh DB)}"
e2e_kv "mode"     "$([[ -n "${HARD:-}" ]] && echo hard || ([[ -n "${CLEAR_HISTORY:-}" ]] && echo clear-history || echo soft))"
e2e_kv "after-all" "$([[ -n "${NO_AFTER_ALL:-}" ]] && echo skip || echo execute)"

# === Confirmation gate for destructive modes ============================
if [[ -n "${CLEAR_HISTORY:-}" || -n "${HARD:-}" ]] && [[ -z "${YES:-}" ]]; then
    e2e_die "destructive mode requires --yes (or omit --clear-history/--hard for soft reset)"
fi

# === 1. Execute after-all hooks =========================================
if [[ -z "${NO_AFTER_ALL:-}" ]]; then
    e2e_section "Executing after-all hooks (teardown)"
    HAS_LH="$(e2e_query_value "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='lifecycle_hooks';")"
    if [[ "$HAS_LH" -eq 1 ]]; then
        HOOK_COUNT="$(e2e_query_value "SELECT COUNT(*) FROM lifecycle_hooks WHERE phase='post-run' AND active=1;")"
        if [[ "$HOOK_COUNT" -gt 0 ]]; then
            sqlite3 -bail -column -header "$E2E_DB" "
              SELECT id, title, enforcement, order_idx
                FROM lifecycle_hooks
               WHERE phase='post-run' AND active=1
               ORDER BY order_idx ASC, id ASC;
            "
            echo ""
            echo "The agent must read each hook's \`body\` and execute the"
            echo "instructions inside, in the order listed above. For each:"
            echo "  - success → log + continue"
            echo "  - blocking failure → write a memory and STOP the reset"
            echo "                       (run remains in-progress for inspection)"
            echo "  - advisory failure → log + memory + continue"
            echo ""
            echo "When all hooks complete, return here for the state-reset step."
        else
            echo "  (no active post-run hooks — nothing to execute)"
        fi
    fi
fi

# === 2. Close active session and run ====================================
if [[ -n "$RUN_ID" ]]; then
    e2e_section "Closing active session and run"
    e2e_exec "
      UPDATE sessions
         SET status='completed', ended_at=COALESCE(ended_at, datetime('now'))
       WHERE run_id=$(e2e_sql_quote "$RUN_ID")
         AND status IN ('active','crashed','paused');

      UPDATE test_runs
         SET status=CASE WHEN status='in-progress' THEN 'completed' ELSE status END,
             ended_at=COALESCE(ended_at, datetime('now'))
       WHERE id=$(e2e_sql_quote "$RUN_ID");

      UPDATE state
         SET active_run_id=NULL,
             active_session_id=NULL,
             last_update=datetime('now')
       WHERE id=1;
    "
fi

# === 3. Clear history (--clear-history mode) ============================
if [[ -n "${CLEAR_HISTORY:-}" ]]; then
    e2e_section "Wiping run-level rows (catalog preserved)"
    # Delete in dependency order. With foreign_keys=ON, CASCADE handles
    # step_executions and screenshots, but bugs need explicit delete first.
    e2e_exec "
      BEGIN;
      DELETE FROM assertion_results;
      DELETE FROM coverage_hits;
      DELETE FROM bugs;
      DELETE FROM step_executions;
      DELETE FROM screenshots;
      DELETE FROM sessions;
      DELETE FROM directive_violations;
      DELETE FROM resource_ledger;
      DELETE FROM notifications;
      DELETE FROM test_runs;
      UPDATE state SET active_run_id=NULL, active_session_id=NULL,
                       last_update=datetime('now') WHERE id=1;
      COMMIT;
    "

    if [[ -d "$E2E_ROOT_DIR/runs" ]]; then
        rm -rf "$E2E_ROOT_DIR/runs"/*
        echo "  cleared $E2E_ROOT_DIR/runs/"
    fi
fi

# === 4. Hard wipe (--hard mode) =========================================
if [[ -n "${HARD:-}" ]]; then
    e2e_section "Hard wipe (.sqlite + runs + _backups)"
    [[ -n "${LEDGER:-}" && -f "$LEDGER" ]] \
        || e2e_die "--hard requires --ledger <path-to-existing-ledger.md>"

    rm -f "$E2E_ROOT_DIR/e2e-tests.sqlite" \
          "$E2E_ROOT_DIR/e2e-tests.sqlite-wal" \
          "$E2E_ROOT_DIR/e2e-tests.sqlite-shm"
    rm -rf "$E2E_ROOT_DIR/runs" "$E2E_ROOT_DIR/_backups"

    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-db.sh"
    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/import-ledger.py" "$LEDGER"
    echo "  re-init + re-import complete from $LEDGER"
fi

# === 5. Final state summary =============================================
e2e_section "Done"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT
    (SELECT COUNT(*) FROM phases)                                      AS phases,
    (SELECT COUNT(*) FROM tests WHERE deprecated_at IS NULL)           AS tests,
    (SELECT COUNT(*) FROM credentials)                                  AS credentials,
    (SELECT COUNT(*) FROM lifecycle_hooks WHERE active=1)              AS hooks,
    (SELECT COUNT(*) FROM memories
        WHERE status='active' AND importance>=4
          AND (tags LIKE '%\"authorization\"%'
               OR tags LIKE '%\"standing-grant\"%'))                    AS authorizations,
    (SELECT COUNT(*) FROM test_runs)                                    AS run_history;
"

echo ""
echo "Ready for a fresh end-to-end run:"
echo "  /e2e-test-specialist:autopilot           # uses APP_URL from .env"
echo "  /e2e-test-specialist:autopilot --dry-run # confirm briefing + queue first"
```

## Mental model

| Bucket                       | Default | --clear-history | --hard |
|------------------------------|:-------:|:---------------:|:------:|
| Active run + session pointer | reset   | reset           | wiped  |
| Run history (test_runs, step_executions, bugs, screenshots) | kept | **deleted** | wiped |
| Catalog (phases / tests / steps / dependencies) | kept | kept            | wiped (re-imported) |
| Credentials / infrastructure / apps / sites / roles | kept | kept            | wiped (re-imported) |
| Directives / memories / authorizations / hooks | kept | kept            | wiped (re-imported) |
| `.e2e-testing/runs/*` artifacts | kept | deleted         | deleted |
| `.e2e-testing/_backups/*`    | kept   | kept            | deleted |
| External infra (DO / Forge / LBs) | torn down by after-all hooks | torn down by after-all hooks | torn down by after-all hooks |

## Choosing a mode

- **You want a clean slate but keep run history for trend analysis** →
  default. `/autopilot` will start fresh `R-NNN+1`.
- **You want to start the R-NNN counter over without changing the test
  plan** → `--clear-history --yes`.
- **You want to re-import a substantially-different ledger and start
  truly fresh** → `--hard --ledger <path> --yes`.

## See also

- `/e2e-test-specialist:after-all` — manage post-run hooks (the teardown
  procedures `/reset` will execute)
- `/e2e-test-specialist:before-all` — manage pre-run hooks (the next
  `/autopilot` will execute these at step 3.5)
- `/e2e-test-specialist:authorize` — standing grants the next briefing
  surfaces (preserved across all reset modes except `--hard`)
- `/e2e-test-specialist:doctor` — verify the post-reset state is healthy
