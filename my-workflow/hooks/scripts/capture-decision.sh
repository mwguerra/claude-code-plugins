#!/bin/bash
# My Workflow Plugin - Extract Decisions from Conversation
# Triggered by PostToolUse events
# Captures architectural and process decisions with rationale

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-decision.sh triggered"

# Check if decision capture is enabled
if ! is_enabled "decisions"; then
    debug_log "Decision capture disabled"
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
# Decision Detection Patterns
# These patterns indicate decisions being made
# ============================================================================

DECISION_PATTERNS=(
    # Explicit decisions
    "decided to "
    "decision is to "
    "we'll go with "
    "let's go with "
    "the approach is "
    "the plan is to "
    # Architectural choices
    "using .* for "
    "implementing .* with "
    "the architecture "
    "the design "
    # Process decisions
    "from now on "
    "going forward "
    "the convention is "
    "the standard is "
    # Comparisons leading to choice
    "instead of "
    "rather than "
    "over .* because "
    # Finality indicators
    "settled on "
    "chose to "
    "picked "
)

# Check for decision patterns
FOUND_DECISION=""
MATCHING_PATTERN=""

for pattern in "${DECISION_PATTERNS[@]}"; do
    if echo "$TOOL_OUTPUT" | grep -Eqi "$pattern"; then
        FOUND_DECISION="true"
        MATCHING_PATTERN="$pattern"
        break
    fi
done

if [[ -z "$FOUND_DECISION" ]]; then
    debug_log "No decision patterns found"
    exit 0
fi

debug_log "Found decision pattern: $MATCHING_PATTERN"

# ============================================================================
# Extract Decision Context
# ============================================================================

# Get the surrounding context
CONTEXT=$(echo "$TOOL_OUTPUT" | grep -Ei "$MATCHING_PATTERN" | head -5)

if [[ -z "$CONTEXT" ]]; then
    debug_log "Could not extract context"
    exit 0
fi

# Generate title from the first match
TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100)
TITLE=$(echo "$TITLE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# Skip if title is too short
if [[ ${#TITLE} -lt 15 ]]; then
    debug_log "Title too short, skipping"
    exit 0
fi

# ============================================================================
# Determine Decision Category
# ============================================================================

CATEGORY="general"

# Architecture patterns
if echo "$CONTEXT" | grep -Eqi "architecture|design|pattern|structure|database|api|model|schema"; then
    CATEGORY="architecture"
# Technology patterns
elif echo "$CONTEXT" | grep -Eqi "library|framework|tool|package|dependency|version"; then
    CATEGORY="technology"
# Process patterns
elif echo "$CONTEXT" | grep -Eqi "workflow|process|convention|standard|practice|policy"; then
    CATEGORY="process"
# Design patterns
elif echo "$CONTEXT" | grep -Eqi "ui|ux|component|layout|style|color|interface"; then
    CATEGORY="design"
fi

# ============================================================================
# Extract Rationale (if present)
# ============================================================================

RATIONALE=""
# Look for "because", "since", "due to" patterns
RATIONALE_MATCH=$(echo "$TOOL_OUTPUT" | grep -Eoi "(because|since|due to|the reason|this is because)[^.]*\." | head -1)
if [[ -n "$RATIONALE_MATCH" ]]; then
    RATIONALE="$RATIONALE_MATCH"
fi

# ============================================================================
# Check for Duplicates
# ============================================================================

# Look for similar recent decisions to avoid duplicates
PROJECT=$(get_project_name)
ESCAPED_TITLE=$(sql_escape "$TITLE")

SIMILAR=$(sqlite3 "$DB" "
    SELECT COUNT(*)
    FROM decisions
    WHERE project = '$PROJECT'
      AND title LIKE '%$(echo "$TITLE" | cut -c1-30)%'
      AND created_at > datetime('now', '-1 hour')
" 2>/dev/null)

if [[ "$SIMILAR" -gt 0 ]]; then
    debug_log "Similar decision already exists, skipping"
    exit 0
fi

# ============================================================================
# Create Decision Record
# ============================================================================

SESSION_ID=$(get_current_session_id)
TIMESTAMP=$(get_iso_timestamp)
DECISION_ID=$(get_next_id "decisions" "D")

ESCAPED_CONTEXT=$(sql_escape "$CONTEXT")
ESCAPED_RATIONALE=$(sql_escape "$RATIONALE")

db_exec "INSERT INTO decisions (
    id, title, description, rationale, category,
    project, source_session_id, source_context, status
) VALUES (
    '$DECISION_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', '$ESCAPED_RATIONALE', '$CATEGORY',
    '$PROJECT', '$SESSION_ID', '$ESCAPED_CONTEXT', 'active'
)"

# Log activity
activity_log "decision" "Recorded decision: $TITLE" "decisions" "$DECISION_ID" "$PROJECT" "{\"category\":\"$CATEGORY\"}"

debug_log "Created decision $DECISION_ID: $TITLE ($CATEGORY)"

# ============================================================================
# Vault Sync (if enabled)
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_vault_structure

        DATE=$(get_date)
        SLUG=$(slugify "$TITLE")
        FILENAME="${DATE}-${SLUG}.md"
        FILE_PATH="$WORKFLOW_FOLDER/decisions/$FILENAME"

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
        EXTRA="decision_id: \"$DECISION_ID\"
category: \"$CATEGORY\"
project: \"$PROJECT\"
status: active"

        # Create vault note
        {
            create_vault_frontmatter "$TITLE" "Decision: $CATEGORY in $PROJECT" "decision, $PROJECT, $CATEGORY" "$RELATED" "$EXTRA"
            echo ""
            echo "# $TITLE"
            echo ""
            echo "| Field | Value |"
            echo "|-------|-------|"
            echo "| ID | $DECISION_ID |"
            echo "| Date | $(get_datetime) |"
            echo "| Category | $CATEGORY |"
            echo "| Project | $PROJECT |"
            echo "| Status | Active |"
            echo ""

            echo "## Decision"
            echo ""
            echo "$CONTEXT"
            echo ""

            if [[ -n "$RATIONALE" ]]; then
                echo "## Rationale"
                echo ""
                echo "$RATIONALE"
                echo ""
            fi

            echo "## Alternatives Considered"
            echo ""
            echo "<!-- Document alternatives that were considered -->"
            echo ""

            echo "## Consequences"
            echo ""
            echo "<!-- What are the implications of this decision? -->"
            echo ""

            # Link to session if available
            if [[ -n "$SESSION_LINKS" ]]; then
                echo "## Related Session"
                echo ""
                echo "Decision made during: $SESSION_LINKS"
                echo ""
            fi

        } > "$FILE_PATH"

        # Update decision with vault note path
        db_exec "UPDATE decisions SET vault_note_path = '$FILE_PATH' WHERE id = '$DECISION_ID'"

        debug_log "Created decision note: $FILE_PATH"
    fi
fi

# Silent exit - decisions are reviewed later
exit 0
