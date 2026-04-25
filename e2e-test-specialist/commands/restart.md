---
description: Abort the active run and start a fresh one (destructive — confirms first)
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [<base-url>] [--label "..."] [--phase ...] [--tag ...] [--skip-tag ...]
---

# /e2e-test-specialist:restart

Abort the currently active run and immediately start a new one with the same
or different filters. **This is destructive** — the in-progress run will be
marked `aborted` and its sessions ended. All historical
`step_executions`/`bugs`/`screenshots` from the aborted run are preserved.

## Process

### 1. Confirm with the user

Use `AskUserQuestion` to confirm. Show what will be aborted:

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT r.id, r.label, r.started_at,
         p.steps_passed, p.steps_failed, p.steps_in_progress
    FROM test_runs r
    LEFT JOIN v_run_progress p ON p.run_id = r.id
   WHERE r.status = 'in-progress';
"
```

Ask: "Abort this run and start a new one? Pass/fail history is preserved.
The in-progress run row will be marked `aborted`."

### 2. Backup before destructive change

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-restart
```

### 3. Abort active run + sessions

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

e2e_exec "
    UPDATE sessions
       SET status='aborted', ended_at=datetime('now')
     WHERE status IN ('active','crashed','paused');
    UPDATE test_runs
       SET status='aborted', ended_at=datetime('now')
     WHERE status='in-progress';
    UPDATE state
       SET active_session_id=NULL, active_run_id=NULL, last_update=datetime('now')
     WHERE id=1;
"
e2e_log INFO restart "aborted in-progress run + sessions"
```

### 4. Delegate to /start

Hand off to `/e2e-test-specialist:start` with the same arguments the user
passed (or empty arguments for a default fresh run). The behaviour from there
is identical to a normal start.

## Notes

- `restart` is for the *common* case: "I broke something mid-run, let me
  scrap and try again". For partial recovery from a single bad step, use
  `/e2e-test-specialist:resume` and skip the offending step instead.
- If you want to delete all history (not just abort), open the database
  manually and `DELETE FROM test_runs;` — this command intentionally does not
  expose that.
