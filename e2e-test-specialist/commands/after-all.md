---
description: Manage post-run lifecycle hooks (the "afterAll" autopilot reads after the run completes)
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(cat:*), Read(*)
argument-hint: <title> [--body "..." | --from <file>] [--id <hook-id>] [--enforcement blocking|advisory] [--order N]  |  --list  |  --show <hook-id>  |  --remove <hook-id>
---

# /e2e-test-specialist:after-all

Manage entries in `lifecycle_hooks WHERE phase='post-run'`. These are
project-specific instructions the autopilot reads and follows **after the
run reaches a terminal status** (snapshot DB, push report, notify Slack,
archive screenshots, restore baseline state, etc.).

This command is the friendly wrapper around the SQL described in
`commands/autopilot.md` § "Managing lifecycle hooks". Use it instead of
hand-writing INSERT/UPDATE/DELETE.

## Modes

| Form                                                        | Effect                                                      |
|-------------------------------------------------------------|-------------------------------------------------------------|
| `<title> --body "instructions…"`                            | Upsert a hook with an inline body                           |
| `<title> --from <path>`                                     | Upsert a hook with body read from a markdown file           |
| `--list`                                                    | List active post-run hooks (ordered by `order_idx`)         |
| `--show <hook-id>`                                          | Print one hook's full body                                  |
| `--remove <hook-id>`                                        | Soft-disable a hook (sets `active=0`)                       |

Optional flags on upsert:

| Flag                              | Default       | Effect                                                   |
|-----------------------------------|---------------|----------------------------------------------------------|
| `--id <hook-id>`                  | auto-slug     | Stable id; reuse to update an existing hook in place     |
| `--enforcement blocking|advisory` | `advisory`    | `blocking` aborts the autopilot if the hook fails        |
| `--order N`                       | `100`         | Lower = earlier; ties broken by id                       |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# Confirm the lifecycle_hooks table exists (schema v1.3.0+).
HAS_TABLE="$(e2e_query_value "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='lifecycle_hooks';")"
[[ "$HAS_TABLE" -eq 1 ]] || e2e_die "lifecycle_hooks table missing — run /e2e-test-specialist:init to migrate (requires schema v1.3.0+)"

# === MODE: --list =========================================================
if [[ -n "${LIST:-}" ]]; then
    e2e_section "Post-run hooks (active=1, ordered by order_idx)"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, title, enforcement, order_idx, active,
             substr(body,1,60) AS body_excerpt,
             updated_at
        FROM lifecycle_hooks
       WHERE phase='post-run'
       ORDER BY active DESC, order_idx ASC, id ASC;
    "
    exit 0
fi

# === MODE: --show <id> ====================================================
if [[ -n "${SHOW_ID:-}" ]]; then
    e2e_section "Hook $SHOW_ID"
    sqlite3 -bail -line "$E2E_DB" "
      SELECT id, phase, title, enforcement, order_idx, active,
             body, source, created_at, updated_at
        FROM lifecycle_hooks
       WHERE id = $(e2e_sql_quote "$SHOW_ID") AND phase='post-run';
    "
    exit 0
fi

# === MODE: --remove <id> ==================================================
if [[ -n "${REMOVE_ID:-}" ]]; then
    EXISTS="$(e2e_query_value "SELECT COUNT(*) FROM lifecycle_hooks WHERE id=$(e2e_sql_quote "$REMOVE_ID") AND phase='post-run';")"
    [[ "$EXISTS" -eq 1 ]] || e2e_die "no post-run hook with id '$REMOVE_ID'"
    e2e_exec "
      UPDATE lifecycle_hooks
         SET active=0, updated_at=datetime('now')
       WHERE id=$(e2e_sql_quote "$REMOVE_ID") AND phase='post-run';
    "
    echo "Disabled post-run hook: $REMOVE_ID"
    exit 0
fi

# === MODE: upsert =========================================================
[[ -n "${TITLE:-}" ]] || e2e_die "usage: /e2e-test-specialist:after-all <title> --body \"…\"  (or --from <file>)  |  --list  |  --show <id>  |  --remove <id>"

