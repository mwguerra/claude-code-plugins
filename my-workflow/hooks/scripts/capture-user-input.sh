#!/bin/bash
# My Workflow Plugin - Capture User Input
# Triggered by UserPromptSubmit events
# Captures decisions, ideas, and commitments from user messages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-user-input.sh triggered"

# Get user input from environment
USER_INPUT="${CLAUDE_USER_PROMPT:-}"

if [[ -z "$USER_INPUT" ]]; then
    debug_log "No user input to analyze"
    exit 0
fi

# Log for diagnostics
debug_log "User input length: ${#USER_INPUT}"

# ============================================================================
# Decision Detection in User Input
# ============================================================================

if is_enabled "decisions"; then
    DECISION_PATTERNS=(
        "let's use "
        "let's go with "
        "I want to use "
        "we should use "
        "I've decided "
        "I decided "
        "the decision is "
        "I'm choosing "
        "I choose "
        "go with "
        "prefer "
        "instead of "
    )

    for pattern in "${DECISION_PATTERNS[@]}"; do
        if echo "$USER_INPUT" | grep -qi "$pattern"; then
            debug_log "Found user decision pattern: $pattern"

            # Extract context around the pattern
            CONTEXT=$(echo "$USER_INPUT" | grep -i "$pattern" | head -3)

            if [[ -n "$CONTEXT" && ${#CONTEXT} -gt 20 ]]; then
                # Check for duplicates
                DB=$(ensure_db)
                PROJECT=$(get_project_name)
                TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

                SIMILAR=$(sqlite3 "$DB" "
                    SELECT COUNT(*)
                    FROM decisions
                    WHERE project = '$PROJECT'
                      AND title LIKE '%$(echo "$TITLE" | cut -c1-30 | sed "s/'/''/g")%'
                      AND created_at > datetime('now', '-1 hour')
                " 2>/dev/null || echo "0")

                if [[ "$SIMILAR" -eq 0 ]]; then
                    SESSION_ID=$(get_current_session_id)
                    DECISION_ID=$(get_next_id "decisions" "D")
                    ESCAPED_TITLE=$(sql_escape "$TITLE")
                    ESCAPED_CONTEXT=$(sql_escape "$CONTEXT")

                    db_exec "INSERT INTO decisions (
                        id, title, description, category,
                        project, source_session_id, source_context, status
                    ) VALUES (
                        '$DECISION_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', 'user-decision',
                        '$PROJECT', '$SESSION_ID', 'user-input', 'active'
                    )"

                    activity_log "decision" "User decision: $TITLE" "decisions" "$DECISION_ID" "$PROJECT" "{\"source\":\"user-input\"}"
                    debug_log "Created user decision $DECISION_ID: $TITLE"

                    # Vault sync for user decisions
                    if is_enabled "vault"; then
                        VAULT_PATH=$(check_vault)
                        if [[ -n "$VAULT_PATH" ]]; then
                            WORKFLOW_FOLDER=$(get_workflow_folder)
                            ensure_vault_structure

                            DATE=$(get_date)
                            SLUG=$(slugify "$TITLE")
                            FILENAME="${DATE}-${SLUG}.md"
                            FILE_PATH="$WORKFLOW_FOLDER/decisions/$FILENAME"

                            RELATED=""
                            SESSION_LINKS=$(get_todays_session_links)
                            if [[ -n "$SESSION_LINKS" ]]; then
                                RELATED="$SESSION_LINKS"
                            fi

                            EXTRA="decision_id: \"$DECISION_ID\"
category: \"user-decision\"
project: \"$PROJECT\"
source: \"user-input\"
status: active"

                            {
                                create_vault_frontmatter "$TITLE" "User decision in $PROJECT" "decision, $PROJECT, user-decision" "$RELATED" "$EXTRA"
                                echo ""
                                echo "# $TITLE"
                                echo ""
                                echo "| Field | Value |"
                                echo "|-------|-------|"
                                echo "| ID | $DECISION_ID |"
                                echo "| Date | $(get_datetime) |"
                                echo "| Category | User Decision |"
                                echo "| Project | $PROJECT |"
                                echo "| Source | User Input |"
                                echo ""
                                echo "## Decision"
                                echo ""
                                echo "$CONTEXT"
                                echo ""
                            } > "$FILE_PATH"

                            db_exec "UPDATE decisions SET vault_note_path = '$FILE_PATH' WHERE id = '$DECISION_ID'"
                            debug_log "Created user decision vault note: $FILE_PATH"
                        fi
                    fi
                fi
            fi
            break
        fi
    done
fi

# ============================================================================
# Idea Detection in User Input
# ============================================================================

if is_enabled "ideas"; then
    IDEA_PATTERNS=(
        "what if "
        "how about "
        "we could "
        "maybe we should "
        "I'm thinking "
        "idea: "
        "thought: "
        "consider "
        "wouldn't it be "
        "can we "
        "could we "
    )

    for pattern in "${IDEA_PATTERNS[@]}"; do
        if echo "$USER_INPUT" | grep -qi "$pattern"; then
            debug_log "Found user idea pattern: $pattern"

            CONTEXT=$(echo "$USER_INPUT" | grep -i "$pattern" | head -3)

            if [[ -n "$CONTEXT" && ${#CONTEXT} -gt 15 ]]; then
                DB=$(ensure_db)
                PROJECT=$(get_project_name)
                TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

                SIMILAR=$(sqlite3 "$DB" "
                    SELECT COUNT(*)
                    FROM ideas
                    WHERE project = '$PROJECT'
                      AND title LIKE '%$(echo "$TITLE" | cut -c1-30 | sed "s/'/''/g")%'
                      AND created_at > datetime('now', '-30 minutes')
                " 2>/dev/null || echo "0")

                if [[ "$SIMILAR" -eq 0 ]]; then
                    SESSION_ID=$(get_current_session_id)
                    IDEA_ID=$(get_next_id "ideas" "I")
                    ESCAPED_TITLE=$(sql_escape "$TITLE")
                    ESCAPED_CONTEXT=$(sql_escape "$CONTEXT")

                    db_exec "INSERT INTO ideas (
                        id, title, description, category,
                        project, source_session_id, status
                    ) VALUES (
                        '$IDEA_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', 'user-idea',
                        '$PROJECT', '$SESSION_ID', 'inbox'
                    )"

                    activity_log "idea" "User idea: $TITLE" "ideas" "$IDEA_ID" "$PROJECT" "{\"source\":\"user-input\"}"
                    debug_log "Created user idea $IDEA_ID: $TITLE"

                    # Vault sync for user ideas
                    if is_enabled "vault"; then
                        VAULT_PATH=$(check_vault)
                        if [[ -n "$VAULT_PATH" ]]; then
                            WORKFLOW_FOLDER=$(get_workflow_folder)
                            ensure_vault_structure
                            ensure_dir "$WORKFLOW_FOLDER/ideas"

                            DATE=$(get_date)
                            SLUG=$(slugify "$TITLE")
                            FILENAME="${IDEA_ID}-${SLUG}.md"
                            FILE_PATH="$WORKFLOW_FOLDER/ideas/$FILENAME"

                            EXTRA="idea_id: \"$IDEA_ID\"
idea_type: \"user-idea\"
project: \"$PROJECT\"
source: \"user-input\"
status: inbox"

                            {
                                create_vault_frontmatter "$TITLE" "User idea in $PROJECT" "idea, user-idea, $PROJECT" "" "$EXTRA"
                                echo ""
                                echo "# $TITLE"
                                echo ""
                                echo "## Context"
                                echo ""
                                echo "$CONTEXT"
                                echo ""
                                echo "## Notes"
                                echo ""
                                echo "<!-- Add your thoughts here -->"
                                echo ""
                            } > "$FILE_PATH"

                            REL_PATH="workflow/ideas/${FILENAME%.md}"
                            db_exec "UPDATE ideas SET vault_note_path = '$REL_PATH' WHERE id = '$IDEA_ID'"
                            debug_log "Created user idea vault note: $FILE_PATH"
                        fi
                    fi
                fi
            fi
            break
        fi
    done
fi

# ============================================================================
# Commitment Detection in User Input
# ============================================================================

if is_enabled "commitments"; then
    COMMITMENT_PATTERNS=(
        "I need to "
        "I have to "
        "I must "
        "I should "
        "I will "
        "I'll "
        "remind me to "
        "don't forget to "
        "make sure to "
        "TODO: "
        "todo: "
    )

    for pattern in "${COMMITMENT_PATTERNS[@]}"; do
        if echo "$USER_INPUT" | grep -qi "$pattern"; then
            debug_log "Found user commitment pattern: $pattern"

            CONTEXT=$(echo "$USER_INPUT" | grep -i "$pattern" | head -3)

            if [[ -n "$CONTEXT" && ${#CONTEXT} -gt 15 ]]; then
                DB=$(ensure_db)
                PROJECT=$(get_project_name)
                TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

                SIMILAR=$(sqlite3 "$DB" "
                    SELECT COUNT(*)
                    FROM commitments
                    WHERE project = '$PROJECT'
                      AND title LIKE '%$(echo "$TITLE" | cut -c1-30 | sed "s/'/''/g")%'
                      AND created_at > datetime('now', '-1 hour')
                " 2>/dev/null || echo "0")

                if [[ "$SIMILAR" -eq 0 ]]; then
                    SESSION_ID=$(get_current_session_id)
                    COMMIT_ID=$(get_next_id "commitments" "C")
                    ESCAPED_TITLE=$(sql_escape "$TITLE")
                    ESCAPED_CONTEXT=$(sql_escape "$CONTEXT")

                    db_exec "INSERT INTO commitments (
                        id, title, description, priority,
                        project, source_session_id, status
                    ) VALUES (
                        '$COMMIT_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', 'normal',
                        '$PROJECT', '$SESSION_ID', 'pending'
                    )"

                    activity_log "commitment" "User commitment: $TITLE" "commitments" "$COMMIT_ID" "$PROJECT" "{\"source\":\"user-input\"}"
                    debug_log "Created user commitment $COMMIT_ID: $TITLE"

                    # Vault sync for user commitments
                    if is_enabled "vault"; then
                        VAULT_PATH=$(check_vault)
                        if [[ -n "$VAULT_PATH" ]]; then
                            WORKFLOW_FOLDER=$(get_workflow_folder)
                            ensure_vault_structure
                            ensure_dir "$WORKFLOW_FOLDER/commitments"

                            DATE=$(get_date)
                            SLUG=$(slugify "$TITLE")
                            FILENAME="${COMMIT_ID}-${SLUG}.md"
                            FILE_PATH="$WORKFLOW_FOLDER/commitments/$FILENAME"

                            RELATED=""
                            SESSION_LINKS=$(get_todays_session_links)
                            if [[ -n "$SESSION_LINKS" ]]; then
                                RELATED="$SESSION_LINKS"
                            fi

                            EXTRA="commitment_id: \"$COMMIT_ID\"
project: \"$PROJECT\"
priority: \"normal\"
source: \"user-input\"
status: pending"

                            {
                                create_vault_frontmatter "$TITLE" "Commitment in $PROJECT" "commitment, $PROJECT, normal" "$RELATED" "$EXTRA"
                                echo ""
                                echo "# $TITLE"
                                echo ""
                                echo "| Field | Value |"
                                echo "|-------|-------|"
                                echo "| ID | $COMMIT_ID |"
                                echo "| Created | $(get_datetime) |"
                                echo "| Project | $PROJECT |"
                                echo "| Priority | Normal |"
                                echo "| Source | User Input |"
                                echo "| Status | Pending |"
                                echo ""
                                echo "## Context"
                                echo ""
                                echo "$CONTEXT"
                                echo ""
                                echo "## Notes"
                                echo ""
                                echo "<!-- Track progress here -->"
                                echo ""
                            } > "$FILE_PATH"

                            db_exec "UPDATE commitments SET vault_note_path = '$FILE_PATH' WHERE id = '$COMMIT_ID'"
                            debug_log "Created user commitment vault note: $FILE_PATH"
                        fi
                    fi
                fi
            fi
            break
        fi
    done
fi

exit 0
