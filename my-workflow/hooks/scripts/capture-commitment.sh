#!/bin/bash
# My Workflow Plugin - Extract Commitments from Conversation
# Triggered by PostToolUse events
# Silently extracts promises, follow-ups, and action items

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-commitment.sh triggered"

# Check if commitment capture is enabled
if ! is_enabled "commitments"; then
    debug_log "Commitment capture disabled"
    exit 0
fi

# Ensure database exists
DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "Database not initialized"
    exit 0
fi

# Get tool output (conversation context)
TOOL_OUTPUT=$(get_tool_output)

if [[ -z "$TOOL_OUTPUT" ]]; then
    debug_log "No tool output to analyze"
    exit 0
fi

# ============================================================================
# Commitment Detection Patterns
# These patterns indicate promises or action items
# ============================================================================

# Patterns that indicate a commitment from Claude/assistant
COMMITMENT_PATTERNS=(
    # Direct promises
    "I will "
    "I'll "
    "Let me "
    # Future actions
    "will need to "
    "should be done "
    "needs to be "
    # Task indicators
    "TODO:"
    "FIXME:"
    "HACK:"
    # Follow-up indicators
    "follow up"
    "follow-up"
    "get back to"
    "circle back"
    "revisit this"
    # User requests that imply commitment
    "remind me to"
    "don't forget to"
    "make sure to"
    # Deferred work
    "later we should"
    "in a future session"
    "next time"
)

# Check if output contains any commitment patterns
FOUND_COMMITMENT=""
MATCHING_PATTERN=""

for pattern in "${COMMITMENT_PATTERNS[@]}"; do
    if echo "$TOOL_OUTPUT" | grep -qi "$pattern"; then
        FOUND_COMMITMENT="true"
        MATCHING_PATTERN="$pattern"
        break
    fi
done

if [[ -z "$FOUND_COMMITMENT" ]]; then
    debug_log "No commitment patterns found"
    exit 0
fi

debug_log "Found commitment pattern: $MATCHING_PATTERN"

# ============================================================================
# Extract Commitment Context
# ============================================================================

# Get the surrounding context (sentences containing the pattern)
# This is a simplified extraction - in production would use more sophisticated NLP
CONTEXT=$(echo "$TOOL_OUTPUT" | grep -i "$MATCHING_PATTERN" | head -3)

if [[ -z "$CONTEXT" ]]; then
    debug_log "Could not extract context"
    exit 0
fi

# Generate a title from the first line of context
TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100)

# Clean up the title
TITLE=$(echo "$TITLE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# Skip if title is too short or generic
if [[ ${#TITLE} -lt 10 ]]; then
    debug_log "Title too short, skipping"
    exit 0
fi

# ============================================================================
# Create Commitment Record
# ============================================================================

PROJECT=$(get_project_name)
SESSION_ID=$(get_current_session_id)
TIMESTAMP=$(get_iso_timestamp)
COMMITMENT_ID=$(get_next_id "commitments" "C")

# Escape for SQL
ESCAPED_TITLE=$(sql_escape "$TITLE")
ESCAPED_CONTEXT=$(sql_escape "$CONTEXT")

# Determine priority based on keywords
PRIORITY="medium"
if echo "$CONTEXT" | grep -qi "urgent\|critical\|asap\|immediately"; then
    PRIORITY="high"
elif echo "$CONTEXT" | grep -qi "when you have time\|low priority\|nice to have"; then
    PRIORITY="low"
fi

# Determine due type
DUE_TYPE="someday"
if echo "$CONTEXT" | grep -qi "today\|now\|immediately"; then
    DUE_TYPE="asap"
elif echo "$CONTEXT" | grep -qi "tomorrow\|soon\|this week"; then
    DUE_TYPE="soft"
elif echo "$CONTEXT" | grep -qi "deadline\|must\|by"; then
    DUE_TYPE="hard"
fi

# Insert commitment (silently)
db_exec "INSERT INTO commitments (
    id, title, description, source_type, source_session_id,
    source_context, project, priority, due_type, status
) VALUES (
    '$COMMITMENT_ID', '$ESCAPED_TITLE', '', 'conversation', '$SESSION_ID',
    '$ESCAPED_CONTEXT', '$PROJECT', '$PRIORITY', '$DUE_TYPE', 'pending'
)"

# Log activity (silent - will show in review)
activity_log "commitment" "Extracted commitment: $TITLE" "commitments" "$COMMITMENT_ID" "$PROJECT" "{\"pattern\":\"$MATCHING_PATTERN\"}"

debug_log "Created commitment $COMMITMENT_ID: $TITLE"

# ============================================================================
# Vault Sync (if enabled)
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_vault_structure

        # Use commitment ID in filename for uniqueness
        FILENAME="${COMMITMENT_ID}.md"
        FILE_PATH="$WORKFLOW_FOLDER/commitments/$FILENAME"

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
        EXTRA="commitment_id: \"$COMMITMENT_ID\"
project: \"$PROJECT\"
priority: \"$PRIORITY\"
due_type: \"$DUE_TYPE\"
status: pending"

        # Create vault note
        {
            create_vault_frontmatter "$TITLE" "Commitment in $PROJECT" "commitment, $PROJECT, $PRIORITY, pending" "$RELATED" "$EXTRA"
            echo ""
            echo "# $TITLE"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| ID | $COMMITMENT_ID |"
            echo "| Created | $(get_datetime) |"
            echo "| Project | $PROJECT |"
            echo "| Priority | $PRIORITY |"
            echo "| Due Type | $DUE_TYPE |"
            echo "| Status | Pending |"
            echo ""

            echo "## Context"
            echo ""
            echo "$CONTEXT"
            echo ""

            echo "## Details"
            echo ""
            echo "<!-- Add more details about this commitment -->"
            echo ""

            echo "## Notes"
            echo ""
            echo "<!-- Track progress and notes here -->"
            echo ""

            # Link to session if available
            if [[ -n "$SESSION_LINKS" ]]; then
                echo "## Related Session"
                echo ""
                echo "Commitment extracted during: $SESSION_LINKS"
                echo ""
            fi

        } > "$FILE_PATH"

        # Update commitment with vault note path
        db_exec "UPDATE commitments SET vault_note_path = '$FILE_PATH' WHERE id = '$COMMITMENT_ID'"

        debug_log "Created commitment note: $FILE_PATH"
    fi
fi

# Silent exit - commitments are reviewed later, not shown immediately
exit 0
