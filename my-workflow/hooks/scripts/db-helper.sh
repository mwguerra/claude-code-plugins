#!/bin/bash
# My Workflow Plugin - Database Helper Layer
# Encapsulates all SQLite operations with typed functions
# Source this file after hook-utils.sh

# Ensure hook-utils.sh is loaded
if [[ -z "$DB_PATH" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/hook-utils.sh"
fi

# =============================================================================
# Core Database Functions
# =============================================================================

# Execute SQL without expecting output
# Usage: db_exec "INSERT INTO ..."
db_exec() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "$sql" 2>/dev/null
}

# Execute SQL and return JSON output
# Usage: db_query "SELECT * FROM ..."
db_query_json() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 -json "$db" "$sql" 2>/dev/null
}

# Execute SQL and return plain text output
# Usage: db_query_plain "SELECT id FROM ..."
db_query_plain() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "$sql" 2>/dev/null
}

# SQL-escape a string (handle single quotes)
# Usage: escaped=$(db_escape "$text")
db_escape() {
    local text="$1"
    echo "${text//\'/\'\'}"
}

# Get next ID for a table with prefix (D-0001, I-0001, C-0001)
# Usage: id=$(db_get_next_id "decisions" "D")
db_get_next_id() {
    local table="$1"
    local prefix="$2"
    local db
    db=$(ensure_db) || return 1

    local max_num
    max_num=$(sqlite3 "$db" "SELECT MAX(CAST(SUBSTR(id, ${#prefix}+2) AS INTEGER)) FROM $table WHERE id LIKE '$prefix-%'" 2>/dev/null)

    if [[ -z "$max_num" || "$max_num" == "null" ]]; then
        max_num=0
    fi

    printf "%s-%04d" "$prefix" $((max_num + 1))
}

# =============================================================================
# Session Operations
# =============================================================================

# Create a new session
# Usage: db_create_session "session_id" "project" "directory" "branch"
db_create_session() {
    local session_id="$1"
    local project="$2"
    local directory="$3"
    local branch="${4:-}"
    local timestamp=$(get_iso_timestamp)

    local escaped_project=$(db_escape "$project")
    local escaped_dir=$(db_escape "$directory")
    local escaped_branch=$(db_escape "$branch")

    db_exec "INSERT INTO sessions (id, project, directory, branch, started_at, status, created_at, updated_at)
             VALUES ('$session_id', '$escaped_project', '$escaped_dir', '$escaped_branch', '$timestamp', 'active', '$timestamp', '$timestamp')"

    # Set as current session
    db_exec "UPDATE state SET current_session_id = '$session_id', updated_at = '$timestamp' WHERE id = 1"

    echo "$session_id"
}

# Close a session with summary and status
# Usage: db_close_session "session_id" "summary" "completed|interrupted"
db_close_session() {
    local session_id="$1"
    local summary="$2"
    local status="${3:-completed}"
    local timestamp=$(get_iso_timestamp)

    local escaped_summary=$(db_escape "$summary")

    # Calculate duration
    local start_time=$(db_query_plain "SELECT started_at FROM sessions WHERE id = '$session_id'")
    local duration=0
    if [[ -n "$start_time" ]]; then
        local start_epoch=$(date_to_epoch "$start_time")
        local end_epoch=$(date +%s)
        if [[ "$start_epoch" -gt 0 ]]; then
            duration=$((end_epoch - start_epoch))
        fi
    fi

    db_exec "UPDATE sessions SET
             ended_at = '$timestamp',
             duration_seconds = $duration,
             summary = '$escaped_summary',
             status = '$status',
             updated_at = '$timestamp'
             WHERE id = '$session_id'"

    # Clear current session if this was it
    local current=$(db_query_plain "SELECT current_session_id FROM state WHERE id = 1")
    if [[ "$current" == "$session_id" ]]; then
        db_exec "UPDATE state SET current_session_id = NULL, updated_at = '$timestamp' WHERE id = 1"
    fi
}

# Get current session ID
# Usage: session_id=$(db_get_current_session_id)
db_get_current_session_id() {
    db_query_plain "SELECT current_session_id FROM state WHERE id = 1"
}

