#!/bin/bash
# My Workflow Plugin - Detect External Changes
# Utility script to detect changes made outside Claude Code
# Called by sync command, not by hooks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "detect-external-changes.sh triggered"

# Ensure database exists
DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "Database not initialized"
    exit 0
fi

PROJECT=$(get_project_name)
TIMESTAMP=$(get_iso_timestamp)

# ============================================================================
# Git Changes Detection
# ============================================================================

detect_git_changes() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        return
    fi

    # Get last known commit from our activity
    LAST_KNOWN=$(sqlite3 "$DB" "
        SELECT details
        FROM activity_timeline
        WHERE activity_type = 'commit'
          AND project = '$PROJECT'
        ORDER BY timestamp DESC LIMIT 1
    " 2>/dev/null | jq -r '.hash // empty' 2>/dev/null)

    if [[ -z "$LAST_KNOWN" ]]; then
        # No commits tracked yet, skip
        return
    fi

    # Find commits not in our activity log
    while IFS='|' read -r hash short msg author date; do
        if [[ -z "$hash" ]]; then continue; fi

        # Check if we already have this commit
        EXISTS=$(sqlite3 "$DB" "
            SELECT COUNT(*)
            FROM activity_timeline
            WHERE activity_type = 'commit'
              AND details LIKE '%$short%'
        " 2>/dev/null)

        if [[ "$EXISTS" == "0" ]]; then
            CHANGE_ID=$(get_next_id "external_changes" "X")
            DETAILS="{\"hash\":\"$hash\",\"short\":\"$short\",\"author\":\"$author\",\"date\":\"$date\"}"
            ESCAPED_MSG=$(sql_escape "$msg")
            ESCAPED_DETAILS=$(sql_escape "$DETAILS")

            db_exec "INSERT INTO external_changes (
                id, change_type, source, description, details,
                project, detected_at
            ) VALUES (
                '$CHANGE_ID', 'git', 'external_commit', '$ESCAPED_MSG',
                '$ESCAPED_DETAILS', '$PROJECT', '$TIMESTAMP'
            )"

            echo "GIT: $short - $msg (by $author)"
        fi
    done < <(git log --since="$(days_ago_date 7)" --format="%H|%h|%s|%an|%ci" 2>/dev/null)
}

# ============================================================================
# File Changes Detection
# ============================================================================

detect_file_changes() {
    # Get last session end time
    LAST_SESSION=$(sqlite3 "$DB" "
        SELECT ended_at
        FROM sessions
        WHERE project = '$PROJECT'
          AND ended_at IS NOT NULL
        ORDER BY ended_at DESC LIMIT 1
    " 2>/dev/null)

    if [[ -z "$LAST_SESSION" ]]; then
        return
    fi

    # Create temp file with last session timestamp (cross-platform)
    TEMP_FILE=$(mktemp)
    touch_date "$LAST_SESSION" "$TEMP_FILE"

    # Find files modified since last session
    COUNT=0
    while IFS= read -r file; do
        if [[ -z "$file" ]]; then continue; fi
        if [[ $COUNT -ge 50 ]]; then break; fi

        # Skip common non-relevant files
        case "$file" in
            *.log|*.tmp|*.cache|*.lock|package-lock.json|yarn.lock|composer.lock)
                continue
                ;;
        esac

        CHANGE_ID=$(get_next_id "external_changes" "X")
        MOD_TIME=$(file_mtime "$file")
        DETAILS="{\"file\":\"$file\",\"modified\":$MOD_TIME}"

        db_exec "INSERT INTO external_changes (
            id, change_type, source, description, details,
            project, file_path, detected_at
        ) VALUES (
            '$CHANGE_ID', 'file', 'filesystem', 'File modified: $file',
            '$DETAILS', '$PROJECT', '$file', '$TIMESTAMP'
        )"

        echo "FILE: $file"
        COUNT=$((COUNT + 1))
    done < <(find . -type f -newer "$TEMP_FILE" \
        -not -path "./.git/*" \
        -not -path "./node_modules/*" \
        -not -path "./vendor/*" \
        -not -path "./__pycache__/*" \
        -not -path "./venv/*" \
        -not -path "./.venv/*" \
        2>/dev/null)

    rm -f "$TEMP_FILE"
}

# ============================================================================
# GitHub Changes Detection
# ============================================================================

detect_github_changes() {
    if ! command -v gh &>/dev/null; then
        return
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        return
    fi

    GH_USERNAME=$(get_config '.github.username' '')
    if [[ -z "$GH_USERNAME" ]]; then
        return
    fi

    # Check for new notifications
    NOTIFICATIONS=$(gh api notifications --jq '.[].subject | "\(.type)|\(.title)"' 2>/dev/null | head -10)

    while IFS='|' read -r type title; do
        if [[ -z "$type" ]]; then continue; fi

        CHANGE_ID=$(get_next_id "external_changes" "X")
        ESCAPED_TITLE=$(sql_escape "$title")
        DETAILS="{\"type\":\"$type\"}"

        db_exec "INSERT INTO external_changes (
            id, change_type, source, description, details,
            detected_at
        ) VALUES (
            '$CHANGE_ID', 'github', 'notification', '$ESCAPED_TITLE',
            '$DETAILS', '$TIMESTAMP'
        )"

        echo "GITHUB: [$type] $title"
    done <<< "$NOTIFICATIONS"
}

# ============================================================================
# Main
# ============================================================================

echo "Detecting external changes..."
echo ""

echo "## Git Commits"
detect_git_changes
echo ""

echo "## File Changes"
detect_file_changes
echo ""

echo "## GitHub Activity"
detect_github_changes
echo ""

# Count unacknowledged changes
TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM external_changes WHERE acknowledged = 0" 2>/dev/null)
echo "---"
echo "Total unacknowledged changes: $TOTAL"

exit 0
