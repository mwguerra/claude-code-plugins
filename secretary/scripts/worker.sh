#!/bin/bash
# Secretary Plugin - Background Worker
# Cron entry point: processes queue, syncs vault, refreshes cache
#
# Designed to be run by cron every 5 minutes:
# */5 * * * * flock -n /tmp/secretary-worker.lock timeout 120 bash ~/.claude/plugins/secretary/scripts/worker.sh >> ~/.claude/secretary/worker.log 2>&1
#
# Safety:
# - flock -n: Non-blocking lock, prevents overlapping runs
# - timeout 120: Hard kill after 2 minutes
# Cross-platform: Linux, macOS, Windows/Git Bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"
source "$PLUGIN_ROOT/hooks/scripts/lib/db.sh"

set +e

debug_log "worker.sh started"

DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    echo "[$(get_iso_timestamp)] ERROR: Database not initialized"
    exit 1
fi

# Record run start
sqlite3 "$DB" "
    UPDATE worker_state SET
        last_run_at = datetime('now'),
        total_runs = total_runs + 1,
        updated_at = datetime('now')
    WHERE id = 1
" 2>/dev/null

# ============================================================================
# Step 1: Expire old queue items before processing
# ============================================================================

EXPIRED=$(sqlite3 "$DB" "
    UPDATE queue SET status = 'expired'
    WHERE status = 'pending'
      AND created_at < datetime('now', '-' || ttl_hours || ' hours');
    SELECT changes();
" 2>/dev/null || echo "0")

if [[ "$EXPIRED" -gt 0 ]]; then
    echo "[$(get_iso_timestamp)] Expired $EXPIRED old queue items"
fi

# ============================================================================
# Step 2: Process pending queue items (up to 50)
# ============================================================================

QUEUE_COUNT=$(get_queue_count)
if [[ "$QUEUE_COUNT" -gt 0 ]]; then
    echo "[$(get_iso_timestamp)] Processing $QUEUE_COUNT pending queue items..."
    bash "$SCRIPT_DIR/process-queue.sh" --limit 50 2>&1
fi

# ============================================================================
# Step 3: Sync vault to git if changes exist
# ============================================================================

VAULT_SYNC_SCRIPT="$SCRIPT_DIR/vault-git-sync.sh"
if [[ -f "$VAULT_SYNC_SCRIPT" ]]; then
    # Only sync if vault is enabled and there are vault notes to sync
    if is_enabled "vault"; then
        LAST_VAULT_SYNC=$(sqlite3 "$DB" "SELECT last_vault_sync_at FROM worker_state WHERE id = 1" 2>/dev/null)
        # Sync if never synced or last sync was more than 15 minutes ago
        SHOULD_SYNC=false
        if [[ -z "$LAST_VAULT_SYNC" ]]; then
            SHOULD_SYNC=true
        else
            SYNC_EPOCH=$(date_to_epoch "$LAST_VAULT_SYNC")
            NOW_EPOCH=$(date +%s)
            DIFF=$((NOW_EPOCH - SYNC_EPOCH))
            if [[ $DIFF -gt 900 ]]; then
                SHOULD_SYNC=true
            fi
        fi

        if [[ "$SHOULD_SYNC" == "true" ]]; then
            echo "[$(get_iso_timestamp)] Syncing vault to git..."
            bash "$VAULT_SYNC_SCRIPT" worker 2>&1 || true
            sqlite3 "$DB" "UPDATE worker_state SET last_vault_sync_at = datetime('now') WHERE id = 1" 2>/dev/null
        fi
    fi
fi

# ============================================================================
# Step 4: Refresh GitHub cache if expired
# ============================================================================

if is_enabled "github" && command -v gh &>/dev/null; then
    CACHE_EXPIRED=$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM github_cache
        WHERE cache_type = 'combined' AND expires_at > datetime('now')
    " 2>/dev/null || echo "0")

    if [[ "$CACHE_EXPIRED" == "0" ]]; then
        GH_USERNAME=$(get_config '.github.username' '')
        if [[ -n "$GH_USERNAME" ]]; then
            echo "[$(get_iso_timestamp)] Refreshing GitHub cache..."
            CACHE_MINUTES=$(get_config '.github.cacheMinutes' '15')

            ISSUES=""
            if [[ "$(get_config '.github.trackIssues' 'true')" == "true" ]]; then
                ISSUES=$(gh issue list --assignee "$GH_USERNAME" --state open --limit 10 --json number,title,repository 2>/dev/null || echo "[]")
            fi

            REVIEWS=""
            if [[ "$(get_config '.github.trackReviews' 'true')" == "true" ]]; then
                REVIEWS=$(gh search prs --review-requested "$GH_USERNAME" --state open --limit 10 --json number,title,repository 2>/dev/null || echo "[]")
            fi

            PRS=""
            if [[ "$(get_config '.github.trackPRs' 'true')" == "true" ]]; then
                PRS=$(gh pr list --author "$GH_USERNAME" --state open --limit 10 --json number,title,repository 2>/dev/null || echo "[]")
            fi

            COMBINED_DATA="{\"issues\":${ISSUES:-[]},\"reviews\":${REVIEWS:-[]},\"prs\":${PRS:-[]}}"
            ESCAPED_DATA=$(sql_escape "$COMBINED_DATA")

            db_exec "INSERT OR REPLACE INTO github_cache (id, cache_type, data, fetched_at, expires_at)
                     VALUES ('combined', 'combined', '$ESCAPED_DATA', datetime('now'), datetime('now', '+$CACHE_MINUTES minutes'))"

            sqlite3 "$DB" "UPDATE worker_state SET last_github_refresh_at = datetime('now') WHERE id = 1" 2>/dev/null
        fi
    fi
fi

# ============================================================================
# Step 5: Record success
# ============================================================================

ITEMS_PROCESSED=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM queue WHERE status = 'processed' AND processed_at > (SELECT last_run_at FROM worker_state WHERE id = 1)
" 2>/dev/null || echo "0")

sqlite3 "$DB" "
    UPDATE worker_state SET
        last_success_at = datetime('now'),
        items_processed = items_processed + $ITEMS_PROCESSED,
        last_error = NULL,
        updated_at = datetime('now')
    WHERE id = 1
" 2>/dev/null

echo "[$(get_iso_timestamp)] Worker completed: $ITEMS_PROCESSED items processed"
debug_log "worker.sh completed: $ITEMS_PROCESSED items processed"
