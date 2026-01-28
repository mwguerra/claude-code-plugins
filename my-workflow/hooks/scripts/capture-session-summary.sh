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

# Calculate duration (cross-platform)
START_TIME=$(sqlite3 "$DB" "SELECT started_at FROM sessions WHERE id = '$SESSION_ID'" 2>/dev/null)
DURATION_SECONDS=0
if [[ -n "$START_TIME" ]]; then
    START_EPOCH=$(date_to_epoch "$START_TIME")
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

# Update daily note with session data
TODAY=$(get_date)
db_exec "UPDATE daily_notes SET
    last_activity_at = '$TIMESTAMP',
    sessions_count = COALESCE(sessions_count, 0) + 1,
    total_work_seconds = COALESCE(total_work_seconds, 0) + $DURATION_SECONDS,
    updated_at = datetime('now')
WHERE date = '$TODAY'"

# Update projects worked (JSON array)
CURRENT_PROJECTS=$(sqlite3 "$DB" "SELECT COALESCE(projects_worked, '{}') FROM daily_notes WHERE date = '$TODAY'" 2>/dev/null || echo "{}")
if [[ -n "$PROJECT" ]]; then
    # Simple JSON update - add or increment project time
    if echo "$CURRENT_PROJECTS" | grep -q "\"$PROJECT\""; then
        # Project exists, increment time (simplified)
        db_exec "UPDATE daily_notes SET projects_worked = '$CURRENT_PROJECTS' WHERE date = '$TODAY'"
    else
        # Add new project
        if [[ "$CURRENT_PROJECTS" == "{}" ]]; then
            NEW_PROJECTS="{\"$PROJECT\":$DURATION_SECONDS}"
        else
            NEW_PROJECTS=$(echo "$CURRENT_PROJECTS" | sed "s/}$/,\"$PROJECT\":$DURATION_SECONDS}/")
        fi
        db_exec "UPDATE daily_notes SET projects_worked = '$NEW_PROJECTS' WHERE date = '$TODAY'"
    fi
fi

# ============================================================================
# Vault Sync (if enabled)
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_vault_structure

        DATE=$(get_date)
        SLUG=$(slugify "${PROJECT:-session}")
        TIME=$(date +%H%M)
        FILENAME="${DATE}-${TIME}-${SLUG}.md"
        FILE_PATH="$WORKFLOW_FOLDER/sessions/$FILENAME"
        REL_PATH="workflow/sessions/${FILENAME%.md}"

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
            SELECT title, activity_type, entity_id
            FROM activity_timeline
            WHERE session_id = '$SESSION_ID'
              AND activity_type NOT IN ('session_start', 'session_end')
            ORDER BY timestamp
        " 2>/dev/null)

        # Build related notes list
        RELATED=""

        # Find commits from this session
        COMMIT_LINKS=""
        if [[ "$COMMITS_JSON" != "[]" ]]; then
            echo "$COMMITS_JSON" | jq -r '.[]' 2>/dev/null | while read -r hash; do
                SHORT=$(git log -1 --format="%h" "$hash" 2>/dev/null)
                MSG=$(git log -1 --format="%s" "$hash" 2>/dev/null)
                COMMIT_SLUG=$(slugify "$MSG")
                COMMIT_FILE="workflow/commits/${DATE}-${COMMIT_SLUG}"
                if [[ -n "$COMMIT_LINKS" ]]; then
                    COMMIT_LINKS="$COMMIT_LINKS, [[${COMMIT_FILE}|${SHORT}]]"
                else
                    COMMIT_LINKS="[[${COMMIT_FILE}|${SHORT}]]"
                fi
            done
        fi

        # Find decisions from this session
        DECISION_LINKS=$(sqlite3 "$DB" "
            SELECT id, title FROM decisions
            WHERE source_session_id = '$SESSION_ID'
        " 2>/dev/null | while IFS='|' read -r did dtitle; do
            DSLUG=$(slugify "$dtitle")
            echo "[[workflow/decisions/${DATE}-${DSLUG}|${did}]]"
        done | paste -sd ', ' -)

        # Find commitments from this session
        COMMITMENT_LINKS=$(sqlite3 "$DB" "
            SELECT id, title FROM commitments
            WHERE source_session_id = '$SESSION_ID'
        " 2>/dev/null | while IFS='|' read -r cid ctitle; do
            echo "[[workflow/commitments/${cid}|${cid}]]"
        done | paste -sd ', ' -)

        # Check for project note
        PROJECT_NOTE="$VAULT_PATH/projects/$PROJECT/README.md"
        if [[ -f "$PROJECT_NOTE" ]]; then
            RELATED="[[projects/$PROJECT/README|$PROJECT]]"
        fi

        # Combine all related links
        for links in "$COMMIT_LINKS" "$DECISION_LINKS" "$COMMITMENT_LINKS"; do
            if [[ -n "$links" ]]; then
                if [[ -n "$RELATED" ]]; then
                    RELATED="$RELATED, $links"
                else
                    RELATED="$links"
                fi
            fi
        done

        # Build extra frontmatter
        EXTRA="session_id: \"$SESSION_ID\"
project: \"$PROJECT\"
duration: \"$DURATION_STR\"
duration_seconds: $DURATION_SECONDS"

        # Create vault note
        {
            create_vault_frontmatter "Session: $PROJECT" "Claude Code session in $PROJECT" "session, workflow, $PROJECT" "$RELATED" "$EXTRA"
            echo ""
            echo "# Session: $PROJECT"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| Date | $(date '+%Y-%m-%d %H:%M') |"
            echo "| Duration | $DURATION_STR |"
            echo "| Project | $PROJECT |"
            echo "| Session ID | \`$SESSION_ID\` |"
            echo ""

            if [[ -n "$SUMMARY" ]]; then
                echo "## Summary"
                echo ""
                echo "$SUMMARY"
                echo ""
            fi

            if [[ -n "$HIGHLIGHTS" ]]; then
                echo "## Activity"
                echo ""
                while IFS='|' read -r title activity_type entity_id; do
                    case "$activity_type" in
                        "commit")
                            echo "- **Commit**: $title"
                            ;;
                        "decision")
                            echo "- **Decision**: $title → [[workflow/decisions/${DATE}-$(slugify "$title")|$entity_id]]"
                            ;;
                        "commitment")
                            echo "- **Commitment**: $title → [[workflow/commitments/$entity_id|$entity_id]]"
                            ;;
                        *)
                            echo "- [$activity_type] $title"
                            ;;
                    esac
                done <<< "$HIGHLIGHTS"
                echo ""
            fi

            if [[ "$COMMITS_JSON" != "[]" ]]; then
                echo "## Commits"
                echo ""
                echo "$COMMITS_JSON" | jq -r '.[]' 2>/dev/null | while read -r hash; do
                    SHORT=$(git log -1 --format="%h" "$hash" 2>/dev/null)
                    MSG=$(git log -1 --format="%s" "$hash" 2>/dev/null)
                    COMMIT_SLUG=$(slugify "$MSG")
                    echo "- [[workflow/commits/${DATE}-${COMMIT_SLUG}|${SHORT}]] $MSG"
                done
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
