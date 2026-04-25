---
description: Manage the test plan over its lifetime — add, update, deprecate, re-discover from app code, or detect drift
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(grep:*), Bash(find:*), Bash(cat:*), Bash(ls:*), Bash(php:*), Bash(python3:*), Glob(*), Grep(*), Read(*), Write(*), AskUserQuestion
argument-hint: <verb> [args...]
  verbs: discover | add-phase | add-test | add-credential | add-app | add-infra
         | update-test <id> | deprecate-test <id> "reason" | reorder-steps <test-id>
         | tags-suggest [<test-id>] | drift | reparse <ledger.md>
         | applies-to <test-id> [APP-001,APP-002,...]
---

# /e2e-test-specialist:plan

The single command for managing the plan after `/init`. Use this instead of
poking the database directly — every verb runs through `AskUserQuestion` so
the change is reviewed, and every write is logged.

## Verb decision tree

```
                       ┌────────────────────────────────────────────┐
                       │ Where does the new/updated info come from? │
                       └────────────────────────────────────────────┘
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                 ▼
   from a markdown                  from app code                   from your head
   ledger file                      (routes, resources)             (one specific change)
        │                                 │                                 │
   /import (first)                  plan discover                  plan add-{phase|test|...}
   plan reparse  (later edits)      plan drift   (changed code)    plan update-test <id>
                                                                   plan deprecate-test <id>
```

## Verbs

### `discover` — bootstrap from app code

For projects without an existing ledger. Scans the codebase and proposes
phases/tests/tags. Read-only commands by stack:

```bash
# Laravel
php artisan route:list --json
find app/Filament -name "*Resource.php"
ls app/Policies app/Models app/Notifications app/Mail 2>/dev/null

# Generic Node/React
grep -r "useRoute\|<Route" src --include="*.tsx" --include="*.jsx"
find src -name "*Page.tsx" -o -name "*Screen.tsx"
```

Synthesize a phase per surface area (auth, CRUD-per-resource, settings,
billing, notifications) and propose tests + tags. Write only after the
user confirms via `AskUserQuestion`.

### `drift` — find gaps between app code and the plan

When the app has changed since the plan was last updated, propose diffs.

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# 1. List current routes/resources (project-specific)
php artisan route:list --json 2>/dev/null > /tmp/routes.json

# 2. List URLs referenced anywhere in the plan
sqlite3 -bail "$E2E_DB" "
  SELECT DISTINCT
    SUBSTR(action, INSTR(action, 'Navigate to')+12) AS url_excerpt
  FROM test_steps
  WHERE action LIKE '%Navigate to%';
"
```

Then propose:

- **New routes with no test coverage** → suggest `add-test` for each
- **Tests referencing removed routes** → suggest `deprecate-test`
- **Tests with stale Filament resources** (model name no longer in
  `app/Models`) → suggest `update-test`

Write results to a temporary report:

```bash
sqlite3 "$E2E_DB" "
  INSERT INTO memories (id, title, kind, body, importance, tags)
  VALUES (
    $(e2e_query_value "SELECT 'M-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id,3) AS INTEGER)),0)+1) FROM memories;"),
    'Drift report ' || datetime('now'),
    'lesson-learned',
    $(e2e_sql_quote "$DRIFT_REPORT"),
    3,
    '[\"drift\",\"audit\"]'
  );
"
```

Then walk the proposals interactively.

### `add-phase`

```bash
# Collect via AskUserQuestion: title, description, phase_order, expected_test_count
PID="P$(printf '%02d' $ORDER)"
e2e_exec "
  INSERT INTO phases (id, title, description, phase_order, expected_test_count, raw_markdown)
  VALUES ($(e2e_sql_quote "$PID"), $(e2e_sql_quote "$TITLE"), $(e2e_sql_quote "$DESC"),
          ${ORDER:-0}, ${EXPECTED:-0}, $(e2e_sql_quote "$RATIONALE"));
"
```

### `add-test`

```bash
# Collect: phase_id, title, actor, preconditions, postconditions, test_kind, is_critical, applies_to (optional)
TID="T-$(echo $PHASE_ID | sed 's/P//').$(printf '%02d' $NEXT_ORDER)"
e2e_exec "
  INSERT INTO tests (id, phase_id, title, actor, preconditions, postconditions,
                     test_kind, test_order, is_critical, raw_markdown, applies_to)
  VALUES ($(e2e_sql_quote "$TID"), $(e2e_sql_quote "$PHASE_ID"), $(e2e_sql_quote "$TITLE"),
          $(e2e_sql_quote "$ACTOR"), $(e2e_sql_quote "$PRE"), $(e2e_sql_quote "$POST"),
          $(e2e_sql_quote "$KIND"), ${NEXT_ORDER:-0}, ${CRITICAL:-0},
          $(e2e_sql_quote "$RATIONALE"), $(e2e_sql_quote "$APPLIES_JSON"));
"

# Loop on steps. SID/TID are internally generated (formatted ids); $i is bash
# integer arithmetic, so it's safe to interpolate as a numeric literal.
for ((i=1; i<=$N_STEPS; i++)); do
  SID="S-${TID#T-}.$(printf '%03d' $i)"
  e2e_exec "
    INSERT INTO test_steps (id, test_id, step_order, action, expected, action_template, expected_template)
    VALUES ($(e2e_sql_quote "$SID"), $(e2e_sql_quote "$TID"), $i,
            $(e2e_sql_quote "${ACTIONS[$i]}"),
            $(e2e_sql_quote "${EXPECTED[$i]}"),
            NULLIF($(e2e_sql_quote "${ACTION_TEMPLATES[$i]}"),''),
            NULLIF($(e2e_sql_quote "${EXPECTED_TEMPLATES[$i]}"),''));
  "
