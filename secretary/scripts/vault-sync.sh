#!/bin/bash
# Secretary Plugin - Vault Note Sync
# Creates/updates Obsidian vault markdown notes from database records
# Called by worker.sh after processing queue items
#
# Uses entity IDs as filenames (D-0001.md) — no AI calls needed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"
source "$PLUGIN_ROOT/hooks/scripts/lib/db.sh"

set +e

# Check vault is enabled
if ! is_enabled "vault"; then
    exit 0
fi

VAULT_PATH=$(check_vault)
if [[ -z "$VAULT_PATH" ]]; then
    exit 0
fi

SEC_FOLDER=$(get_secretary_folder)
ensure_vault_structure

DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    exit 0
fi

debug_log "vault-sync.sh started"

# ============================================================================
# Sync Decisions without vault notes
# ============================================================================

sqlite3 -separator '|' "$DB" "
    SELECT id, title, description, rationale, category, project, created_at
    FROM decisions
    WHERE vault_note_path IS NULL AND status = 'active'
    ORDER BY created_at DESC LIMIT 20
" 2>/dev/null | while IFS='|' read -r id title description rationale category project created; do
    FILE_PATH="$SEC_FOLDER/decisions/${id}.md"

    if [[ -f "$FILE_PATH" ]]; then
        sqlite3 "$DB" "UPDATE decisions SET vault_note_path = 'secretary/decisions/${id}' WHERE id = '$id'" 2>/dev/null
        continue
    fi

    {
        create_vault_frontmatter "$title" "$description" "decision, $category, ${project:-global}" "" "category: \"$category\"
project: \"${project:-global}\"
decision_id: \"$id\"
status: \"active\"" "$created"
        echo ""
        echo "# $title"
        echo ""
        echo "**ID:** $id | **Category:** $category | **Project:** ${project:-global}"
        echo ""
        if [[ -n "$description" && "$description" != "$title" ]]; then
            echo "## Description"
            echo ""
            echo "$description"
            echo ""
        fi
        if [[ -n "$rationale" ]]; then
            echo "## Rationale"
            echo ""
            echo "$rationale"
            echo ""
        fi
    } > "$FILE_PATH"

    sqlite3 "$DB" "UPDATE decisions SET vault_note_path = 'secretary/decisions/${id}' WHERE id = '$id'" 2>/dev/null
    debug_log "Created vault note: $FILE_PATH"
done

# ============================================================================
# Sync Commitments without vault notes
# ============================================================================

sqlite3 -separator '|' "$DB" "
    SELECT id, title, description, priority, due_date, due_type, status, project, created_at
    FROM commitments
    WHERE vault_note_path IS NULL
    ORDER BY created_at DESC LIMIT 20
" 2>/dev/null | while IFS='|' read -r id title description priority due_date due_type status project created; do
    FILE_PATH="$SEC_FOLDER/commitments/${id}.md"

    if [[ -f "$FILE_PATH" ]]; then
        sqlite3 "$DB" "UPDATE commitments SET vault_note_path = 'secretary/commitments/${id}' WHERE id = '$id'" 2>/dev/null
        continue
    fi

    {
        create_vault_frontmatter "$title" "$description" "commitment, $priority, ${project:-global}" "" "priority: \"$priority\"
due_date: \"${due_date:-unset}\"
due_type: \"${due_type:-unspecified}\"
status: \"$status\"
project: \"${project:-global}\"
commitment_id: \"$id\"" "$created"
        echo ""
        echo "# $title"
        echo ""
        echo "**ID:** $id | **Priority:** $priority | **Status:** $status"
        [[ -n "$due_date" ]] && echo "**Due:** $due_date ($due_type)"
        echo "**Project:** ${project:-global}"
        echo ""
        if [[ -n "$description" ]]; then
            echo "## Details"
            echo ""
            echo "$description"
            echo ""
        fi
        echo "## Progress"
        echo ""
        echo "<!-- Track progress here -->"
        echo ""
    } > "$FILE_PATH"

    sqlite3 "$DB" "UPDATE commitments SET vault_note_path = 'secretary/commitments/${id}' WHERE id = '$id'" 2>/dev/null
    debug_log "Created vault note: $FILE_PATH"
done

# ============================================================================
# Sync Ideas without vault notes
# ============================================================================

sqlite3 -separator '|' "$DB" "
    SELECT id, title, description, idea_type, priority, effort, potential_impact, project, created_at
    FROM ideas
    WHERE vault_note_path IS NULL
    ORDER BY created_at DESC LIMIT 20
