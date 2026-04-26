---
description: Record a standing-grant authorization the autopilot reads at every run (memory + optional pre-run hook)
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(cat:*), Read(*)
argument-hint: <title> [--body "..." | --from <file>] [--id <auth-id>] [--scope tag1,tag2,...] [--also-hook] [--enforcement blocking|advisory]  |  --list  |  --show <auth-id>  |  --revoke <auth-id>
---

# /e2e-test-specialist:authorize

Record a **standing authorization** the autopilot reads at every run start
(via the pre-run briefing in `commands/autopilot.md` step 3.5). Use this
instead of giving manual approval mid-run; the autopilot must never need to
ask the user for permission once authorization is on file.

What it writes:
- A row in `memories` (importance=5, tags include `authorization` +
  `standing-grant` + any `--scope` tags), so the autopilot's pre-run
  briefing surfaces it automatically.
- Optionally (`--also-hook`) a row in `lifecycle_hooks(phase='pre-run')`
  so the autopilot also executes any verification steps in the body.

## Modes

| Form                                                                           | Effect                                                  |
|--------------------------------------------------------------------------------|---------------------------------------------------------|
| `<title> --body "grant…"`                                                      | Record an authorization with an inline body            |
| `<title> --from <path>`                                                        | Record an authorization with body from a markdown file |
| `--list`                                                                       | List active authorizations                              |
| `--show <auth-id>`                                                             | Print one authorization's full body                    |
| `--revoke <auth-id>`                                                           | Soft-revoke (`status='deprecated'`)                    |

Optional flags on record:

| Flag                              | Default                          | Effect                                                                                          |
|-----------------------------------|----------------------------------|-------------------------------------------------------------------------------------------------|
| `--id <auth-id>`                  | auto-slug                        | Stable id; reuse to update in place                                                             |
| `--scope a,b`                     | (empty)                          | Extra tags appended to `authorization`/`standing-grant` (e.g. `forge,do-droplets,lb-topology`)  |
| `--also-hook`                     | off                              | Also create a corresponding `pre-run` lifecycle hook with the same body                          |
| `--enforcement blocking|advisory` | `advisory` (only with `--also-hook`) | Hook enforcement (the memory side has no enforcement)                                       |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

HAS_LH="$(e2e_query_value "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='lifecycle_hooks';")"

# === MODE: --list =========================================================
if [[ -n "${LIST:-}" ]]; then
    e2e_section "Active authorizations (memories tagged 'authorization' or 'standing-grant')"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, title, importance,
             substr(body,1,60) AS body_excerpt,
             tags, updated_at
        FROM memories
       WHERE status='active'
         AND (tags LIKE '%\"authorization\"%' OR tags LIKE '%\"standing-grant\"%')
       ORDER BY importance DESC, updated_at DESC;
    "
    if [[ "$HAS_LH" -eq 1 ]]; then
        e2e_section "Pre-run hooks linked to authorizations"
        sqlite3 -bail -column -header "$E2E_DB" "
          SELECT id, title, enforcement, order_idx
            FROM lifecycle_hooks
           WHERE phase='pre-run' AND active=1
             AND (id LIKE 'lh-pre-auth-%' OR source='authorize-cmd')
           ORDER BY order_idx ASC;
        "
    fi
    exit 0
fi

# === MODE: --show <id> ====================================================
if [[ -n "${SHOW_ID:-}" ]]; then
    e2e_section "Authorization $SHOW_ID"
    sqlite3 -bail -line "$E2E_DB" "
      SELECT id, title, kind, importance, status, tags, body, updated_at
        FROM memories
       WHERE id = $(e2e_sql_quote "$SHOW_ID");
    "
    if [[ "$HAS_LH" -eq 1 ]]; then
        sqlite3 -bail -line "$E2E_DB" "
          SELECT id, phase, title, enforcement, order_idx, active, body
            FROM lifecycle_hooks
           WHERE id = 'lh-pre-' || substr($(e2e_sql_quote "$SHOW_ID"), 5);
        " 2>/dev/null || true
    fi
    exit 0
fi

# === MODE: --revoke <id> ==================================================
if [[ -n "${REVOKE_ID:-}" ]]; then
    EXISTS="$(e2e_query_value "SELECT COUNT(*) FROM memories WHERE id=$(e2e_sql_quote "$REVOKE_ID");")"
    [[ "$EXISTS" -eq 1 ]] || e2e_die "no authorization with id '$REVOKE_ID'"
    e2e_exec "
      UPDATE memories
         SET status='deprecated', updated_at=datetime('now')
       WHERE id=$(e2e_sql_quote "$REVOKE_ID");
    "
    if [[ "$HAS_LH" -eq 1 ]]; then
        e2e_exec "
          UPDATE lifecycle_hooks
             SET active=0, updated_at=datetime('now')
           WHERE id = 'lh-pre-' || substr($(e2e_sql_quote "$REVOKE_ID"), 5);
        "
    fi
    echo "Revoked authorization: $REVOKE_ID"
    exit 0
fi

# === MODE: record =========================================================
[[ -n "${TITLE:-}" ]] || e2e_die "usage: /e2e-test-specialist:authorize <title> --body \"…\"  (or --from <file>)  |  --list  |  --show <id>  |  --revoke <id>"

# Resolve body
if [[ -n "${BODY_FILE:-}" ]]; then
    [[ -f "$BODY_FILE" ]] || e2e_die "--from: file not found: $BODY_FILE"
    BODY="$(cat "$BODY_FILE")"