done
```

After insert, suggest auto-tags: `python3 -c "..."` against the taxonomy, then
write to `test_tags`. Ask: "any custom tags?" → write those too.

### `update-test <test-id>`

Show current values, then collect changes. **All fields optional** — only
overwrite what changed.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-update-test >/dev/null
```

```bash
e2e_exec "
  UPDATE tests SET
    title          = COALESCE($(e2e_sql_quote "$NEW_TITLE"), title),
    actor          = COALESCE($(e2e_sql_quote "$NEW_ACTOR"), actor),
    preconditions  = COALESCE($(e2e_sql_quote "$NEW_PRE"), preconditions),
    postconditions = COALESCE($(e2e_sql_quote "$NEW_POST"), postconditions),
    test_kind      = COALESCE($(e2e_sql_quote "$NEW_KIND"), test_kind),
    is_critical    = COALESCE($CRITICAL_OR_NULL, is_critical),
    updated_at     = datetime('now')
  WHERE id = $(e2e_sql_quote "$TID");
"
```

To edit steps, sub-flow:
- Add a step (provide step_order; later steps get bumped)
- Edit a step's action/expected
- Delete a step (HARD delete is OK for steps; tests can't be silently
  deleted, but their internal sequence can change)

### `deprecate-test <test-id> "reason"`

Soft delete — honors the append-only directive. Future runs skip; reports
still show historical executions.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-deprecate >/dev/null
e2e_exec "
  UPDATE tests SET
    deprecated_at = datetime('now'),
    deprecated_reason = $(e2e_sql_quote "$REASON"),
    updated_at = datetime('now')
  WHERE id = $(e2e_sql_quote "$TID");
"
e2e_log INFO plan "deprecated test $TID — $REASON"
```

To **un-deprecate**:

```bash
e2e_exec "UPDATE tests SET deprecated_at=NULL, deprecated_reason=NULL WHERE id=$(e2e_sql_quote "$TID");"
```

### `reorder-steps <test-id>`

Print current order, ask the user for the new order (e.g.,
`3,1,2,4,5`), update `step_order` in one transaction.

### `tags-suggest [<test-id>]`

Re-run the taxonomy against a test's title + raw_markdown and propose
tags. With no test-id, runs across all tests and shows a diff. Apply via
`/e2e-test-specialist:tag bulk-tag` after review.

### `applies-to <test-id> [APP-001,APP-002,...]`

Set or update a test's parametrization. With no second arg, opens an
interactive picker over `apps` + `infrastructure` + synthetic ROLE/VP IDs.
Refuses if the test has step_executions in the active run (would invalidate
in-progress checkpoints).

```bash
e2e_exec "
  UPDATE tests SET applies_to = $(e2e_sql_quote "$APPLIES_JSON"),
                   updated_at = datetime('now')
  WHERE id = $(e2e_sql_quote "$TID");
"
# If the test already has steps, also populate action_template = action where empty
e2e_exec "
  UPDATE test_steps
     SET action_template = COALESCE(action_template, action)
   WHERE test_id = $(e2e_sql_quote "$TID");
"
e2e_log INFO plan "applies_to set on $TID — $APPLIES_JSON"
```

After this, **manually edit** the templates to use `{{subject.field.path}}`
placeholders (the importer's auto-rendering only kicks in when templates
contain placeholders).

### `add-credential`, `add-app`, `add-infra`

Mirror the importer — same column shape, collected via `AskUserQuestion`,
written via INSERT. See `commands/import.md` for the full field semantics.

### `reparse <ledger.md>`

Re-run the markdown importer against an updated source file. Idempotent for
phases/tests/steps (uses INSERT OR REPLACE); additive for credentials and
memories. Hand-edits to test rows in the DB **will be overwritten** — confirm
first:

```bash
# Show what would change
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/import-ledger.py" "$1" --dry-run --json-summary

# Backup before destructive op:
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-reparse

# Confirm via AskUserQuestion, then:
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/import-ledger.py" "$1"
```

## When to use which verb (cheat sheet)

| Situation                                                            | Verb                                       |
|----------------------------------------------------------------------|--------------------------------------------|
| Brand new project, no ledger                                         | `discover`                                 |
| Have a markdown ledger to import                                     | `/e2e-test-specialist:import` (separate)   |
| Markdown ledger was edited; sync DB                                  | `reparse`                                  |
| App code changed; what tests are stale?                              | `drift`                                    |
| Spotted a missing test                                               | `add-test`                                 |
| A test's UI/copy/behavior changed                                    | `update-test`                              |
| A feature was removed                                                | `deprecate-test`                           |
| Steps in a test got rearranged                                       | `reorder-steps`                            |
| Refactor — same procedure now applies to N apps                      | `applies-to <test-id> APP-001,APP-002,…`   |
| Adding new infrastructure (server/droplet)                            | `add-infra`                                |
| Got a new credential (PAT, API token)                                 | `add-credential`                           |
| Auto-tagging missed something                                          | `tags-suggest <test-id>`                   |

## Append-only invariant

The plan grows; tests do not silently disappear. To honor this:
- **Use `deprecate-test`**, never `DELETE FROM tests`.
- Step rearrangement is OK — steps are an internal detail, no one's pinning
  to `S-04.03.005`.
- Phases can be merged, but only by re-pointing `tests.phase_id`; the old
  phase row stays as a record.
