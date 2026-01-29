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
                fi
            fi
            break
        fi
    done
fi

exit 0
