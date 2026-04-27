#!/usr/bin/env bash
# Backup retention policy: keep last 7 daily + last 1/week for 4 weeks +
# last 1/month for 12 months. Delete everything else under _backups/.
#
# Idempotent. Dry-run unless --apply is passed.
#
# Usage:
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/prune-backups.sh"           # report only
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/prune-backups.sh" --apply   # actually delete

set -euo pipefail
source "${CLAUDE_PLUGIN_ROOT:?}/scripts/lib.sh"

BACKUP_DIR="$E2E_ROOT_DIR/_backups"
APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "no backups dir: $BACKUP_DIR"
    exit 0
fi

# List backups newest first (mtime), capture path + epoch.
declare -a KEEP=()
declare -a PRUNE=()
NOW="$(date +%s)"

# stat -f (BSD/macOS) vs -c (GNU/Linux)
get_mtime() {
    stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1"
}

while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    MT="$(get_mtime "$f")"
    AGE_DAYS=$(( (NOW - MT) / 86400 ))
    BASENAME="$(basename "$f")"

    # Daily bucket: last 7 days, keep all
    if [[ "$AGE_DAYS" -le 7 ]]; then
        KEEP+=("$f|daily|${AGE_DAYS}d")
        continue
    fi

    # Weekly bucket: 7-28 days, keep one per ISO week
    if [[ "$AGE_DAYS" -le 28 ]]; then
        WK="$(date -r "$MT" +%Y-%V 2>/dev/null || date -d "@$MT" +%Y-%V)"
        BUCKET="weekly:$WK"
    elif [[ "$AGE_DAYS" -le 365 ]]; then
        # Monthly bucket: 28-365 days
        MO="$(date -r "$MT" +%Y-%m 2>/dev/null || date -d "@$MT" +%Y-%m)"
        BUCKET="monthly:$MO"
    else
        BUCKET="ancient"
    fi

    # If we've already kept one for this bucket, prune.
    SEEN_VAR="seen_$(printf '%s' "$BUCKET" | tr -c '[:alnum:]' _)"
    if [[ -z "${!SEEN_VAR:-}" ]]; then
        eval "$SEEN_VAR=1"
        KEEP+=("$f|$BUCKET|${AGE_DAYS}d")
    else
        PRUNE+=("$f|$BUCKET|${AGE_DAYS}d")
    fi
done < <(ls -t "$BACKUP_DIR"/*.sqlite 2>/dev/null)

echo "Backup retention plan:"
echo "  KEEP   (${#KEEP[@]}):"
for k in "${KEEP[@]}"; do printf '    %s\n' "$k"; done
echo "  PRUNE  (${#PRUNE[@]}):"
for p in "${PRUNE[@]}"; do printf '    %s\n' "$p"; done

if [[ "$APPLY" -eq 1 ]]; then
    for p in "${PRUNE[@]}"; do
        FILE="${p%%|*}"
        rm -f "$FILE"
        echo "  deleted: $FILE"
    done
    echo "Done."
else
    echo ""
    echo "(dry-run — re-run with --apply to delete)"
fi
