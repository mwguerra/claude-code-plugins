---
description: List, add, and triage bugs discovered during E2E runs
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*), Edit(*)
argument-hint: [list | open | fix <id> | retest <id>] [--severity ...] [--run R-NNN]
---

# /e2e-test-specialist:bugs

Manage the `bugs` table — errors found during runs with their root cause, fix
applied, and retest result.

## Subcommands

### `list` (default)

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id, severity, status, retest_result,
         substr(title,1,60) AS title,
         discovered_in_run AS run,
         created_at
    FROM bugs
   WHERE (:status IS NULL OR status = :status)
   ORDER BY
     CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
     created_at DESC;
"
```

### `open`

Interactively add a new bug. Use `AskUserQuestion` to collect:

- title (one-line)
- severity (critical / high / medium / low)
- description (multiline)
- error_message (paste)
- related_step_id (optional — autocomplete from active session if any)

Insert:

```bash
BUG_ID="$(e2e_next_id bugs BUG)"
e2e_exec "
  INSERT INTO bugs
    (id, discovered_in_run, severity, title, description, error_message,
     status, related_step_id)
  VALUES
    ($(e2e_sql_quote "$BUG_ID"),
     $(e2e_sql_quote "$ACTIVE_RUN"),
     $(e2e_sql_quote "$SEVERITY"),
     $(e2e_sql_quote "$TITLE"),
     $(e2e_sql_quote "$DESCRIPTION"),
     $(e2e_sql_quote "$ERROR_MESSAGE"),
     'open',
     NULLIF($(e2e_sql_quote "$STEP_ID"), ''));
"
```

If a `current_execution_id` exists, also link the bug to that execution:

```bash
e2e_exec "UPDATE step_executions
             SET bug_id = $(e2e_sql_quote "$BUG_ID")
           WHERE id     = $(e2e_sql_quote "$ACTIVE_EXEC");"
```

### `fix <bug-id>`

Mark a bug as fixed. Collect:

- root_cause (multiline)
- fix_applied (description of the change)
- fix_commit_sha (optional)

```bash
e2e_exec "
  UPDATE bugs
     SET status='fixed',
         root_cause=$(e2e_sql_quote "$ROOT_CAUSE"),
         fix_applied=$(e2e_sql_quote "$FIX_APPLIED"),
         fix_commit_sha=$(e2e_sql_quote "$FIX_COMMIT"),
         updated_at=datetime('now')
   WHERE id = $(e2e_sql_quote "$BUG_ID");
"
```

Suggest creating a memory:

> "Capture this fix as a memory? Future runs will see it when similar
>  symptoms appear."

If yes, delegate to `/e2e-test-specialist:memory` with `kind=bug-pattern`,
`importance=4`, related_bug_id pre-filled.

### `retest <bug-id>`

Mark the retest result. Used after the user re-ran the affected step:

- retest_result: `fixed` | `persists` | `not-retested`

```bash
e2e_exec "
  UPDATE bugs
     SET retested_at=datetime('now'),
         retest_result=$(e2e_sql_quote "$RETEST"),
         status=CASE WHEN $(e2e_sql_quote "$RETEST")='fixed' THEN 'fixed' ELSE status END,
         updated_at=datetime('now')
   WHERE id = $(e2e_sql_quote "$BUG_ID");
"
```

## Notes

- Bugs are scoped to a run (`discovered_in_run`). Cross-run patterns are
  better expressed as memories with `kind=bug-pattern`.
- The `tags` JSON column on bugs is free-form — use it to group ("LB",
  "WireGuard", "credential-expiry") and query with `json_each`.
