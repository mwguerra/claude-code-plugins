#!/bin/bash
# My Workflow Plugin - Capture User Input
# Triggered by UserPromptSubmit events
# Captures decisions, ideas, and commitments from user messages
# Supports multiple languages via pattern matching + AI fallback

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"
source "$SCRIPT_DIR/ai-analyzer.sh"

debug_log "capture-user-input.sh triggered"

# Get user input from environment
USER_INPUT="${CLAUDE_USER_PROMPT:-}"

if [[ -z "$USER_INPUT" ]]; then
    debug_log "No user input to analyze"
    exit 0
fi

# Log for diagnostics
debug_log "User input length: ${#USER_INPUT}"

# Skip very short inputs
if [[ ${#USER_INPUT} -lt 15 ]]; then
    debug_log "Input too short to analyze"
    exit 0
fi

# ============================================================================
# Multi-language Pattern Arrays
# ============================================================================

DECISION_PATTERNS=(
    # English
    "let's use " "let's go with " "I want to use " "we should use "
    "I've decided " "I decided " "the decision is " "I'm choosing "
    "I choose " "go with " "prefer " "instead of " "opted for "
    # Portuguese BR
    "vamos usar " "vou usar " "decidi " "decidimos " "escolhi "
    "a decisão é " "optei por " "resolvi " "definimos " "prefiro "
    # Spanish
    "vamos a usar " "decidí " "decidimos " "elegí " "la decisión es "
    "opté por " "prefiero "
)

IDEA_PATTERNS=(
    # English
    "what if " "how about " "we could " "maybe we should " "I'm thinking "
    "idea: " "thought: " "consider " "wouldn't it be " "can we " "could we "
    "might be worth " "should explore " "interesting to "
    # Portuguese BR
    "e se " "que tal " "podemos " "poderíamos " "estou pensando "
    "ideia: " "considere " "seria interessante " "vale a pena "
    "deveríamos explorar " "uma ideia "
    # Spanish
    "qué tal si " "podríamos " "estoy pensando " "considera "
    "sería interesante " "vale la pena "
)

COMMITMENT_PATTERNS=(
    # English
    "I need to " "I have to " "I must " "I should " "I will " "I'll "
    "remind me to " "don't forget to " "make sure to " "TODO: " "todo: "
    "need to remember " "gotta "
    # Portuguese BR
    "preciso " "tenho que " "devo " "vou " "não esquecer " "lembrar de "
    "fazer: " "pendente: " "não posso esquecer " "tenho de "
    # Spanish
    "necesito " "tengo que " "debo " "voy a " "no olvidar "
    "recordar " "pendiente: "
)

# ============================================================================
# Helper: Create Decision from Analysis
# ============================================================================

create_decision_from_analysis() {
    local title="$1"
    local context="$2"
    local category="${3:-user-decision}"
    local source_type="${4:-pattern}"

    DB=$(ensure_db)
    PROJECT=$(get_project_name)

    # Check for duplicates
    local similar
    similar=$(sqlite3 "$DB" "
        SELECT COUNT(*)
        FROM decisions
        WHERE project = '$PROJECT'
          AND title LIKE '%$(echo "$title" | cut -c1-30 | sed "s/'/''/g")%'
          AND created_at > datetime('now', '-1 hour')
    " 2>/dev/null || echo "0")

    if [[ "$similar" -gt 0 ]]; then
        debug_log "Similar decision already exists, skipping"
        return 0
    fi

    SESSION_ID=$(get_current_session_id)
    DECISION_ID=$(get_next_id "decisions" "D")
    ESCAPED_TITLE=$(sql_escape "$title")
    ESCAPED_CONTEXT=$(sql_escape "$context")

    db_exec "INSERT INTO decisions (
        id, title, description, category,
        project, source_session_id, source_context, status
    ) VALUES (
        '$DECISION_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', '$category',
        '$PROJECT', '$SESSION_ID', 'user-input-$source_type', 'active'
    )"

    activity_log "decision" "User decision: $title" "decisions" "$DECISION_ID" "$PROJECT" "{\"source\":\"user-input\",\"method\":\"$source_type\"}"
    debug_log "Created user decision $DECISION_ID: $title (via $source_type)"

    # Vault sync
    if is_enabled "vault"; then
        VAULT_PATH=$(check_vault)
        if [[ -n "$VAULT_PATH" ]]; then
            WORKFLOW_FOLDER=$(get_workflow_folder)
            ensure_vault_structure

            DATE=$(get_date)
            SLUG=$(slugify "$title")
            FILENAME="${DATE}-${SLUG}.md"
            FILE_PATH="$WORKFLOW_FOLDER/decisions/$FILENAME"

            RELATED=""
            SESSION_LINKS=$(get_todays_session_links)
            if [[ -n "$SESSION_LINKS" ]]; then
                RELATED="$SESSION_LINKS"
            fi

            EXTRA="decision_id: \"$DECISION_ID\"
category: \"$category\"
project: \"$PROJECT\"
source: \"user-input\"
analysis_method: \"$source_type\"
status: active"

            {
                create_vault_frontmatter "$title" "User decision in $PROJECT" "decision, $PROJECT, $category" "$RELATED" "$EXTRA"
                echo ""
                echo "# $title"
                echo ""
                echo "| Field | Value |"
                echo "|-------|-------|"
                echo "| ID | $DECISION_ID |"
                echo "| Date | $(get_datetime) |"
                echo "| Category | $category |"
                echo "| Project | $PROJECT |"
                echo "| Source | User Input |"
                echo "| Analysis | $source_type |"
                echo ""
                echo "## Decision"
                echo ""
                echo "$context"
                echo ""
            } > "$FILE_PATH"

            db_exec "UPDATE decisions SET vault_note_path = '$FILE_PATH' WHERE id = '$DECISION_ID'"
            debug_log "Created user decision vault note: $FILE_PATH"
        fi
    fi
}

# ============================================================================
# Helper: Create Idea from Analysis
# ============================================================================

create_idea_from_analysis() {
    local title="$1"
    local context="$2"
    local idea_type="${3:-user-idea}"
    local source_type="${4:-pattern}"

    DB=$(ensure_db)
    PROJECT=$(get_project_name)

    # Check for duplicates
    local similar
    similar=$(sqlite3 "$DB" "
        SELECT COUNT(*)
        FROM ideas
        WHERE project = '$PROJECT'
          AND title LIKE '%$(echo "$title" | cut -c1-30 | sed "s/'/''/g")%'
          AND created_at > datetime('now', '-30 minutes')
    " 2>/dev/null || echo "0")

    if [[ "$similar" -gt 0 ]]; then
        debug_log "Similar idea already exists, skipping"
        return 0
    fi

    SESSION_ID=$(get_current_session_id)
    IDEA_ID=$(get_next_id "ideas" "I")
    ESCAPED_TITLE=$(sql_escape "$title")
    ESCAPED_CONTEXT=$(sql_escape "$context")

    db_exec "INSERT INTO ideas (
        id, title, description, category,
        project, source_session_id, status
    ) VALUES (
        '$IDEA_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', '$idea_type',
        '$PROJECT', '$SESSION_ID', 'inbox'
    )"

    activity_log "idea" "User idea: $title" "ideas" "$IDEA_ID" "$PROJECT" "{\"source\":\"user-input\",\"method\":\"$source_type\"}"
    debug_log "Created user idea $IDEA_ID: $title (via $source_type)"

    # Vault sync
    if is_enabled "vault"; then
        VAULT_PATH=$(check_vault)
        if [[ -n "$VAULT_PATH" ]]; then
            WORKFLOW_FOLDER=$(get_workflow_folder)
            ensure_vault_structure
            ensure_dir "$WORKFLOW_FOLDER/ideas"

            DATE=$(get_date)
            SLUG=$(slugify "$title")
            FILENAME="${IDEA_ID}-${SLUG}.md"
            FILE_PATH="$WORKFLOW_FOLDER/ideas/$FILENAME"

            EXTRA="idea_id: \"$IDEA_ID\"
idea_type: \"$idea_type\"
project: \"$PROJECT\"
source: \"user-input\"
analysis_method: \"$source_type\"
status: inbox"

            {
                create_vault_frontmatter "$title" "User idea in $PROJECT" "idea, $idea_type, $PROJECT" "" "$EXTRA"
                echo ""
                echo "# $title"
                echo ""
                echo "## Context"
                echo ""
                echo "$context"
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
}

# ============================================================================
# Helper: Create Commitment from Analysis
# ============================================================================

create_commitment_from_analysis() {
    local title="$1"
    local context="$2"
    local priority="${3:-normal}"
    local source_type="${4:-pattern}"

    DB=$(ensure_db)
    PROJECT=$(get_project_name)

    # Check for duplicates
    local similar
    similar=$(sqlite3 "$DB" "
        SELECT COUNT(*)
        FROM commitments
        WHERE project = '$PROJECT'
          AND title LIKE '%$(echo "$title" | cut -c1-30 | sed "s/'/''/g")%'
          AND created_at > datetime('now', '-1 hour')
    " 2>/dev/null || echo "0")

    if [[ "$similar" -gt 0 ]]; then
        debug_log "Similar commitment already exists, skipping"
        return 0
    fi

    SESSION_ID=$(get_current_session_id)
    COMMIT_ID=$(get_next_id "commitments" "C")
    ESCAPED_TITLE=$(sql_escape "$title")
    ESCAPED_CONTEXT=$(sql_escape "$context")

    db_exec "INSERT INTO commitments (
        id, title, description, priority,
        project, source_session_id, status
    ) VALUES (
        '$COMMIT_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', '$priority',
        '$PROJECT', '$SESSION_ID', 'pending'
    )"

    activity_log "commitment" "User commitment: $title" "commitments" "$COMMIT_ID" "$PROJECT" "{\"source\":\"user-input\",\"method\":\"$source_type\"}"
    debug_log "Created user commitment $COMMIT_ID: $title (via $source_type)"

    # Vault sync
    if is_enabled "vault"; then
        VAULT_PATH=$(check_vault)
        if [[ -n "$VAULT_PATH" ]]; then
            WORKFLOW_FOLDER=$(get_workflow_folder)
            ensure_vault_structure
            ensure_dir "$WORKFLOW_FOLDER/commitments"

            DATE=$(get_date)
            SLUG=$(slugify "$title")
            FILENAME="${COMMIT_ID}-${SLUG}.md"
            FILE_PATH="$WORKFLOW_FOLDER/commitments/$FILENAME"

            RELATED=""
            SESSION_LINKS=$(get_todays_session_links)
            if [[ -n "$SESSION_LINKS" ]]; then
                RELATED="$SESSION_LINKS"
            fi

            EXTRA="commitment_id: \"$COMMIT_ID\"
project: \"$PROJECT\"
priority: \"$priority\"
source: \"user-input\"
analysis_method: \"$source_type\"
status: pending"

            {
                create_vault_frontmatter "$title" "Commitment in $PROJECT" "commitment, $PROJECT, $priority" "$RELATED" "$EXTRA"
                echo ""
                echo "# $title"
                echo ""
                echo "| Field | Value |"
                echo "|-------|-------|"
                echo "| ID | $COMMIT_ID |"
                echo "| Created | $(get_datetime) |"
                echo "| Project | $PROJECT |"
                echo "| Priority | $priority |"
                echo "| Source | User Input |"
                echo "| Analysis | $source_type |"
                echo "| Status | Pending |"
                echo ""
                echo "## Context"
                echo ""
                echo "$context"
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
}

# ============================================================================
# Pattern-based Detection (Fast Path)
# ============================================================================

FOUND_PATTERN=""

# Try decision patterns
if is_enabled "decisions"; then
    for pattern in "${DECISION_PATTERNS[@]}"; do
        if echo "$USER_INPUT" | grep -qi "$pattern"; then
            debug_log "Found user decision pattern: $pattern"
            CONTEXT=$(echo "$USER_INPUT" | grep -i "$pattern" | head -3)
            if [[ -n "$CONTEXT" && ${#CONTEXT} -gt 20 ]]; then
                TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                create_decision_from_analysis "$TITLE" "$CONTEXT" "user-decision" "pattern"
                FOUND_PATTERN="decision"
            fi
            break
        fi
    done
fi

# Try idea patterns (if no decision found)
if [[ -z "$FOUND_PATTERN" ]] && is_enabled "ideas"; then
    for pattern in "${IDEA_PATTERNS[@]}"; do
        if echo "$USER_INPUT" | grep -qi "$pattern"; then
            debug_log "Found user idea pattern: $pattern"
            CONTEXT=$(echo "$USER_INPUT" | grep -i "$pattern" | head -3)
            if [[ -n "$CONTEXT" && ${#CONTEXT} -gt 15 ]]; then
                TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                create_idea_from_analysis "$TITLE" "$CONTEXT" "user-idea" "pattern"
                FOUND_PATTERN="idea"
            fi
            break
        fi
    done
fi

# Try commitment patterns (if nothing else found)
if [[ -z "$FOUND_PATTERN" ]] && is_enabled "commitments"; then
    for pattern in "${COMMITMENT_PATTERNS[@]}"; do
        if echo "$USER_INPUT" | grep -qi "$pattern"; then
            debug_log "Found user commitment pattern: $pattern"
            CONTEXT=$(echo "$USER_INPUT" | grep -i "$pattern" | head -3)
            if [[ -n "$CONTEXT" && ${#CONTEXT} -gt 15 ]]; then
                TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                create_commitment_from_analysis "$TITLE" "$CONTEXT" "normal" "pattern"
                FOUND_PATTERN="commitment"
            fi
            break
        fi
    done
fi

# ============================================================================
# AI Fallback Analysis (When Patterns Don't Match)
# ============================================================================

if [[ -z "$FOUND_PATTERN" ]] && ai_enabled; then
    debug_log "No patterns matched, trying AI analysis"

    # Run AI analysis
    AI_RESULT=$(analyze_content "$USER_INPUT" "auto")

    if [[ -n "$AI_RESULT" ]]; then
        FOUND=$(echo "$AI_RESULT" | jq -r '.found // false')
        TYPE=$(echo "$AI_RESULT" | jq -r '.type // "none"')

        if [[ "$FOUND" == "true" && "$TYPE" != "none" && "$TYPE" != "general" ]]; then
            TITLE=$(echo "$AI_RESULT" | jq -r '.title // empty')
            CATEGORY=$(echo "$AI_RESULT" | jq -r '.category // "general"')
            SUMMARY=$(echo "$AI_RESULT" | jq -r '.summary // empty')

            # Use summary as context if available, otherwise use input
            if [[ -n "$SUMMARY" ]]; then
                CONTEXT="$SUMMARY"
            else
                CONTEXT=$(echo "$USER_INPUT" | head -5)
            fi

            debug_log "AI found $TYPE: $TITLE"

            case "$TYPE" in
                decision)
                    if is_enabled "decisions"; then
                        create_decision_from_analysis "$TITLE" "$CONTEXT" "$CATEGORY" "ai"
                    fi
                    ;;
                idea)
                    if is_enabled "ideas"; then
                        IDEA_TYPE=$(echo "$AI_RESULT" | jq -r '.type // "exploration"')
                        create_idea_from_analysis "$TITLE" "$CONTEXT" "$IDEA_TYPE" "ai"
                    fi
                    ;;
                commitment)
                    if is_enabled "commitments"; then
                        PRIORITY=$(echo "$AI_RESULT" | jq -r '.priority // "normal"')
                        create_commitment_from_analysis "$TITLE" "$CONTEXT" "$PRIORITY" "ai"
                    fi
                    ;;
            esac
        else
            debug_log "AI analysis found no trackable content"
        fi
    fi
fi

exit 0
