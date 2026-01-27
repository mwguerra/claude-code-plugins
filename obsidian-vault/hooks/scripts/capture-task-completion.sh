#!/bin/bash
# Obsidian Vault Plugin - Capture Task Completions
# Triggered by SubagentStop event

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-task-completion.sh triggered"

# Check if capture is enabled
if ! is_capture_enabled "tasks"; then
    debug_log "Task capture disabled"
    exit 0
fi

# Check vault configuration
VAULT_PATH=$(check_vault)
if [[ -z "$VAULT_PATH" ]]; then
    debug_log "Vault not configured"
    exit 0
fi

# Get task information from environment
# Claude Code sets these for SubagentStop events
TASK_SUMMARY="${CLAUDE_SUBAGENT_SUMMARY:-}"
TASK_TYPE="${CLAUDE_SUBAGENT_TYPE:-}"

debug_log "Task type: $TASK_TYPE"
debug_log "Task summary length: ${#TASK_SUMMARY}"

# Skip if no meaningful summary
if [[ -z "$TASK_SUMMARY" ]] || [[ ${#TASK_SUMMARY} -lt 20 ]]; then
    debug_log "No meaningful task summary"
    exit 0
fi

# Get project info
PROJECT=$(get_project_name)
BRANCH=$(get_git_branch)

# Generate title from first line of summary or type
TITLE="${TASK_TYPE:-Task} Completion"
if [[ -n "$TASK_SUMMARY" ]]; then
    FIRST_LINE=$(echo "$TASK_SUMMARY" | head -1 | cut -c1-80)
    if [[ -n "$FIRST_LINE" ]]; then
        TITLE="$FIRST_LINE"
    fi
fi

# Generate filename
DATE=$(get_date)
DATETIME=$(get_datetime)
SLUG=$(slugify "$TITLE")
FILENAME="${DATE}-${SLUG}.md"
FILE_PATH="$VAULT_PATH/journal/tasks/$FILENAME"

# Ensure directory exists
ensure_dir "$VAULT_PATH/journal/tasks"

# Skip if file already exists (avoid duplicates)
if [[ -f "$FILE_PATH" ]]; then
    debug_log "Task note already exists: $FILE_PATH"
    exit 0
fi

# Create tags
TAGS="task, completed, $PROJECT"
if [[ -n "$TASK_TYPE" ]]; then
    TAGS="$TAGS, $TASK_TYPE"
fi

# Check for related project note
RELATED=""
PROJECT_NOTE="$VAULT_PATH/projects/$PROJECT/README.md"
if [[ -f "$PROJECT_NOTE" ]]; then
    RELATED="[[projects/$PROJECT/README]]"
fi

# Create the note
{
    create_frontmatter "$TITLE" "Task completed in $PROJECT" "$TAGS" "$RELATED"
    echo ""
    echo "# $TITLE"
    echo ""
    echo "**Completed:** $DATETIME"
    echo "**Project:** $PROJECT"
    if [[ -n "$BRANCH" ]]; then
        echo "**Branch:** $BRANCH"
    fi
    if [[ -n "$TASK_TYPE" ]]; then
        echo "**Agent Type:** $TASK_TYPE"
    fi
    echo ""

    echo "## Summary"
    echo ""
    echo "$TASK_SUMMARY"
    echo ""

    echo "## What Was Done"
    echo ""
    echo "<!-- Detailed breakdown of completed work -->"
    echo ""

    echo "## Decisions Made"
    echo ""
    echo "<!-- Key decisions and their rationale -->"
    echo ""

} > "$FILE_PATH"

debug_log "Created task note: $FILE_PATH"

echo "OBSIDIAN_TASK_NOTE_CREATED: $FILE_PATH"

exit 0
