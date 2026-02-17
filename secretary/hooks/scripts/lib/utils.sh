#!/bin/bash
# Secretary Plugin - Core Utility Functions
# Cross-platform compatible (Linux, macOS, Windows/Git Bash)

# Configuration and database paths (respect environment overrides for testing)
SECRETARY_CONFIG_FILE="${SECRETARY_CONFIG_FILE:-$HOME/.claude/secretary.json}"
SECRETARY_DB_DIR="${SECRETARY_DB_DIR:-$HOME/.claude/secretary}"
SECRETARY_DB_PATH="${SECRETARY_DB_PATH:-$SECRETARY_DB_DIR/secretary.db}"
SECRETARY_MEMORY_DB_PATH="${SECRETARY_MEMORY_DB_PATH:-$SECRETARY_DB_DIR/memory.db}"
SECRETARY_AUTH_FILE="${SECRETARY_AUTH_FILE:-$SECRETARY_DB_DIR/auth.json}"
SECRETARY_DEBUG_LOG="${SECRETARY_DEBUG_LOG:-$SECRETARY_DB_DIR/debug.log}"
SECRETARY_WORKER_LOG="${SECRETARY_WORKER_LOG:-$SECRETARY_DB_DIR/worker.log}"
OBSIDIAN_CONFIG="${OBSIDIAN_CONFIG:-$HOME/.claude/obsidian-vault.json}"

# ============================================================================
# Platform Detection
# ============================================================================

detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

SECRETARY_OS_TYPE=$(detect_os)

# ============================================================================
# Configuration Functions
# ============================================================================

# Get config value using jq
get_config() {
    local path="$1"
    local default="$2"
    if [[ -f "$SECRETARY_CONFIG_FILE" ]]; then
        local value
        value=$(jq -r "$path // empty" "$SECRETARY_CONFIG_FILE" 2>/dev/null)
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
        "commits")      value=$(get_config '.logging.captureCommits' 'true') ;;
        "decisions")    value=$(get_config '.logging.captureDecisions' 'true') ;;
        "commitments")  value=$(get_config '.logging.captureCommitments' 'true') ;;
        "ideas")        value=$(get_config '.logging.captureIdeas' 'true') ;;
        "briefing")     value=$(get_config '.briefing.showOnStart' 'true') ;;
        "vault")        value=$(get_config '.vault.enabled' 'true') ;;
        "github")       value=$(get_config '.briefing.includeGitHub' 'true') ;;
        "ai")           value=$(get_config '.ai.enabled' 'true') ;;
        "memory")       value=$(get_config '.memory.enabled' 'true') ;;
        "cron")         value=$(get_config '.worker.cronEnabled' 'true') ;;
        *)              value="false" ;;
    esac
    [[ "$value" == "true" ]]
}

# ============================================================================
# Date/Time Functions (Cross-platform)
# ============================================================================

get_date() {
    date +%Y-%m-%d
}

get_datetime() {
    date "+%Y-%m-%d %H:%M:%S"
}

get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Convert date string to epoch (cross-platform)
date_to_epoch() {
    local date_str="$1"
    if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$date_str" +%s 2>/dev/null || \
        date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +%s 2>/dev/null || \
        echo "0"
    else
        date -d "$date_str" +%s 2>/dev/null || echo "0"
    fi
}

days_ago_epoch() {
    local days="$1"
    if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
        date -v-${days}d +%s
    else
        date -d "$days days ago" +%s
    fi
}

days_ago_date() {
    local days="$1"
    if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
        date -v-${days}d +%Y-%m-%d
    else
        date -d "$days days ago" +%Y-%m-%d
    fi
}

file_mtime() {
    local file="$1"
    if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
        stat -f %m "$file" 2>/dev/null || echo "0"
    else
        stat -c %Y "$file" 2>/dev/null || echo "0"
    fi
}

touch_date() {
    local date_str="$1"
    local file="$2"
    if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
        local formatted
        formatted=$(date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +%Y%m%d%H%M.%S 2>/dev/null)
        touch -t "$formatted" "$file" 2>/dev/null
    else
        touch -d "$date_str" "$file" 2>/dev/null
    fi
}

# ============================================================================
# String Functions
# ============================================================================

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50
}

sql_escape() {
    echo "$1" | sed "s/'/''/g"
}

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
# Project/Git Functions
# ============================================================================

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

get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

get_latest_commit() {
    git log -1 --format="%H|%h|%s|%an|%ci" 2>/dev/null
}

# ============================================================================
# Utility Functions
# ============================================================================

ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

get_tool_input() {
    echo "${CLAUDE_TOOL_INPUT:-}"
}

get_tool_output() {
    echo "${CLAUDE_TOOL_OUTPUT:-}"
}

get_user_prompt() {
    echo "${CLAUDE_USER_PROMPT:-}"
}

get_agent_output() {
    echo "${CLAUDE_TOOL_OUTPUT:-}"
}

# Global variable to store hook input (read once from stdin)
if [[ -z "${SECRETARY_HOOK_INPUT_CACHED+x}" ]]; then
    SECRETARY_HOOK_INPUT_CACHED=""
fi
if [[ -z "${SECRETARY_HOOK_INPUT_READ+x}" ]]; then
    SECRETARY_HOOK_INPUT_READ=false
fi

read_hook_input() {
    if [[ "$SECRETARY_HOOK_INPUT_READ" == "false" ]]; then
        SECRETARY_HOOK_INPUT_CACHED=$(timeout 2 cat 2>/dev/null || echo "")
        SECRETARY_HOOK_INPUT_READ=true
    fi
    echo "$SECRETARY_HOOK_INPUT_CACHED"
}

