---
description: Execute pending steps in the active run, with checkpoint persistence and Playwright MCP integration
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(ssh:*), Bash(curl:*), Bash(grep:*), Bash(cat:*), Bash(ls:*), Read(*), Write(*), AskUserQuestion, mcp__playwright__*, mcp__plugin_playwright_playwright__*
argument-hint: [<test-id> | --phase P00,P01 | --tag wireguard,reverb | --resume | --next | --batch N]
---

# /e2e-test-specialist:test

Execute steps from the database against the active run. Every step is
wrapped in a checkpoint that survives session crashes — interrupting and
resuming is always safe.

## When to use which flag

| Flag                   | Behavior                                                                                  |
|------------------------|-------------------------------------------------------------------------------------------|
| (no flag)              | Execute the next pending step (default)                                                   |
| `<test-id>`            | Run the named test (all its steps), e.g. `T-04.03`                                        |
| `--phase P04,P05`      | Run all tests in those phases (intersected with the run's filters)                        |
| `--tag wireguard`      | Run all tests tagged with any of these tags (intersected with the run's filters)          |
| `--resume`             | Continue from the last unfinished step (alias for default)                                |
| `--next`               | Same as default                                                                            |
| `--batch N`            | Run up to N tests, stopping on the first critical failure                                  |

## Pre-flight (every invocation)

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# Reap stale sessions and re-fetch state.
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" > /tmp/e2e-recovery.json

ACTIVE_RUN="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
[[ -n "$ACTIVE_RUN" ]] || e2e_die "no active run — run /e2e-test-specialist:start first"

ACTIVE_SESS="$(e2e_query_value 'SELECT active_session_id FROM state WHERE id=1;')"
if [[ -z "$ACTIVE_SESS" ]]; then
    # Run is alive but has no live session — open one (recovery path).
    ACTIVE_SESS="$(e2e_session_start "$ACTIVE_RUN")"
fi

bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh"
```

## Parametrization (tests with `applies_to`)

Tests can declare they apply to multiple subjects (apps, infrastructure rows,
roles, viewports). When `tests.applies_to` is non-empty, the executor expands
each test into one *execution variant per subject* and renders any
`test_steps.action_template` against the subject's fields.

**Subject resolution.** `applies_to` is a JSON array of subject IDs:

| ID prefix          | Looked up in              | Synthetic? |
|--------------------|---------------------------|------------|
| `APP-NNN`          | `apps`                    | no         |
| `INF-NNN`          | `infrastructure`          | no         |
| `ROLE-{slug}`      | (synthetic — no table)    | yes — user populates `meta.role` later |
| `VP-{slug}`        | (synthetic — `viewport`s) | yes — `desktop`/`tablet`/`mobile` from config |

Resolved fields come from `v_subjects_resolved` (a view defined in `schema.sql`).

**Template rendering.** When a step has `action_template`, render it via:

```bash
SUBJECT_JSON="$(e2e_query "SELECT fields FROM v_subjects_resolved WHERE id=$(e2e_sql_quote "$SUBJECT_ID");" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["fields"])')"
RENDERED_ACTION="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/render-template.py" "$ACTION_TEMPLATE" "$(printf '{"subject":%s}' "$SUBJECT_JSON")")"
```

`{{subject.target_domain}}`, `{{subject.services.redis}}`,
`{{subject.metadata.deploy_dir}}` etc. all resolve as you'd expect. Missing
keys render to empty strings (no errors).

**Step execution id includes the subject** so retries/resume work per-variant:
`EX-{run}-{step}-{subject_id}-{retry}`. The `step_executions.subject_id`
column records which subject was targeted.

## Step selection (build the work queue)

Apply, in order:

1. **Run-level filters** from the `test_runs` row (`target_phases`,
   `target_tags`, `skip_tags`). These were set by `/start`.
2. **Invocation-level filters** from this command's args (`--phase`, `--tag`,
   `<test-id>`).
3. **Already-terminal exclusions**: skip steps whose latest `step_executions`
   row for this run is `passed` or `skipped`.
4. **Dependency check** (schema v1.4.0): for each candidate test, look up
   `test_dependencies(parent_test_id, child_test_id)`. If a parent has
   `test_status='failed'` or `'blocked'` in `v_latest_test_status` for
   this run, the child auto-skips with `skip_reason='dependency-failed'`
   and a note recording the failing parent's test_id. The child's step
   executions are still inserted (so the run report is complete) but with
   `status='skipped'` from the start.
5. **Cross-run-coverage check** (schema v1.4.0): if `test_coverage_links`
   has an active row where `covered_test_id = candidate AND
   covering_test_id` already passed in this run, the candidate auto-skips
   with `skip_reason='cross-run-coverage'` and a note pointing at the
   covering test.

A reference query (substitute placeholders). Note the join with
`v_test_subjects` — that's what materializes per-subject expansions:

```sql
WITH terminal AS (
    SELECT step_id, COALESCE(subject_id,'') AS sid FROM step_executions
     WHERE run_id = :run_id AND status IN ('passed','skipped')
),
filtered_tests AS (
    SELECT t.id
      FROM tests t
     WHERE t.deprecated_at IS NULL
       -- run-level phase filter
       AND ( :run_phases IS NULL OR t.phase_id IN (SELECT value FROM json_each(:run_phases)) )
       -- run-level tag filter (any-match)
       AND ( :run_tags IS NULL
             OR EXISTS (SELECT 1 FROM test_tags tt
                          WHERE tt.test_id = t.id
                            AND tt.tag_name IN (SELECT value FROM json_each(:run_tags))) )
       -- run-level skip-tag filter (none-match)
       AND ( :run_skip_tags IS NULL
             OR NOT EXISTS (SELECT 1 FROM test_tags tt
                              WHERE tt.test_id = t.id
                                AND tt.tag_name IN (SELECT value FROM json_each(:run_skip_tags))) )
       -- invocation-level filters (added at runtime)
       AND ( :invo_phases IS NULL OR t.phase_id IN (SELECT value FROM json_each(:invo_phases)) )
       AND ( :invo_tags   IS NULL OR EXISTS (
              SELECT 1 FROM test_tags tt
               WHERE tt.test_id = t.id
                 AND tt.tag_name IN (SELECT value FROM json_each(:invo_tags))) )
)
SELECT vts.test_id, vts.subject_id,
       s.id AS step_id,
       COALESCE(s.action_template, s.action)     AS action,
       COALESCE(s.expected_template, s.expected) AS expected,
       t.test_kind
  FROM v_test_subjects vts
  JOIN tests       t ON t.id = vts.test_id
  JOIN test_steps  s ON s.test_id = t.id
 WHERE t.id IN (SELECT id FROM filtered_tests)
   AND (s.id, COALESCE(vts.subject_id,'')) NOT IN (SELECT step_id, sid FROM terminal)
 ORDER BY t.test_order, vts.subject_id, s.step_order;
```

## Per-step execution loop

For each step in the queue, **in order**:

### 1. Resolve subject and render action (parametrized tests only)

If `SUBJECT_ID` is non-empty, fetch its fields and render any templates:

```bash
SUBJECT_JSON="$(sqlite3 -bail -json "$E2E_DB" "
    SELECT fields FROM v_subjects_resolved WHERE id=$(e2e_sql_quote "$SUBJECT_ID");
" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["fields"] if d else "{}")')"

if [[ -n "$ACTION_TEMPLATE" ]]; then
    ACTION="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/render-template.py" \
        "$ACTION_TEMPLATE" "$(printf '{"subject":%s}' "$SUBJECT_JSON")")"
