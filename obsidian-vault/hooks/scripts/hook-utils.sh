#!/bin/bash
# Obsidian Vault Plugin - Hook Utility Functions

CONFIG_FILE="$HOME/.claude/obsidian-vault.json"

# Get vault path from config
get_vault_path() {
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r '.vaultPath // empty' "$CONFIG_FILE" 2>/dev/null
    fi
}

# Check if auto-capture is enabled for a type
is_capture_enabled() {
    local type="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        local enabled
        enabled=$(jq -r ".autoCapture.$type // true" "$CONFIG_FILE" 2>/dev/null)
        [[ "$enabled" == "true" ]]
    else
        return 1
    fi
}

# Check if vault is configured
check_vault() {
    local vault_path
    vault_path=$(get_vault_path)
    if [[ -z "$vault_path" ]] || [[ ! -d "$vault_path" ]]; then
        return 1
    fi
    echo "$vault_path"
}

# Generate slug from text
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50
}

# Get current date in YYYY-MM-DD format
get_date() {
    date +%Y-%m-%d
}

# Get current datetime
get_datetime() {
    date "+%Y-%m-%d %H:%M"
}

# Create frontmatter for a note
create_frontmatter() {
    local title="$1"
    local description="$2"
    local tags="$3"
    local related="$4"
    local created="${5:-$(get_date)}"

    echo "---"
    echo "title: \"$title\""
    echo "description: \"$description\""
    echo "tags: [$tags]"
    if [[ -n "$related" ]]; then
        echo "related: [$related]"
    else
        echo "related: []"
    fi
    echo "created: $created"
    echo "updated: $(get_date)"
    echo "---"
}

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

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

# Check if a commit note already exists
commit_note_exists() {
    local vault_path="$1"
    local commit_hash="$2"

    grep -rl "Commit: $commit_hash" "$vault_path/journal/commits" --include="*.md" 2>/dev/null | head -1
}

# Get tool input from environment (set by Claude Code hooks)
get_tool_input() {
    echo "${CLAUDE_TOOL_INPUT:-}"
}

# Get tool output from environment
get_tool_output() {
    echo "${CLAUDE_TOOL_OUTPUT:-}"
}

# Log to debug file (optional)
debug_log() {
    local msg="$1"
    local debug_file="$HOME/.claude/obsidian-vault-debug.log"

    if [[ "${OBSIDIAN_DEBUG:-false}" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$debug_file"
    fi
}

export -f get_vault_path is_capture_enabled check_vault slugify get_date get_datetime
export -f create_frontmatter get_project_name get_git_branch ensure_dir
export -f commit_note_exists get_tool_input get_tool_output debug_log
