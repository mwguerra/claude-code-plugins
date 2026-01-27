#!/bin/bash
# Error Memory Plugin - Cross-Platform Utilities

# Guard against double-sourcing
[[ -n "$_ERROR_MEMORY_PLATFORM_SH" ]] && return
_ERROR_MEMORY_PLATFORM_SH=1

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

# Cross-platform sed in-place editing
# Usage: sed_inplace "s/foo/bar/" file.txt
sed_inplace() {
    local script="$1"
    local file="$2"
    local tmp
    tmp=$(mktemp)
    sed "$script" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Cross-platform date formatting
# Usage: format_date (returns ISO 8601)
format_date() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Cross-platform date parsing (returns epoch)
# Usage: parse_date "2026-01-27T14:30:00Z"
parse_date() {
    local datestr="$1"
    if [[ "$OS_TYPE" == "macos" ]]; then
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$datestr" "+%s" 2>/dev/null || echo "0"
    else
        date -d "$datestr" "+%s" 2>/dev/null || echo "0"
    fi
}

# Check if jq is installed
check_jq() {
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required but not installed."
        echo ""
        if [[ "$OS_TYPE" == "macos" ]]; then
            echo "Install with: brew install jq"
        else
            echo "Install with: sudo apt install jq"
        fi
        exit 1
    fi
}

# Generate a unique ID
# Usage: generate_id "err"
generate_id() {
    local prefix="${1:-id}"
    local random
    if [[ "$OS_TYPE" == "macos" ]]; then
        random=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 12)
    else
        random=$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 12)
    fi
    echo "${prefix}_${random}"
}

# Portable mktemp with directory support
make_temp() {
    local type="${1:-file}"
    if [[ "$type" == "dir" ]]; then
        mktemp -d
    else
        mktemp
    fi
}

# JSON-safe string escaping
json_escape() {
    local str="$1"
    # Escape backslashes, quotes, and control characters
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' '
}

export OS_TYPE
export -f detect_os sed_inplace format_date parse_date check_jq generate_id make_temp json_escape
