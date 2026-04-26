---
description: Re-attempt failed step_executions in a run via the ultrathink fix loop (default no fix-attempt cap)
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(ssh:*), Bash(curl:*), Bash(grep:*), Bash(cat:*), Bash(ls:*), Read(*), Write(*), mcp__playwright__*, mcp__plugin_playwright_playwright__*
argument-hint: [<run-id>] [--max-fix-attempts N] [--test T-04.03] [--phase P04,P05]
---

# /e2e-test-specialist:fix-failures

Re-execute the steps that ended in `failed` status during a run, applying
the Ultrathink Root Cause loop on each one. Defaults to the most recent
completed run when called with no args; use `<run-id>` to target a specific
run, or `--test`/`--phase` to scope to a subset.

This is the "after the run" companion to `/autopilot`'s in-flight fix loop.
The autopilot caps in-flight fix attempts at 5 by default to keep forward
progress; `/fix-failures` removes that cap so genuine product bugs get
fixed even if they need many evidence cycles.

## When to use

- Autopilot just finished and reported `12 steps failed` — those are bugs
  that need fixing, not skips. Run this to revisit them.
- A user fixed something externally (deploy, config, dependency upgrade)
  and wants to retry only the previously-failing steps.
- Triaging a stale run: walk the failures with full evidence, decide
  which are real product bugs vs. flakes vs. fixed-since.

## Modes

| Form                              | Effect                                                   |
|-----------------------------------|----------------------------------------------------------|
| (no args)                         | All `failed` steps in the most recent completed run      |
| `<run-id>`                        | All `failed` steps in the named run                      |
| `--test T-04.03`                  | Only failures for the given test                         |
| `--phase P04,P05`                 | Only failures from the listed phases                     |
| `--max-fix-attempts N`            | Per-step cap (default: 0 = unlimited)                    |

## Behavior

### 1. Pre-flight

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" >/dev/null

MAX_FIX_ATTEMPTS="${MAX_FIX_ATTEMPTS:-0}"   # 0 = unlimited

# Scope to a run
if [[ -z "${RUN_ID:-}" ]]; then
    RUN_ID="$(e2e_query_value "
      SELECT id FROM test_runs
       WHERE status IN ('completed','in-progress','aborted')
       ORDER BY started_at DESC LIMIT 1;
    ")"
    [[ -n "$RUN_ID" ]] || e2e_die "no runs in DB; nothing to fix"
fi
```

### 2. Build the failure work-list

```bash
# Optional filters
TEST_FILTER=""
[[ -n "${TEST_ID:-}" ]] && TEST_FILTER="AND se.test_id = $(e2e_sql_quote "$TEST_ID")"

PHASE_FILTER=""
if [[ -n "${PHASES:-}" ]]; then
    PHASE_LIST="$(printf "%s" "$PHASES" | awk -v RS=, '{printf "%s\"%s\"", (NR>1?",":""), $1}')"
    PHASE_FILTER="AND t.phase_id IN ($PHASE_LIST)"
fi

# Distinct failing (test_id, step_id) pairs in this run, taking only the
# LATEST execution status per step (so steps later fixed manually but never
# re-run aren't included).
WORKLIST="$(e2e_query "
  WITH latest AS (
      SELECT step_id, status,
             ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY created_at DESC) AS rn,
             test_id, error_message
        FROM step_executions
       WHERE run_id = $(e2e_sql_quote "$RUN_ID")
  )
  SELECT DISTINCT l.test_id, l.step_id, t.title, t.phase_id, l.error_message
    FROM latest l
    JOIN tests t ON t.id = l.test_id
   WHERE l.rn = 1 AND l.status = 'failed'
     AND t.deprecated_at IS NULL
     $TEST_FILTER
     $PHASE_FILTER
   ORDER BY t.phase_id, t.test_order, l.step_id;
")"

