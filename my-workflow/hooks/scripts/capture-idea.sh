#!/bin/bash
# My Workflow Plugin - Extract Ideas from Conversation
# Triggered by PostToolUse events
# Captures ideas, inspirations, and things to explore

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-idea.sh triggered"

# Check if idea capture is enabled (default: true)
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

# ============================================================================
# Idea Detection Patterns
# ============================================================================

IDEA_PATTERNS=(
    # Explicit ideas
    "idea:"
    "what if we"
    "what if I"
    "we could "
    "I could "
    "might be worth"
    "worth exploring"
    "worth investigating"
    "should explore"
    "should investigate"
    "interesting to "
    "would be nice to"
    "would be cool to"
    "would be great to"
    # Future possibilities
    "in the future"
    "later we could"
    "eventually "
    "someday "
    "maybe we should"
    "maybe I should"
    # Inspiration
    "inspired by"
    "reminds me of"
    "similar to how"
    # Research/learning
    "need to learn"
    "should learn"
    "want to learn"
    "curious about"
    "wonder if"
    "wonder how"
    # Improvement ideas
    "could be improved"
    "could be better"
    "room for improvement"
    "opportunity to"
)

# Check for idea patterns
FOUND_IDEA=""
MATCHING_PATTERN=""

for pattern in "${IDEA_PATTERNS[@]}"; do
    if echo "$TOOL_OUTPUT" | grep -Eqi "$pattern"; then
        FOUND_IDEA="true"
        MATCHING_PATTERN="$pattern"
        break
    fi
done

if [[ -z "$FOUND_IDEA" ]]; then
    debug_log "No idea patterns found"
    exit 0
fi

debug_log "Found idea pattern: $MATCHING_PATTERN"

# ============================================================================
# Extract Idea Context
# ============================================================================

# Get the surrounding context (5 lines around match)
CONTEXT=$(echo "$TOOL_OUTPUT" | grep -Ei "$MATCHING_PATTERN" | head -3)

if [[ -z "$CONTEXT" ]]; then
    debug_log "Could not extract context"
    exit 0
fi

# Generate title from the first match
TITLE=$(echo "$CONTEXT" | head -1 | cut -c1-100)
TITLE=$(echo "$TITLE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

# Skip if title is too short
if [[ ${#TITLE} -lt 10 ]]; then
    debug_log "Title too short, skipping"
    exit 0
fi

# ============================================================================
# Determine Idea Type
# ============================================================================

IDEA_TYPE="random"

# Feature ideas
if echo "$CONTEXT" | grep -Eqi "feature|functionality|capability|add|implement|create"; then
    IDEA_TYPE="feature"
# Improvement ideas
elif echo "$CONTEXT" | grep -Eqi "improve|better|optimize|enhance|refactor"; then
    IDEA_TYPE="improvement"
# Experiment ideas
elif echo "$CONTEXT" | grep -Eqi "try|experiment|test|prototype|proof of concept|poc"; then
    IDEA_TYPE="experiment"
# Research ideas
elif echo "$CONTEXT" | grep -Eqi "research|investigate|study|learn|understand"; then
    IDEA_TYPE="research"
# Learning ideas
elif echo "$CONTEXT" | grep -Eqi "learn|tutorial|course|documentation"; then
    IDEA_TYPE="learning"
fi

# ============================================================================
# Determine Category
# ============================================================================

CATEGORY=""

if echo "$CONTEXT" | grep -Eqi "architecture|design|pattern|structure"; then
    CATEGORY="architecture"
elif echo "$CONTEXT" | grep -Eqi "ui|ux|interface|user experience|design"; then
    CATEGORY="ux"
elif echo "$CONTEXT" | grep -Eqi "performance|speed|optimization|fast"; then
    CATEGORY="performance"
elif echo "$CONTEXT" | grep -Eqi "tool|tooling|developer experience|dx"; then
    CATEGORY="tooling"
elif echo "$CONTEXT" | grep -Eqi "test|testing|quality|qa"; then
    CATEGORY="testing"
elif echo "$CONTEXT" | grep -Eqi "security|auth|permission"; then
    CATEGORY="security"
fi

# ============================================================================
# Check for Duplicates
# ============================================================================

PROJECT=$(get_project_name)
ESCAPED_TITLE=$(sql_escape "$TITLE")

# Check for similar ideas in last 24 hours
SIMILAR=$(sqlite3 "$DB" "
    SELECT COUNT(*)
    FROM ideas
    WHERE title LIKE '%$(echo "$TITLE" | cut -c1-30 | sed "s/'/''/g")%'
      AND created_at > datetime('now', '-24 hours')
" 2>/dev/null || echo "0")

if [[ "$SIMILAR" -gt 0 ]]; then
    debug_log "Similar idea already exists, skipping"
    exit 0
fi

# ============================================================================
# Create Idea Record
# ============================================================================

SESSION_ID=$(get_current_session_id)
TIMESTAMP=$(get_iso_timestamp)
IDEA_ID=$(get_next_id "ideas" "I")

ESCAPED_CONTEXT=$(sql_escape "$CONTEXT")

db_exec "INSERT INTO ideas (
    id, title, description, idea_type, category,
    project, source_session_id, source_context, status
) VALUES (
    '$IDEA_ID', '$ESCAPED_TITLE', '$ESCAPED_CONTEXT', '$IDEA_TYPE', '$CATEGORY',
    '$PROJECT', '$SESSION_ID', '$ESCAPED_CONTEXT', 'captured'
)"

# Log activity
activity_log "idea" "Captured idea: $TITLE" "ideas" "$IDEA_ID" "$PROJECT" "{\"type\":\"$IDEA_TYPE\"}"

# Update daily note
update_daily_note_ideas "$IDEA_ID"

debug_log "Created idea $IDEA_ID: $TITLE ($IDEA_TYPE)"

# ============================================================================
# Vault Sync (if enabled)
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_vault_structure

        # Create ideas subfolder if needed
        ensure_dir "$WORKFLOW_FOLDER/ideas"

        DATE=$(get_date)
        SLUG=$(slugify "$TITLE")
        FILENAME="${IDEA_ID}-${SLUG}.md"
        FILE_PATH="$WORKFLOW_FOLDER/ideas/$FILENAME"

        # Build extra frontmatter
        EXTRA="idea_id: \"$IDEA_ID\"
idea_type: \"$IDEA_TYPE\"
category: \"$CATEGORY\"
project: \"$PROJECT\"
priority: medium
effort: unknown
status: captured"

        # Create vault note
        {
            create_vault_frontmatter "$TITLE" "Idea: $IDEA_TYPE" "idea, $IDEA_TYPE, $PROJECT" "" "$EXTRA"
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
            echo "## Related"
            echo ""
            echo "- Session: [[workflow/sessions/$(get_date)-*|Today's sessions]]"
            if [[ -n "$PROJECT" ]]; then
                echo "- Project: $PROJECT"
            fi
        } > "$FILE_PATH"

        # Update database with vault path
        REL_PATH="workflow/ideas/${FILENAME%.md}"
        db_exec "UPDATE ideas SET vault_note_path = '$REL_PATH' WHERE id = '$IDEA_ID'"

        debug_log "Created vault note: $FILE_PATH"
    fi
fi

exit 0
