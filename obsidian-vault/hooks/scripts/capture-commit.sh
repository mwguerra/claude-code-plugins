#!/bin/bash
# Obsidian Vault Plugin - Capture Git Commits
# Triggered by PostToolUse on Bash commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-commit.sh triggered"

# Check if capture is enabled
if ! is_capture_enabled "commits"; then
    debug_log "Commit capture disabled"
    exit 0
fi

# Check vault configuration
VAULT_PATH=$(check_vault)
if [[ -z "$VAULT_PATH" ]]; then
    debug_log "Vault not configured"
    exit 0
fi

# Get the tool input (the command that was run)
TOOL_INPUT=$(get_tool_input)
debug_log "Tool input: $TOOL_INPUT"

# Check if this was a git commit command
if ! echo "$TOOL_INPUT" | grep -q "git commit"; then
    debug_log "Not a git commit command"
    exit 0
fi

debug_log "Git commit detected, capturing..."

# Get commit information
COMMIT_HASH=$(git log -1 --format="%H" 2>/dev/null)
COMMIT_SHORT=$(git log -1 --format="%h" 2>/dev/null)
COMMIT_MSG=$(git log -1 --format="%s" 2>/dev/null)
COMMIT_BODY=$(git log -1 --format="%b" 2>/dev/null)
COMMIT_AUTHOR=$(git log -1 --format="%an" 2>/dev/null)
COMMIT_DATE=$(git log -1 --format="%ci" 2>/dev/null | cut -d' ' -f1,2)

if [[ -z "$COMMIT_HASH" ]]; then
    debug_log "Could not get commit info"
    exit 0
fi

# Check if we already have a note for this commit
EXISTING=$(commit_note_exists "$VAULT_PATH" "$COMMIT_SHORT")
if [[ -n "$EXISTING" ]]; then
    debug_log "Note already exists: $EXISTING"
    exit 0
fi

# Get project and branch info
PROJECT=$(get_project_name)
BRANCH=$(get_git_branch)

# Get changed files
FILES_CHANGED=$(git diff-tree --no-commit-id --name-status -r "$COMMIT_HASH" 2>/dev/null | head -20)

# Generate filename
DATE=$(get_date)
SLUG=$(slugify "$COMMIT_MSG")
FILENAME="${DATE}-${SLUG}.md"
FILE_PATH="$VAULT_PATH/journal/commits/$FILENAME"

# Ensure directory exists
ensure_dir "$VAULT_PATH/journal/commits"

# Create tags
TAGS="commit, $PROJECT, $BRANCH"

# Check for related project note
RELATED=""
PROJECT_NOTE="$VAULT_PATH/projects/$PROJECT/README.md"
if [[ -f "$PROJECT_NOTE" ]]; then
    RELATED="[[projects/$PROJECT/README]]"
fi

# Create the note
{
    create_frontmatter "$COMMIT_MSG" "Git commit in $PROJECT on branch $BRANCH" "$TAGS" "$RELATED"
    echo ""
    echo "# $COMMIT_MSG"
    echo ""
    echo "**Date:** $COMMIT_DATE"
    echo "**Project:** $PROJECT"
    echo "**Branch:** $BRANCH"
    echo "**Commit:** $COMMIT_SHORT"
    echo ""

    if [[ -n "$COMMIT_BODY" ]]; then
        echo "## Description"
        echo ""
        echo "$COMMIT_BODY"
        echo ""
    fi

    echo "## What"
    echo ""
    echo "<!-- Describe what was changed -->"
    echo ""

    echo "## Why"
    echo ""
    echo "<!-- Explain the reasoning behind this change -->"
    echo ""

    echo "## Files Changed"
    echo ""
    echo '```'
    echo "$FILES_CHANGED"
    echo '```'
    echo ""

} > "$FILE_PATH"

debug_log "Created commit note: $FILE_PATH"

# Output for Claude to see (and potentially fill in)
echo "OBSIDIAN_COMMIT_NOTE_CREATED: $FILE_PATH"

exit 0
