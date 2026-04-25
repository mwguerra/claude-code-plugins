#!/usr/bin/env bash
# Verify init creates the expected layout and schema version.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh"

[[ -f "$E2E_DB" ]]      || { echo "DB not created"; exit 1; }
[[ -f "$E2E_CONFIG" ]]  || { echo "config not created"; exit 1; }
[[ -d "$E2E_ROOT_DIR/runs" ]] || { echo "runs/ not created"; exit 1; }
[[ -d "$E2E_ROOT_DIR/logs" ]] || { echo "logs/ not created"; exit 1; }

ver="$(sqlite3 "$E2E_DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
[[ "$ver" == "1.2.0" ]] || { echo "expected schema 1.2.0, got: $ver"; exit 1; }

# Idempotent: re-run is a no-op
bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/tmp/2nd-init.log 2>&1
grep -q "already initialized" /tmp/2nd-init.log || {
    echo "second init did not detect existing DB:"
    cat /tmp/2nd-init.log
    exit 1
}