# Resolve body: --from wins, then --body
if [[ -n "${BODY_FILE:-}" ]]; then
    [[ -f "$BODY_FILE" ]] || e2e_die "--from: file not found: $BODY_FILE"
    BODY="$(cat "$BODY_FILE")"
elif [[ -n "${BODY:-}" ]]; then
    : # use BODY as-is
else
    e2e_die "must provide either --body \"…\" or --from <path>"
fi
[[ -n "$BODY" ]] || e2e_die "hook body is empty"

ENFORCEMENT="${ENFORCEMENT:-advisory}"
case "$ENFORCEMENT" in
    blocking|advisory) ;;
    *) e2e_die "--enforcement must be 'blocking' or 'advisory' (got: $ENFORCEMENT)" ;;
esac

ORDER_IDX="${ORDER_IDX:-100}"
[[ "$ORDER_IDX" =~ ^[0-9]+$ ]] || e2e_die "--order must be a non-negative integer"

# Auto-slug the id if --id not provided
if [[ -z "${HOOK_ID:-}" ]]; then
    SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40)"
    [[ -n "$SLUG" ]] || SLUG="hook-$(date -u +%Y%m%dT%H%M%S)"
    HOOK_ID="lh-post-${SLUG}"
fi

# UPSERT: insert if new, update if id exists. Reactivates if previously disabled.
e2e_exec "
  INSERT INTO lifecycle_hooks (id, phase, title, body, enforcement, order_idx, active, source, created_at, updated_at)
  VALUES (
      $(e2e_sql_quote "$HOOK_ID"),
      'post-run',
      $(e2e_sql_quote "$TITLE"),
      $(e2e_sql_quote "$BODY"),
      $(e2e_sql_quote "$ENFORCEMENT"),
      $ORDER_IDX,
      1,
      'after-all-cmd',
      datetime('now'),
      datetime('now')
  )
  ON CONFLICT(id) DO UPDATE SET
      title       = excluded.title,
      body        = excluded.body,
      enforcement = excluded.enforcement,
      order_idx   = excluded.order_idx,
      active      = 1,
      updated_at  = datetime('now');
"

echo "Saved post-run hook: $HOOK_ID"
echo "  title       : $TITLE"
echo "  enforcement : $ENFORCEMENT"
echo "  order_idx   : $ORDER_IDX"
echo "  body bytes  : ${#BODY}"
echo
echo "View with:    /e2e-test-specialist:after-all --show $HOOK_ID"
echo "Disable with: /e2e-test-specialist:after-all --remove $HOOK_ID"
echo "List all:     /e2e-test-specialist:after-all --list"
```

## Examples

```bash
# Snapshot the DB after every run (advisory — autopilot should not abort if backup fails).
/e2e-test-specialist:after-all "Snapshot DB to _backups/post-run-<ts>.sqlite" \
  --body "Run \`bash \${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh post-run\`. The backup feeds the nightly diff report." \
  --enforcement advisory --order 10

# Generate the report and tail it to the operator log.
/e2e-test-specialist:after-all "Generate run report" \
  --body "Invoke \`/e2e-test-specialist:report\` and append the summary to .e2e-testing/logs/reports.log." \
  --order 20

# Restore baseline state on a shared environment.
/e2e-test-specialist:after-all "Restore baseline" --from .e2e-testing/hooks/post-restore.md \
  --enforcement blocking --order 90

# List, inspect, disable.
/e2e-test-specialist:after-all --list
/e2e-test-specialist:after-all --show lh-post-snapshot-db-to-backups-post-run-ts-sql
/e2e-test-specialist:after-all --remove lh-post-snapshot-db-to-backups-post-run-ts-sql
```

## When the autopilot reads these

`/e2e-test-specialist:autopilot` step 5.5 — after the run is marked
`completed` and the run-summary memory is written, before the command
exits. Hooks run in `order_idx` ASC, then `id` ASC.

Post-run hooks run AFTER the run is `completed`, so they cannot affect
the run's final status — they're purely for side effects on external
systems. A `blocking` hook that fails will still be logged and surface a
non-zero exit, but the run row stays `completed`.

## See also

- `/e2e-test-specialist:before-all` — the pre-run counterpart
- `commands/autopilot.md` § "Managing lifecycle hooks" — raw SQL form