# Get a session by ID (returns JSON)
# Usage: db_get_session "session_id"
db_get_session() {
    local session_id="$1"
    db_query_json "SELECT * FROM sessions WHERE id = '$session_id'"
}

# Get all active sessions for a project (returns JSON array)
# Usage: db_get_active_sessions "project_name"
db_get_active_sessions() {
    local project="$1"
    local escaped_project=$(db_escape "$project")
    db_query_json "SELECT id, project, directory, started_at FROM sessions WHERE project = '$escaped_project' AND status = 'active'"
}

# Get all active sessions with directory info
# Usage: db_get_all_active_sessions
db_get_all_active_sessions() {
    db_query_json "SELECT id, project, directory, started_at FROM sessions WHERE status = 'active'"
}

# =============================================================================
# Decision Operations
# =============================================================================

# Insert a new decision
# Returns: decision ID (D-XXXX)
db_insert_decision() {
    local title="$1"
    local description="$2"
    local category="${3:-general}"
    local rationale="${4:-}"
    local session_id="${5:-$(db_get_current_session_id)}"
    local project="${6:-$(get_project_name)}"

    local decision_id=$(db_get_next_id "decisions" "D")
    local timestamp=$(get_iso_timestamp)

    local escaped_title=$(db_escape "$title")
    local escaped_desc=$(db_escape "$description")
    local escaped_rationale=$(db_escape "$rationale")
    local escaped_project=$(db_escape "$project")

    db_exec "INSERT INTO decisions (id, title, description, rationale, category, project, source_session_id, status, created_at, updated_at)
             VALUES ('$decision_id', '$escaped_title', '$escaped_desc', '$escaped_rationale', '$category', '$escaped_project', '$session_id', 'active', '$timestamp', '$timestamp')"

    echo "$decision_id"
}

# Get a decision by ID
db_get_decision() {
    local decision_id="$1"
    db_query_json "SELECT * FROM decisions WHERE id = '$decision_id'"
}

# Update decision with vault note path
db_update_decision_vault_path() {
    local decision_id="$1"
    local vault_path="$2"
    local timestamp=$(get_iso_timestamp)
    db_exec "UPDATE decisions SET vault_note_path = '$vault_path', updated_at = '$timestamp' WHERE id = '$decision_id'"
}

# Get today's decisions
db_get_today_decisions() {
    local today=$(get_date)
    db_query_json "SELECT * FROM decisions WHERE date(created_at) = '$today' ORDER BY created_at DESC"
}

# =============================================================================
# Idea Operations
# =============================================================================

# Insert a new idea
# Returns: idea ID (I-XXXX)
db_insert_idea() {
    local title="$1"
    local description="$2"
    local idea_type="${3:-exploration}"
    local session_id="${4:-$(db_get_current_session_id)}"
    local project="${5:-$(get_project_name)}"

    local idea_id=$(db_get_next_id "ideas" "I")
    local timestamp=$(get_iso_timestamp)

    local escaped_title=$(db_escape "$title")
    local escaped_desc=$(db_escape "$description")
    local escaped_project=$(db_escape "$project")

    db_exec "INSERT INTO ideas (id, title, description, category, project, source_session_id, status, created_at, updated_at)
             VALUES ('$idea_id', '$escaped_title', '$escaped_desc', '$idea_type', '$escaped_project', '$session_id', 'inbox', '$timestamp', '$timestamp')"

    echo "$idea_id"
}

# Get an idea by ID
db_get_idea() {
    local idea_id="$1"
    db_query_json "SELECT * FROM ideas WHERE id = '$idea_id'"
}

# Update idea with vault note path
db_update_idea_vault_path() {
    local idea_id="$1"
    local vault_path="$2"
    local timestamp=$(get_iso_timestamp)
    db_exec "UPDATE ideas SET vault_note_path = '$vault_path', updated_at = '$timestamp' WHERE id = '$idea_id'"
}

# Get today's ideas
db_get_today_ideas() {
    local today=$(get_date)
    db_query_json "SELECT * FROM ideas WHERE date(created_at) = '$today' ORDER BY created_at DESC"
}

# =============================================================================
# Commitment Operations
# =============================================================================

