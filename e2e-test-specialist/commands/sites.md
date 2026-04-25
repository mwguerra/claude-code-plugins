---
description: Manage the sites table — deployed instances of apps on infrastructure
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [list | add | update <site-id> | decommission <site-id> | for-app <app-id>]
---

# /e2e-test-specialist:sites

A site is a *deployed instance* of an app on a specific infrastructure row.
Same app can be deployed to multiple infras (e.g., todo on Worker 1 AND
todo on do-sydney) — each is a distinct site with its own domain, service
overrides, and lifecycle status.

Tests parametrize over `SITE-NNN` IDs when they target a specific deployment
(rather than abstract apps).

## Subcommands

### `list` (default)

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT s.id, s.domain, s.status,
         a.name AS app, i.name AS infra, s.deployed_at
    FROM sites s
    JOIN apps a ON a.id = s.app_id
    JOIN infrastructure i ON i.id = s.infra_id
   ORDER BY s.id;
"
```

### `add`

Use `AskUserQuestion` to collect:
- app_id (autocompleted from `apps` table)
- infra_id (autocompleted from `infrastructure` table)
- domain (e.g., `todo.secnote.com.br`)
- status (`planned` default; or `live` if already deployed)
- services_override (JSON; merges over the app's defaults)

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
SID="$(e2e_alloc_and_insert sites SITE \
    "id, app_id, infra_id, domain, status, services_override" \
    "'__NEXT_ID__', $(e2e_sql_quote "$APP"), $(e2e_sql_quote "$INFRA"), $(e2e_sql_quote "$DOMAIN"), $(e2e_sql_quote "$STATUS"), $(e2e_sql_quote "$OVERRIDE_JSON")")"
echo "Created $SID"
```

### `update <site-id>`

Backup first, then update only changed fields:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-sites-update >/dev/null
e2e_exec "
  UPDATE sites SET
    domain            = COALESCE($(e2e_sql_quote "$NEW_DOMAIN"), domain),
    status            = COALESCE($(e2e_sql_quote "$NEW_STATUS"), status),
    services_override = COALESCE($(e2e_sql_quote "$NEW_OVERRIDE"), services_override),
    deployed_at       = COALESCE($(e2e_sql_quote "$NEW_DEPLOYED"), deployed_at),
    updated_at        = datetime('now')
  WHERE id = $(e2e_sql_quote "$SID");
"
```

### `decommission <site-id>`

Soft delete: set status to `decommissioned` (keeps history).

```bash
e2e_exec "
  UPDATE sites SET status='decommissioned', updated_at=datetime('now')
   WHERE id = $(e2e_sql_quote "$1");
"
```

### `for-app <app-id>`

Show all sites for an app:

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id, domain, status, deployed_at
    FROM sites WHERE app_id = $(e2e_sql_quote "$1") ORDER BY id;
"
```

## Using sites in tests

Once sites exist, parametrize a test over them:

```
/e2e-test-specialist:plan applies-to T-05.01 SITE-001,SITE-002,SITE-003
```

The executor will render `{{subject.domain}}`, `{{subject.services_override.redis}}`,
etc. for each site variant, with per-site step_executions.
