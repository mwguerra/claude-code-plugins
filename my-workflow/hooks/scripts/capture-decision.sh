#!/bin/bash
# My Workflow Plugin - Extract Decisions from Conversation
# Triggered by PostToolUse events
# Captures ALL architectural and process decisions with rationale

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"
source "$SCRIPT_DIR/db-helper.sh"
source "$SCRIPT_DIR/ai-extractor.sh"

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

# Skip very short content
if [[ ${#TOOL_OUTPUT} -lt 20 ]]; then
    debug_log "Tool output too short to analyze"
    exit 0
fi

# ============================================================================
# Extract ALL Decisions using AI or Patterns
# ============================================================================

PROJECT=$(get_project_name)
SESSION_ID=$(db_get_current_session_id)
DECISIONS_CREATED=0

# Use smart extraction (AI with pattern fallback)
EXTRACTION_RESULT=$(smart_extract_all_items "$TOOL_OUTPUT")

if [[ -z "$EXTRACTION_RESULT" ]]; then
    debug_log "No extraction result"
    exit 0
fi

# Get decisions array
DECISIONS=$(echo "$EXTRACTION_RESULT" | jq -c '.decisions // []')

if [[ "$DECISIONS" == "[]" || -z "$DECISIONS" ]]; then
    debug_log "No decisions found in extraction"
    exit 0
fi

debug_log "Found $(echo "$DECISIONS" | jq 'length') potential decisions"

# Process each decision (use process substitution to stay in main shell)
while read -r decision; do
    TITLE=$(echo "$decision" | jq -r '.title // empty')
    CATEGORY=$(echo "$decision" | jq -r '.category // "general"')
    RATIONALE=$(echo "$decision" | jq -r '.rationale // empty')

    # Skip if title is empty or too short
    if [[ -z "$TITLE" || ${#TITLE} -lt 15 ]]; then
        debug_log "Skipping decision with short/empty title"
        continue
    fi

    # Check for duplicates
    if db_check_duplicate "decisions" "$TITLE" 1 "$PROJECT"; then
        debug_log "Duplicate decision skipped: $TITLE"
        continue
    fi

    # Validate category
    case "$CATEGORY" in
        architecture|technology|process|design|general) ;;
        *) CATEGORY="general" ;;
    esac

    # Insert decision using db-helper
    DECISION_ID=$(db_insert_decision "$TITLE" "$TOOL_OUTPUT" "$CATEGORY" "$RATIONALE" "$SESSION_ID" "$PROJECT")

    if [[ -z "$DECISION_ID" ]]; then
        debug_log "Failed to create decision"
        continue
    fi

    # Log activity
    db_log_activity "decision" "Recorded decision: $TITLE" "decisions" "$DECISION_ID" "$PROJECT" "{\"category\":\"$CATEGORY\"}"

    # Update daily note in database
    db_add_daily_decision "$(get_date)" "$DECISION_ID"

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
            SLUG=$(smart_filename "$TITLE" "decision" 40)
            FILENAME="${DATE}-${SLUG}.md"
            FILE_PATH="$WORKFLOW_FOLDER/decisions/$FILENAME"
            REL_PATH="workflow/decisions/${FILENAME%.md}"

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

            # Create vault note (with retry logic for concurrent access)
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
                echo "$TITLE"
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

            } | create_vault_note_safe "$FILE_PATH"

            # Update decision with vault note path
            db_update_decision_vault_path "$DECISION_ID" "$FILE_PATH"

            # Log to daily vault note
            vault_log_activity "decision" "$TITLE" "$DECISION_ID" "$REL_PATH"

            debug_log "Created decision note: $FILE_PATH"
        fi
    fi

    DECISIONS_CREATED=$((DECISIONS_CREATED + 1))
done < <(echo "$DECISIONS" | jq -c '.[]' 2>/dev/null)

debug_log "Created $DECISIONS_CREATED decision(s)"

exit 0