# Insert a new commitment
# Returns: commitment ID (C-XXXX)
db_insert_commitment() {
    local title="$1"
    local description="$2"
    local priority="${3:-medium}"
    local due_type="${4:-unspecified}"
    local session_id="${5:-$(db_get_current_session_id)}"
    local project="${6:-$(get_project_name)}"

    local commitment_id=$(db_get_next_id "commitments" "C")
    local timestamp=$(get_iso_timestamp)

    local escaped_title=$(db_escape "$title")
    local escaped_desc=$(db_escape "$description")
    local escaped_project=$(db_escape "$project")

    db_exec "INSERT INTO commitments (id, title, description, source_type, source_session_id, project, priority, due_type, status, created_at, updated_at)
             VALUES ('$commitment_id', '$escaped_title', '$escaped_desc', 'conversation', '$session_id', '$escaped_project', '$priority', '$due_type', 'pending', '$timestamp', '$timestamp')"

    echo "$commitment_id"
}

# Get a commitment by ID
db_get_commitment() {
    local commitment_id="$1"
    db_query_json "SELECT * FROM commitments WHERE id = '$commitment_id'"
}

# Update commitment with vault note path
db_update_commitment_vault_path() {
    local commitment_id="$1"
    local vault_path="$2"
    local timestamp=$(get_iso_timestamp)
    db_exec "UPDATE commitments SET vault_note_path = '$vault_path', updated_at = '$timestamp' WHERE id = '$commitment_id'"
}

# Get pending commitments
db_get_pending_commitments() {
    db_query_json "SELECT * FROM commitments WHERE status = 'pending' ORDER BY priority DESC, created_at ASC"
}

# =============================================================================
# Duplicate Detection
# =============================================================================

