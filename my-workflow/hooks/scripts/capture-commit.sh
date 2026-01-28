#!/bin/bash
# My Workflow Plugin - Capture Git Commits
# Triggered by PostToolUse on Bash commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-commit.sh triggered"

# Check if commit capture is enabled
if ! is_enabled "commits"; then
    debug_log "Commit capture disabled"
    exit 0
fi

# Ensure database exists
DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "Database not initialized"
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

# Verify we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    debug_log "Not in a git repository"
    exit 0
fi

# Get commit information
COMMIT_HASH=$(git log -1 --format="%H" 2>/dev/null)
COMMIT_SHORT=$(git log -1 --format="%h" 2>/dev/null)
COMMIT_MSG=$(git log -1 --format="%s" 2>/dev/null)
COMMIT_BODY=$(git log -1 --format="%b" 2>/dev/null)
COMMIT_AUTHOR=$(git log -1 --format="%an" 2>/dev/null)
COMMIT_DATE=$(git log -1 --format="%ci" 2>/dev/null)

if [[ -z "$COMMIT_HASH" ]]; then
    debug_log "Could not get commit info"
    exit 0
fi

# Get project and branch info
PROJECT=$(get_project_name)
BRANCH=$(get_git_branch)
SESSION_ID=$(get_current_session_id)

# Get changed files
FILES_CHANGED=$(git diff-tree --no-commit-id --name-status -r "$COMMIT_HASH" 2>/dev/null | head -20)
FILES_JSON="[]"
if [[ -n "$FILES_CHANGED" ]]; then
    FILES_JSON=$(echo "$FILES_CHANGED" | awk '{print "\""$2"\""}' | paste -sd ',' - | sed 's/^/[/' | sed 's/$/]/')
fi

# Log activity
activity_log "commit" "$COMMIT_MSG" "commit" "$COMMIT_SHORT" "$PROJECT" "{\"hash\":\"$COMMIT_HASH\",\"branch\":\"$BRANCH\"}"

debug_log "Logged commit: $COMMIT_SHORT"

# ============================================================================
# Vault Sync (if enabled)
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_vault_structure

        DATE=$(get_date)
        SLUG=$(slugify "$COMMIT_MSG")
        FILENAME="${DATE}-${SLUG}.md"
        FILE_PATH="$WORKFLOW_FOLDER/commits/$FILENAME"

        # Skip if note already exists
        if [[ -f "$FILE_PATH" ]]; then
            debug_log "Commit note already exists"
            exit 0
        fi

        # Determine commit type from conventional commit
        COMMIT_TYPE="chore"
        if [[ "$COMMIT_MSG" =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: ]]; then
            COMMIT_TYPE="${BASH_REMATCH[1]}"
        fi

        # Build related notes
        RELATED=""

        # Link to today's sessions
        SESSION_LINKS=$(get_todays_session_links)
        if [[ -n "$SESSION_LINKS" ]]; then
            RELATED="$SESSION_LINKS"
        fi

        # Link to project note
        PROJECT_NOTE="$VAULT_PATH/projects/$PROJECT/README.md"
        if [[ -f "$PROJECT_NOTE" ]]; then
            if [[ -n "$RELATED" ]]; then
                RELATED="$RELATED, [[projects/$PROJECT/README|$PROJECT]]"
            else
                RELATED="[[projects/$PROJECT/README|$PROJECT]]"
            fi
        fi

        # Build extra frontmatter
        EXTRA="commit: \"$COMMIT_SHORT\"
hash: \"$COMMIT_HASH\"
project: \"$PROJECT\"
branch: \"$BRANCH\"
author: \"$COMMIT_AUTHOR\"
commit_type: \"$COMMIT_TYPE\""

        # Create vault note
        {
            create_vault_frontmatter "$COMMIT_MSG" "Git commit in $PROJECT on branch $BRANCH" "commit, $PROJECT, $BRANCH, $COMMIT_TYPE" "$RELATED" "$EXTRA"
            echo ""
            echo "# $COMMIT_MSG"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| Date | $COMMIT_DATE |"
            echo "| Project | $PROJECT |"
            echo "| Branch | $BRANCH |"
            echo "| Commit | \`$COMMIT_SHORT\` |"
            echo "| Author | $COMMIT_AUTHOR |"
            echo "| Type | $COMMIT_TYPE |"
            echo ""

            if [[ -n "$COMMIT_BODY" ]]; then
                echo "## Description"
                echo ""
                echo "$COMMIT_BODY"
                echo ""
            fi

            echo "## Files Changed"
            echo ""
            echo '```'
            echo "$FILES_CHANGED"
            echo '```'
            echo ""

            echo "## Context"
            echo ""
            echo "### What"
            echo "<!-- Describe what was changed -->"
            echo ""
            echo "### Why"
            echo "<!-- Explain the reasoning -->"
            echo ""

            # Link to session if available
            if [[ -n "$SESSION_LINKS" ]]; then
                echo "## Related Session"
                echo ""
                echo "This commit was made during: $SESSION_LINKS"
                echo ""
            fi

        } > "$FILE_PATH"

        debug_log "Created commit note: $FILE_PATH"
    fi
fi

exit 0
