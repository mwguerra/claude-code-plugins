---
description: Manage the roles table — first-class user identities for role-based testing
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [list | add | update <role-id> | link-credential <role-id> <cred-id>]
---

# /e2e-test-specialist:roles

A role represents a tested user identity (Super Admin, Tenant Owner, Member,
Guest). Roles can be linked to a credential, so role-parametrized tests can
log in with the right account automatically.

## Subcommands

### `list` (default)

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT r.id, r.name, r.panel,
         json_array_length(r.permissions) AS perm_count,
         c.name AS credential
    FROM roles r
    LEFT JOIN credentials c ON c.id = r.credential_id
   ORDER BY r.id;
"
```

### `add`

Use `AskUserQuestion` to collect:
- name (e.g., 'super-admin', 'tenant-owner', 'member', 'guest')
- panel (admin / tenant / public / api)
- permissions (comma-separated → JSON array)
- credential_id (optional; from `credentials` list — usually a username-password)
- notes

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
RID="ROLE-$(echo "$NAME" | tr 'A-Z ' 'a-z-')"
e2e_exec "
  INSERT INTO roles (id, name, permissions, credential_id, panel, notes)
  VALUES (
    $(e2e_sql_quote "$RID"),
    $(e2e_sql_quote "$NAME"),
    $(e2e_sql_quote "$PERMISSIONS_JSON"),
    NULLIF($(e2e_sql_quote "$CRED_ID"),''),
    $(e2e_sql_quote "$PANEL"),
    $(e2e_sql_quote "$NOTES")
  );
"
```

### `update <role-id>`

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-roles-update >/dev/null
e2e_exec "
  UPDATE roles SET
    permissions   = COALESCE($(e2e_sql_quote "$NEW_PERMS"), permissions),
    panel         = COALESCE($(e2e_sql_quote "$NEW_PANEL"), panel),
    credential_id = COALESCE(NULLIF($(e2e_sql_quote "$NEW_CRED"),''), credential_id),
    notes         = COALESCE($(e2e_sql_quote "$NEW_NOTES"), notes),
    updated_at    = datetime('now')
  WHERE id = $(e2e_sql_quote "$RID");
"
```

### `link-credential <role-id> <cred-id>`

Associate a stored credential with a role so role-based tests can resolve
login info automatically:

```bash
e2e_exec "
  UPDATE roles SET credential_id = $(e2e_sql_quote "$2"), updated_at = datetime('now')
   WHERE id = $(e2e_sql_quote "$1");
"
```

After linking, parametrized tests with `applies_to = ["ROLE-admin","ROLE-user"]`
will resolve subject fields including `{{subject.credential.username}}` and
`{{subject.credential.password}}` — the executor reaches through the
`v_subjects_resolved` view to fetch.

## Using roles in tests

```
/e2e-test-specialist:plan applies-to T-01.04 ROLE-admin,ROLE-user,ROLE-guest
```

The test runs three times, once per role. Steps with templates like:

```
Navigate to /login, fill {{subject.credential.username}} / {{subject.credential.password}}, submit.
Verify {{subject.panel}} dashboard loads.
```

…render correctly per role.