fi
```

(For non-parametrized steps, `ACTION` is just the literal `action` column.)

### 2. Checkpoint: begin

```bash
EXEC_ID="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint.sh" begin \
    "$ACTIVE_RUN" "$TEST_ID" "$STEP_ID" "$ATTEMPT" "$SUBJECT_ID")"
```

This creates a `step_executions` row with `status='in-progress'` *before* the
action. If Claude crashes mid-action, the row is still there — that's how
resume knows where you stopped. The `subject_id` column means retries/resume
correctly target the same variant.

### 3. Directive check (only for risky actions)

If the step's action involves SSH writes, `tinker`, or DB writes:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/directive-check.sh" "$ACTION_KIND" "$ACTION_DESCRIPTION"
RC=$?
if [[ $RC -eq 1 ]]; then
    e2e_record_violation blocking  "$ACTION_KIND" "$ACTION_DESCRIPTION" aborted
    STATUS=blocked; ERR="blocked by directive"
    # skip the action entirely
elif [[ $RC -eq 2 ]]; then
    e2e_record_violation warning   "$ACTION_KIND" "$ACTION_DESCRIPTION" continued
fi
```

### 4. Perform the action

For long-blocking actions (apt locks, image transfers, multi-region DO
provisioning, anything you expect could exceed `crash_detection.warn_seconds`),
spawn the background heartbeat watcher BEFORE the action and stop it after:

```bash
WATCHER="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/long-step-heartbeat.sh" start)"
# ... long action runs here ...
bash "${CLAUDE_PLUGIN_ROOT}/scripts/long-step-heartbeat.sh" stop "$WATCHER"
```

This keeps the heartbeat ticking every ~half of `warn_seconds` so a
crashed-session reaper doesn't false-positive on legitimate long waits.

Dispatch by the test's `test_kind`:

#### `browser`
Use Playwright MCP tools. Heartbeat after **each** tool call:

