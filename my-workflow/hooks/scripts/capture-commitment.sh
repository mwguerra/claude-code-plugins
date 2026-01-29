#!/bin/bash
# My Workflow Plugin - Extract Commitments from Conversation
# Triggered by PostToolUse events
# Captures ALL promises, follow-ups, and action items

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"
source "$SCRIPT_DIR/db-helper.sh"
source "$SCRIPT_DIR/ai-extractor.sh"

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

# Skip very short content
if [[ ${#TOOL_OUTPUT} -lt 20 ]]; then
    debug_log "Tool output too short to analyze"
    exit 0
fi

# ============================================================================
# Extract ALL Commitments using AI or Patterns
# ============================================================================

PROJECT=$(get_project_name)
SESSION_ID=$(db_get_current_session_id)
COMMITMENTS_CREATED=0

# Use smart extraction (AI with pattern fallback)
EXTRACTION_RESULT=$(smart_extract_all_items "$TOOL_OUTPUT")

if [[ -z "$EXTRACTION_RESULT" ]]; then
    debug_log "No extraction result"
    exit 0
fi

# Get commitments array
COMMITMENTS=$(echo "$EXTRACTION_RESULT" | jq -c '.commitments // []')

if [[ "$COMMITMENTS" == "[]" || -z "$COMMITMENTS" ]]; then
    debug_log "No commitments found in extraction"
    exit 0
fi

debug_log "Found $(echo "$COMMITMENTS" | jq 'length') potential commitments"

# Process each commitment (use process substitution to stay in main shell)
while read -r commitment; do
    TITLE=$(echo "$commitment" | jq -r '.title // empty')
    PRIORITY=$(echo "$commitment" | jq -r '.priority // "medium"')
    DUE_TYPE=$(echo "$commitment" | jq -r '.due_type // "unspecified"')

    # Skip if title is empty or too short
    if [[ -z "$TITLE" || ${#TITLE} -lt 10 ]]; then
        debug_log "Skipping commitment with short/empty title"
        continue
    fi

    # Check for duplicates
    if db_check_duplicate "commitments" "$TITLE" 1 "$PROJECT"; then
        debug_log "Duplicate commitment skipped: $TITLE"
        continue
    fi

    # Validate priority
    case "$PRIORITY" in
        high|medium|low) ;;
        *) PRIORITY="medium" ;;
    esac

    # Validate due_type
    case "$DUE_TYPE" in
        immediate|soon|later|unspecified) ;;
        *) DUE_TYPE="unspecified" ;;
    esac

    # Insert commitment using db-helper
    COMMITMENT_ID=$(db_insert_commitment "$TITLE" "$TOOL_OUTPUT" "$PRIORITY" "$DUE_TYPE" "$SESSION_ID" "$PROJECT")

    if [[ -z "$COMMITMENT_ID" ]]; then
        debug_log "Failed to create commitment"
        continue
    fi

    # Log activity
    db_log_activity "commitment" "Extracted commitment: $TITLE" "commitments" "$COMMITMENT_ID" "$PROJECT" "{\"priority\":\"$PRIORITY\"}"

    debug_log "Created commitment $COMMITMENT_ID: $TITLE ($PRIORITY)"

    # ============================================================================
    # Vault Sync (if enabled)
    # ============================================================================

    if is_enabled "vault"; then
        VAULT_PATH=$(check_vault)
        if [[ -n "$VAULT_PATH" ]]; then
            WORKFLOW_FOLDER=$(get_workflow_folder)
            ensure_vault_structure
            ensure_dir "$WORKFLOW_FOLDER/commitments"

            # Use commitment ID in filename for uniqueness
            FILENAME="${COMMITMENT_ID}.md"
            FILE_PATH="$WORKFLOW_FOLDER/commitments/$FILENAME"
            REL_PATH="workflow/commitments/${COMMITMENT_ID}"

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

            # Create vault note (with retry logic for concurrent access)
            {
                create_vault_frontmatter "$TITLE" "Commitment in $PROJECT" "commitment, $PROJECT, $PRIORITY" "$RELATED" "$EXTRA"
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
                echo "$TITLE"
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

            } | create_vault_note_safe "$FILE_PATH"

            # Update commitment with vault note path
            db_update_commitment_vault_path "$COMMITMENT_ID" "$FILE_PATH"

            # Log to daily vault note
            vault_log_activity "commitment" "$TITLE" "$COMMITMENT_ID" "$REL_PATH"

            debug_log "Created commitment note: $FILE_PATH"
        fi
    fi

    COMMITMENTS_CREATED=$((COMMITMENTS_CREATED + 1))
done < <(echo "$COMMITMENTS" | jq -c '.[]' 2>/dev/null)

debug_log "Created $COMMITMENTS_CREATED commitment(s)"

# Silent exit - commitments are reviewed later
exit 0
