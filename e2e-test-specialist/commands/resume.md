---
description: Resume the active run after a crash, broken session, or paused state
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: (no arguments)
---

# /e2e-test-specialist:resume

Detect the most recent crashed (or paused) session, open a fresh session
attached to the same run, and resume execution from the last unfinished step.

## Process

### 1. Reap stale sessions and read recovery state

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" > /tmp/e2e-recovery.json
cat /tmp/e2e-recovery.json
```

The output is JSON with `active_run_id`, `crashed_session`, and
`next_pending_step`.

### 2. Decide what to resume

- **`active_run_id` is null** → no run to resume. Suggest
  `/e2e-test-specialist:start`.
- **`crashed_session` is non-null and `next_pending_step` is non-null** →
  proceed to resume.
- **`crashed_session` is null but a run is `in-progress`** → likely the
  previous session ended cleanly without finishing. Treat as "continue from
  next pending step".
- **No `next_pending_step`** → all steps are terminal. Ask the user if the
  run should be marked completed or if more work is expected.

If multiple crashed sessions exist (rare — only with manual DB edits), prefer
the one with the latest `last_heartbeat`.

### 3. Confirm with the user

Before mutating anything, surface the situation. Use `AskUserQuestion`:

```
A previous session crashed in run R-NNN.
  Last heartbeat: 2026-04-25T01:42:11Z (heartbeat went stale ~32 minutes ago)
  Last test:      T-04.03 "Site Creation — todo wizard"
  Last step:      S-04.03.005 "Click Create"
  Action:         Click 'Create' button on the wizard's review step

Resume from this step?
```

Options:
- **Yes, resume** → continue to step 4
- **Yes, but skip that step** (mark it failed/blocked first) → record the
  user's choice in `step_executions` then resume from the *next* step
- **No, abort run** → call `/e2e-test-specialist:restart` instead

### 4. Open a new session attached to the same run

```bash
SESSION_ID="$(e2e_session_start "$ACTIVE_RUN_ID")"
e2e_session_set_pointer "$NEXT_TEST_ID" "$NEXT_STEP_ID" ""
e2e_log INFO resume "resumed run=$ACTIVE_RUN_ID at $NEXT_TEST_ID/$NEXT_STEP_ID (new session=$SESSION_ID)"
```

### 5. Re-validate the runtime environment before resuming

The world has likely moved while you were away — assume nothing:

- Re-run `mcp__playwright__browser_install` if the browser is gone.
- Re-navigate to the run's `base_url` and `mcp__playwright__browser_snapshot`
  to confirm we're still pointing at the expected application.
- If the run was mid-login, **re-establish authentication** before resuming
  the next step. Many tests assume a logged-in session that won't survive a
  Claude restart.
- For Laravel/PrimeForge-style runs: re-detect docker-local + WireGuard mesh
  status via SSH read-only checks before assuming the panel is reachable.

Tick heartbeat after each of the above with
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh"`.

### 6. Hand off to /test

Print:

```
Resumed run $ACTIVE_RUN_ID.
  Next test: $NEXT_TEST_ID — $NEXT_TEST_TITLE
  Next step: $NEXT_STEP_ID — $NEXT_STEP_ACTION

Continue execution with: /e2e-test-specialist:test
```

## Notes

- The `crash_detection.heartbeat_stale_seconds` config controls how long until
  an active session is reaped as crashed (default 1200s). If a run has long
  legitimate steps (apt locks, image transfers), bump this in
  `.e2e-testing/config.json`.
- A session in `paused` status is also resumable via this command — the same
  flow applies, just without the "crashed" framing.
