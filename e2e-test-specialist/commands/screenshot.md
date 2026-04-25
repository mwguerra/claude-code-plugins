---
description: Capture a screenshot in the active run and record it in the database
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(mkdir:*), mcp__playwright__*, mcp__plugin_playwright_playwright__*, Read(*)
argument-hint: [--label "page-home-initial"] [--full-page]
---

# /e2e-test-specialist:screenshot

Take a Playwright screenshot of the current browser state and record it in
the `screenshots` table linked to the active run (and the active execution,
if any).

## Process

### 1. Resolve active run and current step

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

ACTIVE_RUN="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
[[ -n "$ACTIVE_RUN" ]] || e2e_die "no active run"

ACTIVE_EXEC="$(e2e_query_value '
    SELECT current_execution_id FROM sessions
     WHERE id=(SELECT active_session_id FROM state WHERE id=1);
')"
```

### 2. Build path

```bash
RUN_DIR="$E2E_ROOT_DIR/runs/$ACTIVE_RUN/screenshots"
mkdir -p "$RUN_DIR"

LABEL="${1:-screenshot}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
PATH_OUT="$RUN_DIR/${TS}_${LABEL//[^a-zA-Z0-9_-]/_}.png"
```

### 3. Pre-flight: check for visible credentials

Take a `mcp__playwright__browser_snapshot` first and feed its text content
through the redaction detector:

```bash
SNAPSHOT_TEXT="$(...captured from browser_snapshot...)"
echo "$SNAPSHOT_TEXT" | python3 "${CLAUDE_PLUGIN_ROOT}/scripts/redact-screenshot.py"
RC=$?
if [[ $RC -ne 0 ]]; then
    # Use AskUserQuestion: "Credentials are visible. Capture anyway?"
    # If user says no, abort the screenshot.
    :
fi
```

### 4. Capture via Playwright

Use `mcp__playwright__browser_take_screenshot` with the `path` argument set
to `$PATH_OUT`. If `--full-page` was passed, include `fullPage: true`.

After the call, tick the heartbeat:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh"
```

### 5. Record in DB

```bash
SHOT_ID="$(e2e_next_id screenshots SHOT)"
e2e_exec "
    INSERT INTO screenshots (id, execution_id, run_id, path, label)
    VALUES (
        '$SHOT_ID',
        NULLIF($(e2e_sql_quote "$ACTIVE_EXEC"), ''),
        '$ACTIVE_RUN',
        $(e2e_sql_quote "$PATH_OUT"),
        $(e2e_sql_quote "$LABEL")
    );
"
```

### 6. Report

```
Screenshot saved.
  path:        $PATH_OUT
  shot_id:     $SHOT_ID
  linked to:   exec=$ACTIVE_EXEC, run=$ACTIVE_RUN
```

## Notes

- Naming convention from the original plugin is preserved: timestamp prefix,
  slug-cased label.
- Screenshots without an active execution still get recorded against the run
  (manual snapshots are valid).
- For full systematic capture during tests, the `/test` command takes
  screenshots automatically at page loads, form submits, errors, and flow
  completions. Use this command for ad-hoc captures.
