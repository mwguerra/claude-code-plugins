#!/usr/bin/env bash
# Initialize the .e2e-testing/ structure inside the current working directory.
#
# Usage: bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-db.sh"
# Idempotent: safe to re-run.

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"

E2E_COMPONENT=init

if [[ -f "$E2E_DB" ]]; then
    existing="$(sqlite3 "$E2E_DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;' 2>/dev/null || true)"
    case "$existing" in
        1.4.0)
            echo "e2e-test-specialist already initialized at $E2E_ROOT_DIR (schema v$existing)."
            exit 0
            ;;
        1.3.0)
            echo "Found schema v1.3.0; migrating to v1.4.0 (skip_reason + fix_attempt_index + idempotent + affected_tests + coverage_links + notifications + resource_ledger)..."
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.3-to-v1.4.sh" "$E2E_DB"
            exit 0
            ;;
        1.2.0)
            echo "Found schema v1.2.0; migrating to v1.4.0..."
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.2-to-v1.3.sh" "$E2E_DB"
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.3-to-v1.4.sh" "$E2E_DB"
            exit 0
            ;;
        1.1.0)
            echo "Found schema v1.1.0; migrating to v1.4.0..."
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.1-to-v1.2.sh" "$E2E_DB"
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.2-to-v1.3.sh" "$E2E_DB"
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.3-to-v1.4.sh" "$E2E_DB"
            exit 0
            ;;
        1.0.0)
            echo "Found schema v1.0.0; migrating to v1.4.0..."
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.0-to-v1.1.sh" "$E2E_DB"
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.1-to-v1.2.sh" "$E2E_DB"
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.2-to-v1.3.sh" "$E2E_DB"
            bash "${CLAUDE_PLUGIN_ROOT}/schemas/migrate-v1.3-to-v1.4.sh" "$E2E_DB"
            exit 0
            ;;
        "")
            : # empty/missing version — proceed to fresh init below
            ;;
        *)
            e2e_die "found unknown schema v$existing — no migration path defined"
            ;;
    esac
fi

mkdir -p "$E2E_ROOT_DIR/runs" "$E2E_ROOT_DIR/logs"

sqlite3 "$E2E_DB" < "${CLAUDE_PLUGIN_ROOT}/schemas/schema.sql" >/dev/null

# Copy default config (only if missing — preserve user edits)
if [[ ! -f "$E2E_CONFIG" ]]; then
    cp "${CLAUDE_PLUGIN_ROOT}/schemas/default-config.json" "$E2E_CONFIG"
fi

# Verify
version="$(sqlite3 "$E2E_DB" 'SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;')"
[[ "$version" == "1.4.0" ]] || e2e_die "schema version mismatch: $version"

e2e_log INFO init "initialized $E2E_ROOT_DIR (schema v$version)"

cat <<EOF
e2e-test-specialist initialized at $E2E_ROOT_DIR/ (schema v$version)

  $E2E_DB         (SQLite database, WAL mode)
  $E2E_CONFIG     (config — edit crash_detection / retry / playwright)
  $E2E_ROOT_DIR/runs/  (per-run artifacts: screenshots, logs)
  $E2E_LOG        (append-only activity log)

Next steps:
  /e2e-test-specialist:import <path-to-existing-ledger.md>   # if you have one
  /e2e-test-specialist:plan discover                         # otherwise scan app code
  /e2e-test-specialist:start                                 # begin a run
EOF