elif [[ -n "${BODY:-}" ]]; then
    : # use BODY as-is
else
    e2e_die "must provide either --body \"…\" or --from <path>"
fi
[[ -n "$BODY" ]] || e2e_die "authorization body is empty"

# Auto-slug the id if --id not provided
if [[ -z "${AUTH_ID:-}" ]]; then
    SLUG="$(printf '%s' "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40)"
    [[ -n "$SLUG" ]] || SLUG="auth-$(date -u +%Y%m%dT%H%M%S)"
    AUTH_ID="auth-${SLUG}"
fi

# Build tags JSON. Default: authorization + standing-grant. Append --scope.
SCOPE_TAGS_JSON='"authorization","standing-grant"'
if [[ -n "${SCOPE:-}" ]]; then
    EXTRA="$(printf '%s' "$SCOPE" | awk -v RS=, '{printf "%s\"%s\"", (NR>1?",":""), $1}')"
    SCOPE_TAGS_JSON="${SCOPE_TAGS_JSON},${EXTRA}"
fi
TAGS_JSON="[${SCOPE_TAGS_JSON}]"

# UPSERT memory row (kind='other' is the only catch-all in the v1.2.0 CHECK).
e2e_exec "
  INSERT INTO memories (id, title, kind, body, importance, tags, status, created_at, updated_at)
  VALUES (
      $(e2e_sql_quote "$AUTH_ID"),
      $(e2e_sql_quote "$TITLE"),
      'other',
      $(e2e_sql_quote "$BODY"),
      5,
      $(e2e_sql_quote "$TAGS_JSON"),
      'active',
      datetime('now'),
      datetime('now')
  )
  ON CONFLICT(id) DO UPDATE SET
      title       = excluded.title,
      body        = excluded.body,
      tags        = excluded.tags,
      importance  = excluded.importance,
      status      = 'active',
      updated_at  = datetime('now');
"

echo "Recorded authorization memory: $AUTH_ID"
echo "  title       : $TITLE"
echo "  importance  : 5"
echo "  tags        : $TAGS_JSON"
echo "  body bytes  : ${#BODY}"

# Optionally also write the pre-run hook
if [[ -n "${ALSO_HOOK:-}" && "$HAS_LH" -eq 1 ]]; then
    HOOK_ID="lh-pre-${AUTH_ID#auth-}"
    HOOK_ENFORCEMENT="${ENFORCEMENT:-advisory}"
    case "$HOOK_ENFORCEMENT" in
        blocking|advisory) ;;
        *) e2e_die "--enforcement must be 'blocking' or 'advisory' (got: $HOOK_ENFORCEMENT)" ;;
    esac
    e2e_exec "
      INSERT INTO lifecycle_hooks (id, phase, title, body, enforcement, order_idx, active, source, created_at, updated_at)
      VALUES (
          $(e2e_sql_quote "$HOOK_ID"),
          'pre-run',
          'Authorization: ' || $(e2e_sql_quote "$TITLE"),
          $(e2e_sql_quote "$BODY"),
          $(e2e_sql_quote "$HOOK_ENFORCEMENT"),
          5,
          1,
          'authorize-cmd',
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
    echo "  also-hook   : $HOOK_ID (enforcement=$HOOK_ENFORCEMENT, order=5)"
fi

echo
echo "View with:    /e2e-test-specialist:authorize --show $AUTH_ID"
echo "Revoke with:  /e2e-test-specialist:authorize --revoke $AUTH_ID"
echo "List all:     /e2e-test-specialist:authorize --list"
```

## Examples

```bash
# Record the standing infra-provisioning grant from R-2027.
/e2e-test-specialist:authorize "Provision Forge servers and DO droplets for E2E" \
  --scope forge,do-droplets,lb-topology \
  --body "The autopilot has standing user authorization to create Forge servers and DigitalOcean droplets for E2E testing across all R-NNN rounds. Tier B phases (LB, DO lifecycle, Forge migration — P25/P26/P27/P28/P29/P40/P41/P42/P43/P52/P53/P54) MUST be driven LIVE; cross-run-coverage closure is no longer the default. Forbidden Forge IDs 919574 and 1175655 are NEVER mutated. Tear down pfimport-* and pfdo-* resources at run end (verify count==0)." \
  --also-hook --enforcement advisory

# Same authorization, body in a file.
/e2e-test-specialist:authorize "Provision E2E infra" --from .e2e-testing/auth/infra-grant.md \
  --scope forge,do-droplets --also-hook

# Inspect / list / revoke.
/e2e-test-specialist:authorize --list
/e2e-test-specialist:authorize --show auth-provision-e2e-infra
/e2e-test-specialist:authorize --revoke auth-provision-e2e-infra
```

## Why this exists

Without it, the autopilot has no record of standing user grants and has to
either (a) ask the user mid-run (forbidden by autopilot's no-prompt rule)
or (b) skip the test ("requires manual approval"). With an authorization
memory in place, the autopilot's pre-run briefing surfaces it as part of
the run context — the agent can drive Tier B phases live without prompting.

The memory side is what the agent **reads**; the optional `--also-hook`
side is what the agent **executes** if there's a verification step in the
body (e.g. "before granting, verify forbidden IDs are still in the
guard list"). For pure declarative grants, skip `--also-hook`.

## See also

- `/e2e-test-specialist:before-all` — pre-run hooks (procedural)
- `/e2e-test-specialist:memory` — generic memory management
- `commands/autopilot.md` § "Pre-run briefing" — how the autopilot reads this
