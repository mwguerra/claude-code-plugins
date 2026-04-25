#!/usr/bin/env bash
# Atomic backup of the e2e-tests.sqlite via SQLite's online .backup API.
# Called automatically by destructive commands (/restart, /plan reparse,
# /plan update-test, /plan deprecate-test). Also exposed as a manual command.
#
# Usage:
#   bash backup-db.sh                   → .e2e-testing/runs/_backups/{timestamp}-manual.sqlite
#   bash backup-db.sh "<reason-tag>"   → ...{timestamp}-{tag}.sqlite

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT is unset}/scripts/lib.sh"
E2E_COMPONENT=backup
e2e_require_db

reason="${1:-manual}"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$E2E_ROOT_DIR/runs/_backups"
mkdir -p "$backup_dir"
out="$backup_dir/${ts}-${reason//[^a-zA-Z0-9._-]/_}.sqlite"

sqlite3 "$E2E_DB" ".backup '$out'"

# Prune to keep last 30 backups (avoid unbounded growth)
keep="$(e2e_config_get backup.keep_count 30)"
if [[ "${keep:-30}" =~ ^[0-9]+$ ]]; then
    ls -1t "$backup_dir"/*.sqlite 2>/dev/null | tail -n +$((keep + 1)) | xargs -I{} rm -f {} || true
fi

e2e_log INFO backup "created $out"
printf '%s\n' "$out"
