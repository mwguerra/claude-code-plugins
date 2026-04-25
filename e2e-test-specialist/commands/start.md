---
description: Start a new test run (R-NNN) with optional phase or tag filters
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [<base-url>] [--label "..."] [--phase P00,P01,...] [--tag wireguard,reverb,...] [--skip-tag mobile,...]
---

# /e2e-test-specialist:start

Start a new test run. Allocates the next R-NNN id, opens a session with
heartbeat tracking, and points the run at a subset of tests by phase and/or
tag.

## Process

### 1. Pre-flight

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db
```

Reap any crashed sessions:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" > /tmp/e2e-recovery.json
```

Read `/tmp/e2e-recovery.json`. **If `crashed_session` is non-null and
`active_run_id` is non-null**, ask the user via `AskUserQuestion`:

- "A previous run **{active_run_id}** crashed at step
  **{crashed_session.current_step_id}**. Resume it, or abort and start a new
  run?"
  - **Resume** → invoke `/e2e-test-specialist:resume` instead and stop here.
  - **New run (abort old)** → continue (this command will mark the old run
    `aborted`).

### 2. Parse arguments

| Flag             | Effect                                                       |
|------------------|--------------------------------------------------------------|
| `<base-url>`     | URL the run targets; stored on the run row and `state`       |
| `--label "..."`  | Free-form label for the run (used in reports)                |
| `--phase X,Y`    | Limit to listed phase IDs (e.g., `P00,P01,P04`)              |
| `--tag a,b`      | Limit to tests with **any** of the listed tags                |
| `--skip-tag x,y` | Exclude tests tagged with any of these                        |

If `--tag` was provided, **verify the tags exist** before creating the run:

```bash
for tag in $(echo "$tags" | tr , ' '); do
    n="$(e2e_query_value "SELECT COUNT(*) FROM tags WHERE name = $(e2e_sql_quote "$tag");")"
    [[ "$n" -eq 0 ]] && e2e_die "tag '$tag' is unknown — run /e2e-test-specialist:tag --list"
done
```

### 3. Allocate run id and abort any in-progress run

```bash
RUN_ID="$(e2e_next_run_id)"
e2e_exec "
    UPDATE test_runs SET status='aborted', ended_at=datetime('now')
     WHERE status='in-progress';
"
```

### 4. Create the run row

```bash
e2e_exec "
    INSERT INTO test_runs (id, label, base_url, status, target_phases, target_tags, skip_tags)
    VALUES (
        $(e2e_sql_quote "$RUN_ID"),
        $(e2e_sql_quote "${LABEL:-untitled}"),
        $(e2e_sql_quote "${BASE_URL:-}"),
        'in-progress',
        $(e2e_sql_quote "$(printf '%s' "$PHASES_JSON")"),
        $(e2e_sql_quote "$(printf '%s' "$TAGS_JSON")"),
        $(e2e_sql_quote "$(printf '%s' "$SKIP_TAGS_JSON")")
    );
    UPDATE state SET active_run_id  = $(e2e_sql_quote "$RUN_ID"),
                     base_url       = $(e2e_sql_quote "${BASE_URL:-}"),
                     last_update    = datetime('now')
     WHERE id=1;
"
```

### 5. Open a session with heartbeat

```bash
SESSION_ID="$(e2e_session_start "$RUN_ID")"
```

### 6. Pre-test checks (preserved from the original plugin)

These are crucial Playwright-specific checks. Honor them in this order:

1. **Browser install**: `mcp__playwright__browser_install` if not already.
2. **URL/port verification** (CRITICAL): `mcp__playwright__browser_navigate`
   to the base URL → `mcp__playwright__browser_snapshot`. Confirm you're on
   the expected app (not nginx default, not an error page). If verification
   fails, try the common fallback ports (8000, 8080, 3000, 5173, 5174, 5000,
   4200) before giving up. Update `state.base_url` if a different port works.
3. **Docker-local detection**: for Laravel projects, check for `.env` with a
   `.test` APP_URL and use that domain instead of localhost. Never spin up
   `php artisan serve` if docker-local is up.
4. **CSS/Tailwind rendering**: take a screenshot of the first page; verify
   icons + Tailwind look correct. Fix `vite.config.js`/`tailwind.config.js`
   /Filament theme registration if not — see the agent doc for full diagnostic
   steps.
5. **Viewport**: `mcp__playwright__browser_resize` per
   `playwright.default_viewport` from config.

After EACH of the above tool calls, tick the heartbeat:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/heartbeat.sh"
```

### 7. Hand off to /test

Print to the user:

```
Run $RUN_ID started.
  base_url:  $BASE_URL
  phases:    $PHASES_DISPLAY
  tags:      $TAGS_DISPLAY
  skip-tags: $SKIP_TAGS_DISPLAY

Begin execution with: /e2e-test-specialist:test
```

The actual test execution loop lives in `/e2e-test-specialist:test`. This
command only sets up the run and validates the environment.
