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

### 6. On failure: consult retry policy

```bash
backoff="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/retry-policy.sh" "$TEST_KIND" "$ERR_KIND" "$ATTEMPT")"
if [[ $? -eq 0 ]]; then
    sleep "$backoff"
    ATTEMPT=$((ATTEMPT + 1))
    # Loop back to step 1 with new attempt number — checkpoint.sh begin
    # produces a new row (because retry_attempt is part of the id).
fi
```

### 7. On unrecoverable failure: open a bug?

If the step is `is_critical=1` and the failure is an assertion (not
transient), ask the user via `AskUserQuestion` whether to:

- **Open a bug** (insert into `bugs`, link to this `step_executions.bug_id`).
  Capture: title, severity, description, error_message; leave `root_cause` /
  `fix_applied` blank for now.
- **Mark blocked** (no bug — known precondition not met).
- **Skip** (note why).

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