```
mcp__playwright__browser_navigate   → bash heartbeat.sh
mcp__playwright__browser_snapshot   → bash heartbeat.sh
mcp__playwright__browser_click      → bash heartbeat.sh
mcp__playwright__browser_fill_form  → bash heartbeat.sh
mcp__playwright__browser_take_screenshot → bash heartbeat.sh + record path in screenshots
```

Critical rules preserved from the previous plugin:
- **Sequential only**. Never run E2E in parallel.
- Visible browser by default; open new tabs (with 1s wait between) if other
  tests are running.
- Always take a screenshot at significant transitions; insert a row into the
  `screenshots` table linked to this `EXEC_ID`.
- Check `mcp__playwright__browser_console_messages` and
  `mcp__playwright__browser_network_requests` after navigations; capture
  failures as part of `evidence_snapshot`.

#### `ssh`
Use Bash(`ssh:*`) with read-only intent. Verify with `grep`/`cat` only — never
write to remote files mid-run (the directive-check guard will stop you anyway).
Capture stdout into `evidence_snapshot`.

#### `api`
Use `curl -sS` (or your project's API client). Capture status code and
body excerpt into `evidence_snapshot`.

#### `cli` / `mixed`
Run the command. Capture exit code + truncated stdout/stderr.

#### `manual` / `observation`
Use `AskUserQuestion` to record the result; the user types the observed
outcome. Status is whatever they say.

### 5. Evaluate result

- **Match against `expected`** if provided. Otherwise, classify by exit code /
  HTTP status / presence of "error"/"500"/"undefined" in evidence.
- Set `STATUS` to `passed`, `failed`, `skipped`, or `blocked`.

### 6. On failure: classify, then either retry (transient) OR root-cause (everything else)

```bash
backoff="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/retry-policy.sh" "$TEST_KIND" "$ERR_KIND" "$ATTEMPT")"
RETRY_RC=$?
if [[ $RETRY_RC -eq 0 ]]; then
    # Transient infrastructure flake — wait + retry.
    sleep "$backoff"
    ATTEMPT=$((ATTEMPT + 1))
    # Loop back to step 1 with new attempt number — checkpoint.sh begin
    # produces a new row (because retry_attempt is part of the id).
    continue
fi
# RETRY_RC != 0 → this is a real failure. Do NOT skip. Do NOT loop. Drop
# into the root-cause loop in step 7.
```

### 7. On real failure: ULTRATHINK ROOT CAUSE → FIX → RETEST

This step is non-negotiable. The fix loop is part of the test loop. A bug
that's only reported is half a bug; a bug that's root-caused, fixed,
regression-tested, redeployed, and re-verified is a closed bug.

**7.1 Capture full evidence into `step_executions.evidence_snapshot`**

For browser failures:
```bash
mcp__playwright__browser_console_messages    # JS errors / warnings
mcp__playwright__browser_network_requests    # 4xx/5xx responses
mcp__playwright__browser_take_screenshot     # visual evidence
mcp__playwright__browser_snapshot            # accessibility tree
```

For server-side failures:
```bash
ssh "$SERVER" "tail -200 /var/www/html/storage/logs/laravel.log"
ssh "$SERVER" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
ssh "$SERVER" "docker logs $CONTAINER --tail 200 --timestamps"
ssh "$SERVER" "tail -200 /var/log/primeforge-agent/agent.log"
```

For panel/DB-side failures:
```bash
sqlite3 -bail -json "$E2E_DB" "SELECT … FROM bugs ORDER BY created_at DESC LIMIT 5;"
# Plus targeted queries against the actual app DB to confirm panel state
# matches reality on the server.
```

Persist all of the above to `evidence_snapshot` so a future session can
re-investigate without rerunning the failure.

**7.2 Form a specific hypothesis (one sentence, names the code path)**

Bad: "intermittent network issue", "probably a race", "needs investigation".
Good: "ImageDistributionService::transfer() exits 0 on partial transfer
because rsync exit-code 23 is treated as success" / "Reverb apps.json uses
underscore-joined slug while site env emits hyphen-joined".

**7.3 Verify the hypothesis by reading source / running a targeted query**

Open the suspected file at the suspected line. Confirm the code matches the
hypothesis. If it doesn't, form a new hypothesis. Never skip this step.

**7.4 Propose the smallest fix that addresses the root cause**

NOT "catch and ignore". NOT "add a retry". NOT "add a sleep". Look for the
underlying invariant that's being violated. If the fix would touch a wider
area than the user authorized, use `AskUserQuestion` to confirm before
proceeding.

**7.5 Open a bug row, then apply the fix in the source repo**

Maintain `bugs.affected_tests` (schema v1.4.0 column, JSON array) so triage
can answer "which tests does fixing this bug unblock?" in one query. Use
`json_array(<test_id>)` on insert and `json_insert` if a later failure
attaches the same root cause to a different test.

```bash
BUG_ID="$(e2e_query_value "
    INSERT INTO bugs (id, discovered_in_run, severity, title, description,
                      error_message, evidence_snapshot, root_cause,
                      fix_applied, affected_tests, status)
    VALUES ('$NEW_BUG_ID', '$ACTIVE_RUN', '$SEVERITY',
            $(e2e_sql_quote \"$TITLE\"),
            $(e2e_sql_quote \"$DESCRIPTION\"),
            $(e2e_sql_quote \"$ERR\"),
            $(e2e_sql_quote \"$EVIDENCE\"),
            $(e2e_sql_quote \"$ROOT_CAUSE\"),
            $(e2e_sql_quote \"$PROPOSED_FIX\"),
            json_array($(e2e_sql_quote \"$TEST_ID\")),
            'in-progress')
    RETURNING id;
")"
```

Then: edit the source file(s), add/update a regression test that reproduces
the bug, run the test suite locally (`php artisan test --filter=…`),
commit with a conventional message naming the root cause + fix, redeploy
the affected component if needed.

**7.6 Re-run the failing step end-to-end against the fixed code**

The new `step_executions.fix_attempt_index` column (schema v1.4.0) is the
authoritative counter for fix attempts. Increment on each retry; the
autopilot's MAX_FIX_ATTEMPTS check uses this column directly instead of
counting `status='failed'` rows.

```bash
ATTEMPT="$(e2e_query_value "
    SELECT COALESCE(MAX(fix_attempt_index),0)+1
      FROM step_executions
     WHERE run_id=$(e2e_sql_quote \"$ACTIVE_RUN\") AND step_id=$(e2e_sql_quote \"$STEP_ID\");
")"
# Loop back to step 2 (Checkpoint: begin) for a fresh execution row,
# inserting fix_attempt_index = $ATTEMPT.
# When this re-execution returns STATUS=passed:
e2e_exec "
    UPDATE bugs
       SET status = 'fixed',
           fix_commit_sha = $(e2e_sql_quote \"$COMMIT_SHA\"),
           retested_at = datetime('now'),
           retest_result = 'fixed',
           updated_at = datetime('now')
     WHERE id = $(e2e_sql_quote \"$BUG_ID\");
"
```

Only after the failing step passes against the fixed code is the bug
considered resolved.

**7.7 If you genuinely cannot determine the root cause OR the fix exceeds
the user's authorized scope**

Use `AskUserQuestion` to surface the partial hypothesis tree + collected
evidence + your best-guess fix proposal, and ask the user how to proceed
(authorize a wider fix; defer with bug recorded; mark blocked; skip with
explicit acknowledgement). NEVER silently skip.

**Special case: `is_critical=0` non-blocking checks**

For non-critical steps (e.g., observation-only screenshots, optional
warnings), step 7's full root-cause loop is best-effort — log the bug,
attempt a quick hypothesis, but the run can proceed. For critical steps
(default), the loop above is mandatory.

### 8. Checkpoint: end

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint.sh" end \
    "$EXEC_ID" "$STATUS" "$ACTUAL" "$ERR" "$EVIDENCE" "$BUG_ID"
```

This writes the terminal status, duration, and evidence atomically. After
this returns, the next session would resume from the *next* step.

### 9. Continue or stop

- If `STATUS == passed | skipped`: continue to next step.
- If `STATUS == failed | blocked` AND step is critical: ask whether to
  continue, abort run, or pause for investigation. Default is **pause**
  (mark session `paused`, leave run `in-progress`).
- If `--batch N` was set, decrement N; stop when 0.

## Run completion

When the queue is empty:

```bash
e2e_exec "
    UPDATE test_runs
       SET status='completed', ended_at=datetime('now')
     WHERE id = $(e2e_sql_quote "$ACTIVE_RUN");
"
e2e_session_end completed
```

Print a summary using `v_run_progress`. Suggest next steps:

```
Run R-NNN complete.
  passed:        ###
  failed:        ##   (with bug ids)
  skipped:       #
  blocked:       #

Generate report:    /e2e-test-specialist:report
Triage bugs:        /e2e-test-specialist:bugs
Capture lessons:    /e2e-test-specialist:memory
```

## Important guarantees

- **Every step row exists before the action runs.** A crash mid-action leaves
  the row in `in-progress` status. The next session detects it via
  `crash-recovery.sh` and resumes (or skips, on user choice).
- **Heartbeat is updated after every tool call.** Long-running but live
  operations don't get falsely flagged as crashed.
- **Tags drive selection, not test order.** Re-running just the
  `--tag wireguard` subset across many phases is one command.
- **Sequential execution is enforced.** This loop processes one step at a
  time per session — Playwright state, auth state, and DB state stay
  consistent.
