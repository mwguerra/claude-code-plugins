#!/bin/bash
# My Workflow Plugin - Hook Utility Functions

# Configuration and database paths
CONFIG_FILE="$HOME/.claude/my-workflow.json"
DB_DIR="$HOME/.claude/my-workflow"
DB_PATH="$DB_DIR/workflow.db"
OBSIDIAN_CONFIG="$HOME/.claude/obsidian-vault.json"

# ============================================================================
# Configuration Functions
# ============================================================================

# Get config value using jq
get_config() {
    local path="$1"
    local default="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        local value
        value=$(jq -r "$path // empty" "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$value" && "$value" != "null" ]]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

# Check if a feature is enabled
is_enabled() {
    local feature="$1"
    local value
    case "$feature" in
        "commits")
            value=$(get_config '.logging.captureCommits' 'true')
            ;;
        "decisions")
            value=$(get_config '.logging.captureDecisions' 'true')
            ;;
        "commitments")
            value=$(get_config '.logging.captureCommitments' 'true')
            ;;
        "briefing")
            value=$(get_config '.briefing.showOnStart' 'true')
            ;;
        "vault")
            value=$(get_config '.vault.enabled' 'true')
            ;;
        "github")
            value=$(get_config '.briefing.includeGitHub' 'true')
            ;;
        *)
            value="false"
            ;;
    esac
    [[ "$value" == "true" ]]
}

# ============================================================================
# Database Functions
# ============================================================================

# Ensure database directory and file exist
ensure_db() {
    if [[ ! -d "$DB_DIR" ]]; then
        mkdir -p "$DB_DIR"
    fi

    if [[ ! -f "$DB_PATH" ]]; then
        # Initialize database with schema
        local schema_file="${CLAUDE_PLUGIN_ROOT}/schemas/schema.sql"
        if [[ -f "$schema_file" ]]; then
            sqlite3 "$DB_PATH" < "$schema_file"
            debug_log "Initialized database from schema"
        else
            debug_log "ERROR: Schema file not found: $schema_file"
            return 1
        fi
    fi
    echo "$DB_PATH"
}

# Run SQL query
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

# Get next ID for a table with prefix
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

# ============================================================================
# Session Functions
# ============================================================================

# Generate session ID
generate_session_id() {
    date +"%Y%m%d-%H%M%S-$$"
}

# Get current session ID
get_current_session_id() {
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "SELECT current_session_id FROM state WHERE id = 1" 2>/dev/null
}

# Set current session
set_current_session() {
    local session_id="$1"
    db_exec "UPDATE state SET current_session_id = '$session_id', updated_at = datetime('now') WHERE id = 1"
}

# ============================================================================
# Obsidian Vault Integration
# ============================================================================

# Get vault path from obsidian-vault plugin config
get_vault_path() {
    if [[ -f "$OBSIDIAN_CONFIG" ]]; then
        jq -r '.vaultPath // empty' "$OBSIDIAN_CONFIG" 2>/dev/null
    fi
}

# Check if vault integration is available
check_vault() {
    if ! is_enabled "vault"; then
        return 1
    fi

    local vault_path
    vault_path=$(get_vault_path)

    if [[ -z "$vault_path" ]] || [[ ! -d "$vault_path" ]]; then
        return 1
    fi

    echo "$vault_path"
}

# Get workflow folder in vault
get_workflow_folder() {
    local vault_path
    vault_path=$(check_vault) || return 1
    local folder
    folder=$(get_config '.vault.workflowFolder' 'workflow')
    echo "$vault_path/$folder"
}

# ============================================================================
# Project/Git Functions
# ============================================================================

# Get project name from git or directory
get_project_name() {
    local dir="${1:-$(pwd)}"

    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        local remote
        remote=$(git -C "$dir" remote get-url origin 2>/dev/null)
        if [[ -n "$remote" ]]; then
            basename "$remote" .git
            return
        fi
    fi

    basename "$dir"
}

# Get current git branch
get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Get latest commit info
get_latest_commit() {
    git log -1 --format="%H|%h|%s|%an|%ci" 2>/dev/null
}

# ============================================================================
# Date/Time Functions
# ============================================================================

# Get current date in YYYY-MM-DD format
get_date() {
    date +%Y-%m-%d
}

# Get current datetime in ISO format
get_datetime() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Get ISO 8601 timestamp
get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ============================================================================
# String Functions
# ============================================================================

# Generate slug from text
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50
}

# Escape string for SQL
sql_escape() {
    echo "${1//\'/\'\'}"
}

# Escape string for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

# Get tool input from environment
get_tool_input() {
    echo "${CLAUDE_TOOL_INPUT:-}"
}

# Get tool output from environment
get_tool_output() {
    echo "${CLAUDE_TOOL_OUTPUT:-}"
}

# Get stop summary from environment
get_stop_summary() {
    echo "${CLAUDE_STOP_SUMMARY:-}"
}

# ============================================================================
# Logging Functions
# ============================================================================

# Debug log (only when enabled)
debug_log() {
    local msg="$1"
    local debug_file="$DB_DIR/debug.log"

    if [[ "${WORKFLOW_DEBUG:-false}" == "true" ]]; then
        echo "[$(get_iso_timestamp)] $msg" >> "$debug_file"
    fi
}

# Activity log (always)
activity_log() {
    local activity_type="$1"
    local title="$2"
    local entity_type="$3"
    local entity_id="$4"
    local project="$5"
    local details="$6"

    local session_id
    session_id=$(get_current_session_id)

    local escaped_title
    escaped_title=$(sql_escape "$title")
    local escaped_details
    escaped_details=$(sql_escape "$details")

    db_exec "INSERT INTO activity_timeline (activity_type, title, entity_type, entity_id, project, details, session_id)
             VALUES ('$activity_type', '$escaped_title', '$entity_type', '$entity_id', '$project', '$escaped_details', '$session_id')"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f get_config is_enabled
export -f ensure_db db_query db_exec get_next_id
export -f generate_session_id get_current_session_id set_current_session
export -f get_vault_path check_vault get_workflow_folder
export -f get_project_name get_git_branch get_latest_commit
export -f get_date get_datetime get_iso_timestamp
export -f slugify sql_escape json_escape
export -f ensure_dir get_tool_input get_tool_output get_stop_summary
export -f debug_log activity_log