" 2>/dev/null | while IFS='|' read -r id title description type priority effort impact project created; do
    FILE_PATH="$SEC_FOLDER/ideas/${id}.md"

    if [[ -f "$FILE_PATH" ]]; then
        sqlite3 "$DB" "UPDATE ideas SET vault_note_path = 'secretary/ideas/${id}' WHERE id = '$id'" 2>/dev/null
        continue
    fi

    {
        create_vault_frontmatter "$title" "$description" "idea, $type, ${project:-global}" "" "idea_type: \"$type\"
priority: \"$priority\"
effort: \"${effort:-unknown}\"
impact: \"${impact:-unknown}\"
project: \"${project:-global}\"
idea_id: \"$id\"" "$created"
        echo ""
        echo "# $title"
        echo ""
        echo "**ID:** $id | **Type:** $type | **Priority:** $priority"
        [[ -n "$effort" ]] && echo "**Effort:** $effort | **Impact:** ${impact:-unknown}"
        echo "**Project:** ${project:-global}"
        echo ""
        if [[ -n "$description" ]]; then
            echo "## Description"
            echo ""
            echo "$description"
            echo ""
        fi
        echo "## Notes"
        echo ""
        echo "<!-- Add exploration notes here -->"
        echo ""
    } > "$FILE_PATH"

    sqlite3 "$DB" "UPDATE ideas SET vault_note_path = 'secretary/ideas/${id}' WHERE id = '$id'" 2>/dev/null
    debug_log "Created vault note: $FILE_PATH"
done

# ============================================================================
# Sync Daily Notes
# ============================================================================

TODAY=$(get_date)
DAILY_FILE="$SEC_FOLDER/daily/${TODAY}.md"

if [[ ! -f "$DAILY_FILE" ]]; then
    DAY_OF_WEEK=$(date +%A)
    mkdir -p "$(dirname "$DAILY_FILE")"

    {
        echo "---"
        echo "title: \"Daily Note: $TODAY\""
        echo "tags: [\"daily\", \"secretary\"]"
        echo "created: $TODAY"
        echo "updated: $TODAY"
        echo "date: \"$TODAY\""
        echo "day_of_week: \"$DAY_OF_WEEK\""
        echo "---"
        echo ""
        echo "# $TODAY ($DAY_OF_WEEK)"
        echo ""
        echo "## Sessions"
        echo ""
        echo "## Work Log"
        echo ""
        echo "## Decisions"
        echo ""
        echo "## Ideas"
        echo ""
        echo "## Commitments"
        echo ""
        echo "## Reflections"
        echo ""
    } > "$DAILY_FILE"

    debug_log "Created daily vault note: $DAILY_FILE"
fi

# ============================================================================
# Update vault index
# ============================================================================

INDEX_FILE="$SEC_FOLDER/index.md"

DECISION_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM decisions WHERE status = 'active'" 2>/dev/null || echo "0")
COMMITMENT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM commitments WHERE status IN ('pending','in_progress')" 2>/dev/null || echo "0")
IDEA_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ideas WHERE status = 'captured'" 2>/dev/null || echo "0")
GOAL_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM goals WHERE status = 'active'" 2>/dev/null || echo "0")

{
    echo "---"
    echo "title: \"Secretary Dashboard\""
    echo "tags: [\"secretary\", \"index\"]"
    echo "updated: $(get_date)"
    echo "---"
    echo ""
    echo "# Secretary Dashboard"
    echo ""
    echo "| Section | Count | Link |"
    echo "|---------|-------|------|"
    echo "| Active Decisions | $DECISION_COUNT | [[secretary/decisions/]] |"
    echo "| Pending Commitments | $COMMITMENT_COUNT | [[secretary/commitments/]] |"
    echo "| Ideas Inbox | $IDEA_COUNT | [[secretary/ideas/]] |"
    echo "| Active Goals | $GOAL_COUNT | [[secretary/goals/]] |"
    echo ""
    echo "## Quick Links"
    echo ""
    echo "- [[secretary/daily/${TODAY}|Today's Note]]"
    echo "- [[secretary/sessions/|Sessions]]"
    echo "- [[secretary/reviews/|Reviews]]"
    echo "- [[secretary/patterns/|Patterns]]"
    echo ""
} > "$INDEX_FILE"

debug_log "vault-sync.sh completed"
