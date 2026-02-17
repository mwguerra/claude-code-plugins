#!/bin/bash
# Secretary Plugin - Database Functions
# SQLite operations with WAL mode for concurrent access

# Source utils if not already loaded
if [[ -z "${SECRETARY_DB_PATH:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/utils.sh"
fi

# ============================================================================
# Database Functions
# ============================================================================

# Ensure database directory and file exist
ensure_db() {
    if [[ ! -d "$SECRETARY_DB_DIR" ]]; then
        mkdir -p "$SECRETARY_DB_DIR"
    fi

    if [[ ! -f "$SECRETARY_DB_PATH" ]]; then
        local schema_file="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")")}/schemas/secretary.sql"
        if [[ -f "$schema_file" ]]; then
            sqlite3 "$SECRETARY_DB_PATH" < "$schema_file"
            # Enable WAL mode for concurrent access
            sqlite3 "$SECRETARY_DB_PATH" "PRAGMA journal_mode=WAL;"
            debug_log "Initialized secretary database from schema"
        else
            debug_log "ERROR: Schema file not found: $schema_file"
            return 1
        fi
    fi
    echo "$SECRETARY_DB_PATH"
}

# Run SQL query (returns results)
db_query() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 -json "$db" "$sql" 2>/dev/null
}

# Run SQL command (no output expected)
db_exec() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "$sql" 2>/dev/null
}

# Run SQL query with separator output (for shell processing)
db_query_sep() {
    local sql="$1"
    local sep="${2:-|}"
    local db
    db=$(ensure_db) || return 1
    sqlite3 -separator "$sep" "$db" "$sql" 2>/dev/null
}

# Get next ID for a table with prefix (C-0001, D-0001, etc.)
get_next_id() {
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

# Get current session ID from state table
get_current_session_id() {
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "SELECT current_session_id FROM state WHERE id = 1" 2>/dev/null
}

# Set current session ID
set_current_session() {
    local session_id="$1"
    db_exec "UPDATE state SET current_session_id = '$(sql_escape "$session_id")', updated_at = datetime('now') WHERE id = 1"
}

# Queue an item for later processing
# Usage: queue_item "type" "data" [priority] [session_id] [project]
queue_item() {
    local item_type="$1"
    local data="$2"
    local priority="${3:-5}"
    local session_id="${4:-}"
    local project="${5:-}"

    local escaped_data
    escaped_data=$(sql_escape "$data")
    local escaped_project
    escaped_project=$(sql_escape "$project")
    local escaped_session
    escaped_session=$(sql_escape "$session_id")

    db_exec "INSERT INTO queue (item_type, data, priority, session_id, project, status, attempts, created_at)
             VALUES ('$item_type', '$escaped_data', $priority, '$escaped_session', '$escaped_project', 'pending', 0, datetime('now'))"
}

# Get pending queue count
get_queue_count() {
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "SELECT COUNT(*) FROM queue WHERE status = 'pending'" 2>/dev/null || echo "0"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f ensure_db db_query db_exec db_query_sep get_next_id
export -f get_current_session_id set_current_session
export -f queue_item get_queue_count