WORK_COUNT="$(printf '%s\n' "$WORKLIST" | grep -c '|' || echo 0)"
e2e_log "fix-failures: $WORK_COUNT failed step(s) to revisit in $RUN_ID"
[[ "$WORK_COUNT" -gt 0 ]] || { echo "No failed steps to fix in $RUN_ID."; exit 0; }
```

### 3. Reactivate the run for live work

If the run is already `completed` or `aborted`, mark it `in-progress` for
the duration of fix-failures (autopilot's resume contract requires an
active run for new step_executions to be inserted cleanly). Open a new
session.

```bash
e2e_exec "
  UPDATE test_runs
     SET status='in-progress', ended_at=NULL
   WHERE id = $(e2e_sql_quote "$RUN_ID");
  UPDATE state SET active_run_id = $(e2e_sql_quote "$RUN_ID"), last_update=datetime('now') WHERE id=1;
"
SESSION_ID="$(e2e_session_start "$RUN_ID")"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh"
```

### 4. Per-failure fix loop

Iterate the WORKLIST. For each (test_id, step_id):

```text
1. Capture fresh evidence:
     - Re-read the test's source markdown via tests.raw_markdown
     - Re-read the step's action via test_steps.action
     - Pull the latest error_message + evidence_snapshot from step_executions
     - Pull any open bug rows linked to bug_id

2. Execute the Ultrathink Root Cause loop EXACTLY as defined in
   agents/e2e-test-agent.md and commands/test.md step 7:
     i.   Capture evidence (artifacts, console, network, DB state)
     ii.  Form a hypothesis about the root cause
     iii. Verify the hypothesis against source code / DB / logs
     iv.  Apply the smallest correct fix in the project source
     v.   Add a regression test or assertion proving the fix
     vi.  Redeploy / restart the affected service if needed
     vii. Re-run the step (insert a new step_executions row with retry_attempt+1)

3. After re-run:
     - status='passed' → log + continue to next failure
     - status='failed' AND MAX_FIX_ATTEMPTS == 0 → loop back to step 1
       on the same failure (unbounded)
     - status='failed' AND attempts >= MAX_FIX_ATTEMPTS → mark blocked,
       write a memory (kind='bug-pattern', importance=5), continue to
       next failure

4. Update the bug row (if any):
     - root_cause = <hypothesis verified at step iii>
     - fix_applied = <short summary of the change>
     - fix_commit = <git rev-parse HEAD if a commit was made>
     - status = 'fixed' (when the re-run passes) or 'investigating' (still failing)
```

### 5. Final accounting

When the worklist is empty:

```bash
# Restore the run to a sensible terminal status: 'completed' if zero
# failures remain, otherwise 'in-progress' so the user can iterate again.
REMAINING="$(e2e_query_value "
  WITH latest AS (
      SELECT step_id, status,
             ROW_NUMBER() OVER (PARTITION BY step_id ORDER BY created_at DESC) AS rn
        FROM step_executions
       WHERE run_id = $(e2e_sql_quote "$RUN_ID")
  )
  SELECT COUNT(*) FROM latest WHERE rn=1 AND status='failed';
")"

if [[ "$REMAINING" -eq 0 ]]; then
    e2e_exec "UPDATE test_runs SET status='completed', ended_at=datetime('now') WHERE id=$(e2e_sql_quote "$RUN_ID");"
    e2e_session_end completed
    echo "All failures fixed. Run $RUN_ID re-marked completed."
else
    echo "$REMAINING failure(s) still unresolved in $RUN_ID. Re-run /e2e-test-specialist:fix-failures to continue."
fi
```

## What this command will NOT do

- Will not skip a failure silently. Every iteration MUST land on a
  passed/blocked terminal state with a memory + bug update.
- Will not re-run `passed` or `skipped` steps. Use `/test --resume` for
  full re-execution.
- Will not silently widen scope. If `--test` or `--phase` filters were
  given, only those matching failures are revisited.

## See also

- `/e2e-test-specialist:failures` — list (without re-running) what failed
- `/e2e-test-specialist:autopilot` — full run with in-flight fix loop
- `/e2e-test-specialist:bugs` — open bug-row triage
- `commands/test.md` § "Step 7: Ultrathink Root Cause" — the canonical fix loop