# Check if a similar record exists recently
# Returns: 0 if duplicate exists, 1 if no duplicate
db_check_duplicate() {
    local table="$1"
    local title="$2"
    local hours_back="${3:-1}"
    local project="${4:-$(get_project_name)}"

    # Use first 30 chars for matching
    local title_prefix=$(echo "$title" | cut -c1-30)
    local escaped_prefix=$(db_escape "$title_prefix")
    local escaped_project=$(db_escape "$project")

    local count=$(db_query_plain "SELECT COUNT(*) FROM $table
                                  WHERE project = '$escaped_project'
                                  AND title LIKE '%$escaped_prefix%'
                                  AND created_at > datetime('now', '-$hours_back hour')")

    [[ "$count" -gt 0 ]]
}

# =============================================================================
# Activity Timeline
# =============================================================================

# Log an activity
db_log_activity() {
    local activity_type="$1"
    local title="$2"
    local entity_type="${3:-}"
    local entity_id="${4:-}"
    local project="${5:-$(get_project_name)}"
    local metadata="$6"
    [[ -z "$metadata" ]] && metadata='{}'
    local session_id="${7:-$(db_get_current_session_id)}"

    local timestamp=$(get_iso_timestamp)
    local escaped_title=$(db_escape "$title")
    local escaped_project=$(db_escape "$project")

    db_exec "INSERT INTO activity_timeline (activity_type, title, entity_type, entity_id, project, session_id, details, timestamp)
             VALUES ('$activity_type', '$escaped_title', '$entity_type', '$entity_id', '$escaped_project', '$session_id', '$metadata', '$timestamp')"
}

# =============================================================================
# Daily Note Operations
# =============================================================================

# Ensure a daily note record exists
db_ensure_daily_note() {
    local date="${1:-$(get_date)}"
    local day_of_week=$(date -d "$date" +%A 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%A 2>/dev/null || echo "")

    local exists=$(db_query_plain "SELECT COUNT(*) FROM daily_notes WHERE date = '$date'")

    if [[ "$exists" -eq 0 ]]; then
        local timestamp=$(get_iso_timestamp)
        db_exec "INSERT INTO daily_notes (date, day_of_week, created_at, updated_at)
                 VALUES ('$date', '$day_of_week', '$timestamp', '$timestamp')"
    fi
}

# Add a decision ID to daily note
db_add_daily_decision() {
    local date="${1:-$(get_date)}"
    local decision_id="$2"

    db_ensure_daily_note "$date"

    # Get current decisions list and append
    local current=$(db_query_plain "SELECT COALESCE(new_decisions, '[]') FROM daily_notes WHERE date = '$date'")

    # Handle NULL or empty values
    if [[ -z "$current" || "$current" == "null" ]]; then
        current="[]"
    fi

    # Parse JSON array and add new ID if not present
    if echo "$current" | grep -q "\"$decision_id\""; then
        return 0  # Already present
    fi

    local updated
    if [[ "$current" == "[]" ]]; then
        updated="[\"$decision_id\"]"
    else
        updated=$(echo "$current" | sed "s/\]$/,\"$decision_id\"]/")
    fi

    local timestamp=$(get_iso_timestamp)
    db_exec "UPDATE daily_notes SET new_decisions = '$updated', updated_at = '$timestamp' WHERE date = '$date'"
}

# Add an idea ID to daily note
db_add_daily_idea() {
    local date="${1:-$(get_date)}"
    local idea_id="$2"

    db_ensure_daily_note "$date"

    local current=$(db_query_plain "SELECT COALESCE(new_ideas, '[]') FROM daily_notes WHERE date = '$date'")

    # Handle NULL or empty values
    if [[ -z "$current" || "$current" == "null" ]]; then
        current="[]"
    fi

    if echo "$current" | grep -q "\"$idea_id\""; then
        return 0
    fi

    local updated
    if [[ "$current" == "[]" ]]; then
        updated="[\"$idea_id\"]"
    else
        updated=$(echo "$current" | sed "s/\]$/,\"$idea_id\"]/")
    fi

    local timestamp=$(get_iso_timestamp)
    db_exec "UPDATE daily_notes SET new_ideas = '$updated', updated_at = '$timestamp' WHERE date = '$date'"
}

# Update daily note session count and duration
db_update_daily_session() {
    local date="${1:-$(get_date)}"
    local duration_seconds="${2:-0}"
    local project="${3:-$(get_project_name)}"

    db_ensure_daily_note "$date"

    local timestamp=$(get_iso_timestamp)
    db_exec "UPDATE daily_notes SET
             last_activity_at = '$timestamp',
             sessions_count = COALESCE(sessions_count, 0) + 1,
             total_work_seconds = COALESCE(total_work_seconds, 0) + $duration_seconds,
             updated_at = '$timestamp'
             WHERE date = '$date'"

    # Update projects_worked JSON
    local current=$(db_query_plain "SELECT COALESCE(projects_worked, '{}') FROM daily_notes WHERE date = '$date'")
    local escaped_project=$(db_escape "$project")

    local updated
    if [[ "$current" == "{}" ]]; then
        updated="{\"$escaped_project\":$duration_seconds}"
    elif echo "$current" | grep -q "\"$escaped_project\""; then
        # Project exists, would need jq to properly increment - simplified for now
        updated="$current"
    else
        updated=$(echo "$current" | sed "s/}$/,\"$escaped_project\":$duration_seconds}/")
    fi

    db_exec "UPDATE daily_notes SET projects_worked = '$updated' WHERE date = '$date'"
}

# =============================================================================
# State Management
# =============================================================================

# Get a state value
db_get_state() {
    local field="$1"
    db_query_plain "SELECT $field FROM state WHERE id = 1"
}

# Set a state value
db_set_state() {
    local field="$1"
    local value="$2"
    local timestamp=$(get_iso_timestamp)
    local escaped_value=$(db_escape "$value")
    db_exec "UPDATE state SET $field = '$escaped_value', updated_at = '$timestamp' WHERE id = 1"
}

# =============================================================================
# Export Functions
# =============================================================================

export -f db_exec db_query_json db_query_plain db_escape db_get_next_id
export -f db_create_session db_close_session db_get_current_session_id db_get_session
export -f db_get_active_sessions db_get_all_active_sessions
export -f db_insert_decision db_get_decision db_update_decision_vault_path db_get_today_decisions
export -f db_insert_idea db_get_idea db_update_idea_vault_path db_get_today_ideas
export -f db_insert_commitment db_get_commitment db_update_commitment_vault_path db_get_pending_commitments
export -f db_check_duplicate
export -f db_log_activity
export -f db_ensure_daily_note db_add_daily_decision db_add_daily_idea db_update_daily_session
export -f db_get_state db_set_state
