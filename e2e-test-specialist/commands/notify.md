---
description: Manage outbound notifications (run-completed, hook-failed, critical-failure, cascade-detected, etc.)
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(cat:*), Read(*)
argument-hint: --list  |  --send  |  --suppress <id>  |  --create <kind> --title "..." [--body "..."] [--severity info|warning|critical] [--target <url>]
---

# /e2e-test-specialist:notify

Manage rows in the `notifications` table (schema v1.4.0). Autopilot writes
to this table at notable events; `--send` drains pending rows by invoking
`scripts/notify.sh` (which fires webhooks / file appends / OS notifications
per `.e2e-testing/config.json`).

## Modes

| Form                                                                                  | Effect                                              |
|---------------------------------------------------------------------------------------|-----------------------------------------------------|
| `--list`                                                                              | List pending + recently-sent notifications          |
| `--send`                                                                              | Dispatch all `pending` notifications                |
| `--suppress <id>`                                                                     | Mark a notification as `suppressed` (won't dispatch) |
| `--create <kind> --title "..." [--body "..."] [--severity ...] [--target ...]`        | Manually queue a notification                       |

`<kind>` is one of: `run-completed`, `run-failed`, `hook-blocking-failed`,
`critical-failure`, `wall-time-hit`, `cascade-detected`,
`kill-switch-triggered`, `manual`.

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# === --list ==============================================================
if [[ -n "${LIST:-}" ]]; then
    e2e_section "Pending notifications"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, kind, severity, title, related_run, created_at
        FROM notifications
       WHERE status='pending'
       ORDER BY created_at DESC
       LIMIT 50;
    "
    e2e_section "Recent (last 20 sent/failed/suppressed)"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, kind, severity, status, sent_at, target
        FROM notifications
       WHERE status IN ('sent','failed','suppressed')
       ORDER BY COALESCE(sent_at, created_at) DESC
       LIMIT 20;
    "
    exit 0
fi

# === --send ==============================================================
if [[ -n "${SEND:-}" ]]; then
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh"
    exit $?
fi

# === --suppress <id> =====================================================
if [[ -n "${SUPPRESS_ID:-}" ]]; then
    e2e_exec "
      UPDATE notifications SET status='suppressed', sent_at=datetime('now')
       WHERE id=$(e2e_sql_quote "$SUPPRESS_ID');
    "
    echo "Suppressed: $SUPPRESS_ID"
    exit 0
fi

# === --create =============================================================
if [[ -n "${CREATE_KIND:-}" ]]; then
    [[ -n "${TITLE:-}" ]] || e2e_die "--create requires --title"
    SEV="${SEVERITY:-info}"
    NOTIF_ID="ntf-$(date -u +%Y%m%dT%H%M%S)-$(printf '%04x' $RANDOM)"
    e2e_exec "
      INSERT INTO notifications (id, kind, severity, title, body, target, status, related_run, created_at)
      VALUES (
          $(e2e_sql_quote "$NOTIF_ID"),
          $(e2e_sql_quote "$CREATE_KIND"),
          $(e2e_sql_quote "$SEV"),
          $(e2e_sql_quote "$TITLE"),
          $(e2e_sql_quote "${BODY:-}"),
          $(e2e_sql_quote "${TARGET:-}"),
          'pending',
          (SELECT active_run_id FROM state WHERE id=1),
          datetime('now')
      );
    "
    echo "Queued notification: $NOTIF_ID  (kind=$CREATE_KIND, severity=$SEV)"
    echo "Dispatch with: /e2e-test-specialist:notify --send"
    exit 0
fi

e2e_die "usage: /e2e-test-specialist:notify --list  |  --send  |  --suppress <id>  |  --create <kind> --title \"...\""
```

## Configuring dispatch targets

`.e2e-testing/config.json` keys consumed by `scripts/notify.sh`:

```json
{
  "notifications": {
    "default_target": "file:.e2e-testing/logs/notifications.log",
    "webhook_url": "https://hooks.slack.com/services/...",
    "min_severity_for_webhook": "warning"
  }
}
```

Targets supported by `notify.sh`:
- `file:<path>` — append a JSON line to the file
- `webhook:<url>` — POST `{title, body, severity, kind, …}` as JSON
- `notify:` — `osascript -e 'display notification …'` on macOS;
  `notify-send` on Linux

If a notification row has its own `target`, it overrides the default.