get_transcript_path() {
    local input
    input=$(read_hook_input)
    if [[ -z "$input" ]]; then
        echo ""
        return
    fi
    local transcript_path
    transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
    if [[ "$transcript_path" == "~/"* ]]; then
        transcript_path="${HOME}${transcript_path:1}"
    fi
    echo "$transcript_path"
}

# ============================================================================
# Obsidian Vault Integration
# ============================================================================

get_vault_path() {
    if [[ -f "$OBSIDIAN_CONFIG" ]]; then
        jq -r '.vaultPath // empty' "$OBSIDIAN_CONFIG" 2>/dev/null
    fi
}

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

get_secretary_folder() {
    local vault_path
    vault_path=$(check_vault) || return 1
    local folder
    folder=$(get_config '.vault.secretaryFolder' 'secretary')
    echo "$vault_path/$folder"
}

sanitize_tag() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

create_vault_frontmatter() {
    local title="$1"
    local description="$2"
    local tags="$3"
    local related="$4"
    local extra="$5"
    local created="${6:-$(get_date)}"

    echo "---"
    echo "title: \"$(echo "$title" | sed 's/"/\\"/g')\""
    if [[ -n "$description" ]]; then
        echo "description: \"$(echo "$description" | sed 's/"/\\"/g')\""
    fi
    echo "tags:"
    if [[ -n "$tags" ]]; then
        echo "$tags" | tr ',' '\n' | while read -r tag; do
            tag=$(echo "$tag" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            local clean_tag=$(sanitize_tag "$tag")
            if [[ -n "$clean_tag" ]]; then
                echo "  - \"$clean_tag\""
            fi
        done
    fi
    echo "related:"
    if [[ -n "$related" ]]; then
        echo "$related" | tr ',' '\n' | while read -r link; do
            link=$(echo "$link" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ -n "$link" ]]; then
                echo "  - \"$link\""
            fi
        done
    fi
    echo "created: $created"
    echo "updated: $(get_date)"
    if [[ -n "$extra" ]]; then
        echo "$extra"
    fi
    echo "---"
}

wiki_link() {
    local path="$1"
    local display="$2"
    path="${path%.md}"
    if [[ -n "$display" ]]; then
        echo "[[${path}|${display}]]"
    else
        echo "[[${path}]]"
    fi
}

ensure_vault_structure() {
    local secretary_folder
    secretary_folder=$(get_secretary_folder) || return 1
    ensure_dir "$secretary_folder/daily"
    ensure_dir "$secretary_folder/sessions"
    ensure_dir "$secretary_folder/decisions"
    ensure_dir "$secretary_folder/commitments"
    ensure_dir "$secretary_folder/ideas"
    ensure_dir "$secretary_folder/goals"
    ensure_dir "$secretary_folder/reviews"
    ensure_dir "$secretary_folder/patterns"
}

# ============================================================================
# Logging Functions
# ============================================================================

debug_log() {
    local msg="$1"
    if [[ "${SECRETARY_DEBUG:-false}" == "true" ]]; then
        echo "[$(get_iso_timestamp)] $msg" >> "$SECRETARY_DEBUG_LOG"
    fi
}

# ============================================================================
# Session Functions
# ============================================================================

generate_session_id() {
    date +"%Y%m%d-%H%M%S-$$"
}

# ============================================================================
# Process Detection for Session Cleanup (Cross-platform)
# ============================================================================

is_claude_running_for_directory() {
    local target_dir="$1"
    target_dir=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")

    if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
        # macOS: use lsof to find processes
        local pids
        pids=$(pgrep -x "claude" 2>/dev/null) || return 1
        for pid in $pids; do
            local cwd
            cwd=$(lsof -p "$pid" -Fn 2>/dev/null | grep "^n.*cwd" | head -1 | sed 's/^n//' || true)
            if [[ -n "$cwd" && ("$target_dir" == "$cwd"* || "$cwd" == "$target_dir"*) ]]; then
                return 0
            fi
        done
    elif [[ "$SECRETARY_OS_TYPE" == "windows" ]]; then
        # Windows/Git Bash: skip process detection
        return 1
    else
        # Linux: use /proc
        local pids
        pids=$(pgrep -x "claude" 2>/dev/null) || return 1
        for pid in $pids; do
            local cwd
            cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
            if [[ "$target_dir" == "$cwd"* ]] || [[ "$cwd" == "$target_dir"* ]]; then
                return 0
            fi
        done
    fi

    return 1
}

# ============================================================================
# Export Functions
# ============================================================================

export SECRETARY_OS_TYPE
export SECRETARY_CONFIG_FILE SECRETARY_DB_DIR SECRETARY_DB_PATH SECRETARY_MEMORY_DB_PATH
export SECRETARY_AUTH_FILE SECRETARY_DEBUG_LOG SECRETARY_WORKER_LOG OBSIDIAN_CONFIG

export -f detect_os get_config is_enabled
export -f get_date get_datetime get_iso_timestamp date_to_epoch days_ago_epoch days_ago_date file_mtime touch_date
export -f slugify sql_escape json_escape
export -f get_project_name get_git_branch get_latest_commit
export -f ensure_dir get_tool_input get_tool_output get_user_prompt get_agent_output
export -f read_hook_input get_transcript_path
export -f get_vault_path check_vault get_secretary_folder sanitize_tag
export -f create_vault_frontmatter wiki_link ensure_vault_structure
export -f debug_log generate_session_id is_claude_running_for_directory
