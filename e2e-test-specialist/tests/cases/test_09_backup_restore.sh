#!/usr/bin/env bash
# Verify backup-db.sh produces a working SQLite backup that can be restored.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Seed something distinguishable
sqlite3 "$E2E_DB" "
    INSERT INTO phases (id, title, phase_order) VALUES ('P-zz','marker',999);
"

# Make a backup
backup="$(bash "$CLAUDE_PLUGIN_ROOT/scripts/backup-db.sh" self-test)"
[[ -f "$backup" ]] || { echo "backup file missing: $backup"; exit 1; }

# Backup should contain the marker
m="$(sqlite3 "$backup" "SELECT title FROM phases WHERE id='P-zz';")"
[[ "$m" == "marker" ]] || { echo "marker not in backup: '$m'"; exit 1; }

# Mutate the original — delete the marker
sqlite3 "$E2E_DB" "DELETE FROM phases WHERE id='P-zz';"
remaining="$(sqlite3 "$E2E_DB" "SELECT COUNT(*) FROM phases WHERE id='P-zz';")"
[[ "$remaining" == "0" ]] || { echo "delete didn't take"; exit 1; }

# Restore the backup
cp "$backup" "$E2E_DB"

# Marker should be back
m2="$(sqlite3 "$E2E_DB" "SELECT title FROM phases WHERE id='P-zz';")"
[[ "$m2" == "marker" ]] || { echo "marker not restored: '$m2'"; exit 1; }
