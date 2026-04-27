---
description: First-run interactive setup — init, import, seed authorizations, configure hooks, validate
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(ls:*), Bash(cat:*), Read(*), AskUserQuestion
argument-hint: [--ledger <path>] [--non-interactive]
---

# /e2e-test-specialist:wizard

End-to-end onboarding for a new project. Walks the user through:

1. **Init** — create `.e2e-testing/` if missing.
2. **Import** — find or accept a path to an `e2e-testing.md` ledger.
3. **Sanity check** — run `/e2e-test-specialist:doctor` and verify counts.
4. **Authorizations** — offer to seed common standing grants (infra
   provisioning, etc.) using `/e2e-test-specialist:authorize`.
5. **Lifecycle hooks** — offer to register a sample pre-run / post-run hook.
6. **Notifications** — confirm the default target and (optionally) a
   webhook URL.
7. **Test invocation** — print the exact `/autopilot` command to run.

Use `--non-interactive` to skip prompts (good for CI / scripted setup).

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"

INTERACTIVE=1
[[ "${NON_INTERACTIVE:-}" == "1" ]] && INTERACTIVE=0

# === 1. Init ============================================================
if [[ ! -f .e2e-testing/e2e-tests.sqlite ]]; then
    echo "Step 1/7 — Initializing .e2e-testing/ ..."
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-db.sh"
else
    echo "Step 1/7 — .e2e-testing/ already exists; running migration check..."
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-db.sh"
fi

source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

# === 2. Import ==========================================================
PHASE_COUNT="$(e2e_query_value 'SELECT COUNT(*) FROM phases;')"
if [[ "$PHASE_COUNT" -eq 0 ]]; then
    if [[ -z "${LEDGER:-}" ]]; then
        # Try common locations
        for candidate in e2e-testing.md docs/e2e-testing.md tests/e2e-testing.md .claude/e2e-testing.md; do
            [[ -f "$candidate" ]] && LEDGER="$candidate" && break
        done
    fi

    if [[ -n "${LEDGER:-}" && -f "$LEDGER" ]]; then
        echo "Step 2/7 — Importing ledger: $LEDGER"
        python3 "${CLAUDE_PLUGIN_ROOT}/scripts/import-ledger.py" "$LEDGER"
    else
        echo "Step 2/7 — No ledger found. Skipping import."
        echo "  When ready: /e2e-test-specialist:import <path-to-ledger.md>"
    fi
else
    echo "Step 2/7 — DB already has $PHASE_COUNT phase(s); skipping import."
fi

# === 3. Doctor ==========================================================
echo "Step 3/7 — Health check..."
echo "  (running /e2e-test-specialist:doctor — see output below)"
# Inline doctor essentials
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT 'phases' AS k, COUNT(*) AS n FROM phases
  UNION ALL SELECT 'tests', COUNT(*) FROM tests WHERE deprecated_at IS NULL
  UNION ALL SELECT 'test_steps', COUNT(*) FROM test_steps
  UNION ALL SELECT 'directives', COUNT(*) FROM directives WHERE active=1
  UNION ALL SELECT 'memories', COUNT(*) FROM memories WHERE status='active';
"

# === 4. Authorizations ==================================================
AUTH_COUNT="$(e2e_query_value "
  SELECT COUNT(*) FROM memories
   WHERE status='active' AND importance>=4
     AND (tags LIKE '%\"authorization\"%' OR tags LIKE '%\"standing-grant\"%');
")"
if [[ "$AUTH_COUNT" -eq 0 ]]; then
    echo "Step 4/7 — No authorizations on file."
    if [[ "$INTERACTIVE" -eq 1 ]]; then
        echo "  Many R-NNN runs need standing grants for infra provisioning."
        echo "  Record one with:"
        echo "    /e2e-test-specialist:authorize \"Provision E2E infra\" --scope forge,do-droplets --body \"...\""
    fi
else
    echo "Step 4/7 — $AUTH_COUNT authorization(s) on file:"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, title FROM memories
       WHERE status='active' AND importance>=4
         AND (tags LIKE '%\"authorization\"%' OR tags LIKE '%\"standing-grant\"%')
       ORDER BY updated_at DESC LIMIT 10;
    "
fi

# === 5. Lifecycle hooks =================================================
HOOK_COUNT="$(e2e_query_value "SELECT COUNT(*) FROM lifecycle_hooks WHERE active=1;")"
if [[ "$HOOK_COUNT" -eq 0 ]]; then
    echo "Step 5/7 — No lifecycle hooks. Common starters:"
    echo "    /e2e-test-specialist:before-all \"Verify VPS clean slate\" --body \"...\" --enforcement blocking"
    echo "    /e2e-test-specialist:after-all  \"Snapshot DB to _backups/\" --body \"bash \${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh post-run\""
else
    echo "Step 5/7 — $HOOK_COUNT lifecycle hook(s) registered:"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT id, phase, title FROM lifecycle_hooks WHERE active=1 ORDER BY phase, order_idx;
    "
fi

# === 6. Notifications ===================================================
DEFAULT_TARGET="$(e2e_config_get notifications.default_target "file:.e2e-testing/logs/notifications.log")"
WEBHOOK_URL="$(e2e_config_get notifications.webhook_url "")"
echo "Step 6/7 — Notifications:"
echo "  default target: $DEFAULT_TARGET"
echo "  webhook url:    ${WEBHOOK_URL:-(not set)}"
echo "  (edit .e2e-testing/config.json to change)"

# === 7. Next step =======================================================
echo ""
echo "Step 7/7 — Ready. Suggested next move:"
echo ""
APP_URL=""
if [[ -f .env ]]; then
    APP_URL="$(grep -E '^[[:space:]]*APP_URL[[:space:]]*=' .env | tail -n1 | sed -E 's/^[[:space:]]*APP_URL[[:space:]]*=[[:space:]]*//; s/^"//; s/"$//; s/^'"'"'//; s/'"'"'$//')"
fi
if [[ -n "$APP_URL" ]]; then
    echo "  /e2e-test-specialist:autopilot --label \"$(date -u +%Y-%m-%d) first run\""
    echo "  (will use APP_URL=$APP_URL from .env)"
else
    echo "  /e2e-test-specialist:autopilot https://your-app.test --label \"$(date -u +%Y-%m-%d) first run\""
fi
echo ""
echo "  Try a dry-run first to confirm the briefing + queue:"
echo "  /e2e-test-specialist:autopilot --dry-run"
```
