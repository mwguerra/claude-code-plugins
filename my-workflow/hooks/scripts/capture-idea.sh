#!/bin/bash
# My Workflow Plugin - Extract Ideas from Conversation
# Triggered by PostToolUse events
# Captures ALL ideas, suggestions, and explorations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"
source "$SCRIPT_DIR/db-helper.sh"
source "$SCRIPT_DIR/ai-extractor.sh"

debug_log "capture-idea.sh triggered"

# Check if idea capture is enabled
if ! is_enabled "ideas"; then
    debug_log "Idea capture disabled"
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
# Extract ALL Ideas using AI or Patterns
# ============================================================================

PROJECT=$(get_project_name)
SESSION_ID=$(db_get_current_session_id)
IDEAS_CREATED=0

# Use smart extraction (AI with pattern fallback)
EXTRACTION_RESULT=$(smart_extract_all_items "$TOOL_OUTPUT")

if [[ -z "$EXTRACTION_RESULT" ]]; then
    debug_log "No extraction result"
    exit 0
fi

# Get ideas array
IDEAS=$(echo "$EXTRACTION_RESULT" | jq -c '.ideas // []')

if [[ "$IDEAS" == "[]" || -z "$IDEAS" ]]; then
    debug_log "No ideas found in extraction"
    exit 0
fi

debug_log "Found $(echo "$IDEAS" | jq 'length') potential ideas"

# Process each idea (use process substitution to stay in main shell)
while read -r idea; do
    TITLE=$(echo "$idea" | jq -r '.title // empty')
    IDEA_TYPE=$(echo "$idea" | jq -r '.type // "exploration"')
    POTENTIAL=$(echo "$idea" | jq -r '.potential // empty')

    # Skip if title is empty or too short
    if [[ -z "$TITLE" || ${#TITLE} -lt 15 ]]; then
        debug_log "Skipping idea with short/empty title"
        continue
    fi

    # Check for duplicates (30 minute window for ideas)
    if db_check_duplicate "ideas" "$TITLE" 0.5 "$PROJECT"; then
        debug_log "Duplicate idea skipped: $TITLE"
        continue
    fi

    # Validate type
    case "$IDEA_TYPE" in
        feature|improvement|exploration|refactor|question) ;;
        *) IDEA_TYPE="exploration" ;;
    esac

    # Insert idea using db-helper
    IDEA_ID=$(db_insert_idea "$TITLE" "$TOOL_OUTPUT" "$IDEA_TYPE" "$SESSION_ID" "$PROJECT")

    if [[ -z "$IDEA_ID" ]]; then
        debug_log "Failed to create idea"
        continue
    fi

    # Log activity
    db_log_activity "idea" "Captured idea: $TITLE" "ideas" "$IDEA_ID" "$PROJECT" "{\"type\":\"$IDEA_TYPE\"}"

    # Update daily note in database
    db_add_daily_idea "$(get_date)" "$IDEA_ID"

    debug_log "Created idea $IDEA_ID: $TITLE ($IDEA_TYPE)"

    # ============================================================================
    # Vault Sync (if enabled)
    # ============================================================================

    if is_enabled "vault"; then
        VAULT_PATH=$(check_vault)
        if [[ -n "$VAULT_PATH" ]]; then
            WORKFLOW_FOLDER=$(get_workflow_folder)
            ensure_vault_structure
            ensure_dir "$WORKFLOW_FOLDER/ideas"

            DATE=$(get_date)
            SLUG=$(smart_filename "$TITLE" "idea" 40)
            FILENAME="${IDEA_ID}-${SLUG}.md"
            FILE_PATH="$WORKFLOW_FOLDER/ideas/$FILENAME"
            REL_PATH="workflow/ideas/${FILENAME%.md}"

            # Build related notes
            RELATED=""

            # Link to today's sessions
            SESSION_LINKS=$(get_todays_session_links)
            if [[ -n "$SESSION_LINKS" ]]; then
                RELATED="$SESSION_LINKS"
            fi

            # Build extra frontmatter
            EXTRA="idea_id: \"$IDEA_ID\"
idea_type: \"$IDEA_TYPE\"
project: \"$PROJECT\"
priority: medium
effort: unknown
status: captured"

            # Create vault note
            {
                create_vault_frontmatter "$TITLE" "Idea: $IDEA_TYPE" "idea, $IDEA_TYPE, $PROJECT" "$RELATED" "$EXTRA"
                echo ""
                echo "# $TITLE"
                echo ""
                echo "## Context"
                echo ""
                echo "$TITLE"
                echo ""

                if [[ -n "$POTENTIAL" ]]; then
                    echo "## Potential Value"
                    echo ""
                    echo "$POTENTIAL"
                    echo ""
                fi

                echo "## Notes"
                echo ""
                echo "<!-- Add your thoughts here -->"
                echo ""

                echo "## Related"
                echo ""
                if [[ -n "$SESSION_LINKS" ]]; then
                    echo "- Session: $SESSION_LINKS"
                fi
                echo "- Project: $PROJECT"
                echo ""

            } > "$FILE_PATH"

            # Update idea with vault note path
            db_update_idea_vault_path "$IDEA_ID" "$REL_PATH"

            # Log to daily vault note
            vault_log_activity "idea" "$TITLE" "$IDEA_ID" "$REL_PATH"

            debug_log "Created idea note: $FILE_PATH"
        fi
    fi

    IDEAS_CREATED=$((IDEAS_CREATED + 1))
done < <(echo "$IDEAS" | jq -c '.[]' 2>/dev/null)

debug_log "Created $IDEAS_CREATED idea(s)"

exit 0
