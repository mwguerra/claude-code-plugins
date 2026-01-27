#!/bin/bash
# Obsidian Vault Plugin - Capture Session Summary
# Triggered by Stop event (end of conversation)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-session-summary.sh triggered"

# Check if capture is enabled
if ! is_capture_enabled "sessionSummaries"; then
    debug_log "Session summary capture disabled"
    exit 0
fi

# Check vault configuration
VAULT_PATH=$(check_vault)
if [[ -z "$VAULT_PATH" ]]; then
    debug_log "Vault not configured"
    exit 0
fi

# Get session information from environment
SESSION_SUMMARY="${CLAUDE_STOP_SUMMARY:-}"

debug_log "Session summary length: ${#SESSION_SUMMARY}"

# Skip if no meaningful summary
if [[ -z "$SESSION_SUMMARY" ]] || [[ ${#SESSION_SUMMARY} -lt 50 ]]; then
    debug_log "No meaningful session summary"
    exit 0
fi

# Get project info
PROJECT=$(get_project_name)
BRANCH=$(get_git_branch)

# Generate title from summary
TITLE="Session Summary"
FIRST_LINE=$(echo "$SESSION_SUMMARY" | head -1 | cut -c1-60)
if [[ -n "$FIRST_LINE" ]]; then
    TITLE="$FIRST_LINE"
fi

# Use timestamp in filename to allow multiple sessions per day
DATE=$(get_date)
TIMESTAMP=$(date +%H%M)
DATETIME=$(get_datetime)
SLUG=$(slugify "$TITLE")
FILENAME="${DATE}-${TIMESTAMP}-${SLUG}.md"
FILE_PATH="$VAULT_PATH/journal/tasks/$FILENAME"

# Ensure directory exists
ensure_dir "$VAULT_PATH/journal/tasks"

# Create tags
TAGS="session, summary, $PROJECT"

# Check for related project note
RELATED=""
PROJECT_NOTE="$VAULT_PATH/projects/$PROJECT/README.md"
if [[ -f "$PROJECT_NOTE" ]]; then
    RELATED="[[projects/$PROJECT/README]]"
fi

# Look for related commits from today
TODAY_COMMITS=$(find "$VAULT_PATH/journal/commits" -name "${DATE}*.md" 2>/dev/null | head -5)
for commit_file in $TODAY_COMMITS; do
    if [[ -f "$commit_file" ]]; then
        rel_path="${commit_file#$VAULT_PATH/}"
        rel_path="${rel_path%.md}"
        if [[ -n "$RELATED" ]]; then
            RELATED="$RELATED, [[$rel_path]]"
        else
            RELATED="[[$rel_path]]"
        fi
    fi
done

# Create the note
{
    create_frontmatter "$TITLE" "Claude Code session in $PROJECT" "$TAGS" "$RELATED"
    echo ""
    echo "# $TITLE"
    echo ""
    echo "**Date:** $DATETIME"
    echo "**Project:** $PROJECT"
    if [[ -n "$BRANCH" ]]; then
        echo "**Branch:** $BRANCH"
    fi
    echo ""

    echo "## Session Summary"
    echo ""
    echo "$SESSION_SUMMARY"
    echo ""

    echo "## Key Outcomes"
    echo ""
    echo "<!-- Main accomplishments from this session -->"
    echo ""

    echo "## Next Steps"
    echo ""
    echo "<!-- What should be done in future sessions -->"
    echo ""

} > "$FILE_PATH"

debug_log "Created session note: $FILE_PATH"

echo "OBSIDIAN_SESSION_NOTE_CREATED: $FILE_PATH"

exit 0
