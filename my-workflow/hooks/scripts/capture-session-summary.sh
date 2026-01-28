#!/bin/bash
# My Workflow Plugin - Capture Session Summary
# Triggered by Stop event (end of conversation)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-session-summary.sh triggered"

# Ensure database exists
DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "Database not initialized"
    exit 0
fi

# Get current session
SESSION_ID=$(get_current_session_id)
if [[ -z "$SESSION_ID" ]]; then
    debug_log "No active session"
    exit 0
fi

# Get session summary from environment
SUMMARY=$(get_stop_summary)
TIMESTAMP=$(get_iso_timestamp)
PROJECT=$(get_project_name)

debug_log "Session summary length: ${#SUMMARY}"

# Calculate duration
START_TIME=$(sqlite3 "$DB" "SELECT started_at FROM sessions WHERE id = '$SESSION_ID'" 2>/dev/null)
DURATION_SECONDS=0
if [[ -n "$START_TIME" ]]; then
    START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || echo "0")
    END_EPOCH=$(date +%s)
    if [[ "$START_EPOCH" -gt 0 ]]; then
        DURATION_SECONDS=$((END_EPOCH - START_EPOCH))
    fi
fi

# Get commits made during session
COMMITS_JSON="[]"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    # Get commits made since session start
    if [[ -n "$START_TIME" ]]; then
        COMMITS=$(git log --since="$START_TIME" --format="%H" 2>/dev/null | head -20)
        if [[ -n "$COMMITS" ]]; then
            COMMITS_JSON="[$(echo "$COMMITS" | sed 's/^/"/' | sed 's/$/"/' | paste -sd ',' -)]"
        fi
    fi
fi

# Update session record
ESCAPED_SUMMARY=$(sql_escape "$SUMMARY")
db_exec "UPDATE sessions SET
    ended_at = '$TIMESTAMP',
    duration_seconds = $DURATION_SECONDS,
    summary = '$ESCAPED_SUMMARY',
    commits = '$COMMITS_JSON',
    status = 'completed',
    updated_at = '$TIMESTAMP'
WHERE id = '$SESSION_ID'"

# Log activity
activity_log "session_end" "Completed session ($DURATION_SECONDS seconds)" "sessions" "$SESSION_ID" "$PROJECT" "{\"duration\":$DURATION_SECONDS}"

# Clear current session
db_exec "UPDATE state SET current_session_id = NULL, updated_at = '$TIMESTAMP' WHERE id = 1"

# ============================================================================
# Vault Sync (if enabled)
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_dir "$WORKFLOW_FOLDER/sessions"

        DATE=$(get_date)
        SLUG=$(slugify "${PROJECT:-session}")
        TIME=$(date +%H%M)
        FILENAME="${DATE}-${TIME}-${SLUG}.md"
        FILE_PATH="$WORKFLOW_FOLDER/sessions/$FILENAME"

        # Format duration
        HOURS=$((DURATION_SECONDS / 3600))
        MINUTES=$(((DURATION_SECONDS % 3600) / 60))
        DURATION_STR=""
        if [[ $HOURS -gt 0 ]]; then
            DURATION_STR="${HOURS}h ${MINUTES}m"
        else
            DURATION_STR="${MINUTES}m"
        fi

        # Get session highlights from activity timeline
        HIGHLIGHTS=$(sqlite3 "$DB" "
            SELECT title, activity_type
            FROM activity_timeline
            WHERE session_id = '$SESSION_ID'
              AND activity_type NOT IN ('session_start', 'session_end')
            ORDER BY timestamp
        " 2>/dev/null)

        # Create vault note
        {
            echo "---"
            echo "title: \"Session: $PROJECT\""
            echo "session_id: \"$SESSION_ID\""
            echo "project: \"$PROJECT\""
            echo "date: $DATE"
            echo "duration: \"$DURATION_STR\""
            echo "duration_seconds: $DURATION_SECONDS"
            echo "tags: [session, workflow, $PROJECT]"
            echo "---"
            echo ""
            echo "# Session: $PROJECT"
            echo ""
            echo "**Date:** $(date '+%Y-%m-%d %H:%M')"
            echo "**Duration:** $DURATION_STR"
            echo "**Session ID:** $SESSION_ID"
            echo ""

            if [[ -n "$SUMMARY" ]]; then
                echo "## Summary"
                echo ""
                echo "$SUMMARY"
                echo ""
            fi

            if [[ -n "$HIGHLIGHTS" ]]; then
                echo "## Activity Highlights"
                echo ""
                while IFS='|' read -r title activity_type; do
                    echo "- [$activity_type] $title"
                done <<< "$HIGHLIGHTS"
                echo ""
            fi

            if [[ "$COMMITS_JSON" != "[]" ]]; then
                echo "## Commits"
                echo ""
                echo '```'
                echo "$COMMITS_JSON" | jq -r '.[]' 2>/dev/null | while read -r hash; do
                    git log -1 --format="- %h %s" "$hash" 2>/dev/null
                done
                echo '```'
                echo ""
            fi

            echo "## Next Steps"
            echo ""
            echo "<!-- Add follow-up items -->"
            echo ""

        } > "$FILE_PATH"

        # Update session with vault note path
        db_exec "UPDATE sessions SET vault_note_path = '$FILE_PATH' WHERE id = '$SESSION_ID'"

        debug_log "Created vault note: $FILE_PATH"
        echo "WORKFLOW_SESSION_NOTE: $FILE_PATH"
    fi
fi

debug_log "Session $SESSION_ID completed"

exit 0
