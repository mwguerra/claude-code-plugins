#!/bin/bash
# Error Memory Plugin - Detect errors in tool output
# This script analyzes tool output for error patterns

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PLUGIN_ROOT/scripts/lib/platform.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract tool information
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // .toolInput // "{}"')
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // .toolOutput // .output // ""')
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // .exitCode // 0')

# Error detection patterns
declare -a ERROR_PATTERNS=(
    # PHP/Laravel errors
    "Fatal error:"
    "Parse error:"
    "SQLSTATE\["
    "Exception:"
    "ErrorException"
    "BadMethodCallException"
    "InvalidArgumentException"
    "RuntimeException"
    "Call to undefined"
    "Class .* not found"
    "Undefined variable"
    "Undefined index"
    "Undefined property"

    # JavaScript/Node errors
    "TypeError:"
    "ReferenceError:"
    "SyntaxError:"
    "RangeError:"
    "Error:"
    "UnhandledPromiseRejection"
    "Cannot find module"
    "is not defined"
    "is not a function"

    # Python errors
    "Traceback \(most recent call last\)"
    "ImportError:"
    "ModuleNotFoundError:"
    "AttributeError:"
    "KeyError:"
    "ValueError:"
    "IndentationError:"

    # HTTP errors
    "HTTP/[0-9.]* [45][0-9][0-9]"
    "404 Not Found"
    "500 Internal Server Error"
    "403 Forbidden"
    "401 Unauthorized"

    # Database errors
    "Connection refused"
    "Access denied for user"
    "Unknown database"
    "Table .* doesn't exist"
    "Duplicate entry"

    # Docker errors
    "container .* is not running"
    "No such container"
    "port is already allocated"
    "network .* not found"

    # Git errors
    "fatal:"
    "error: failed to push"
    "CONFLICT \(content\)"
    "merge conflict"

    # Build errors
    "Build failed"
    "Compilation failed"
    "npm ERR!"
    "composer .* failed"

    # Browser/Playwright errors
    "net::ERR_"
    "page crashed"
    "Target closed"
    "Navigation failed"
    "TimeoutError"
    "Element not found"
    "Selector .* not found"
)

# Check if output contains error patterns
detect_error() {
    local output="$1"
    local found_error=""

    for pattern in "${ERROR_PATTERNS[@]}"; do
        if echo "$output" | grep -qiE "$pattern"; then
            found_error=$(echo "$output" | grep -iE "$pattern" | head -5)
            echo "$found_error"
            return 0
        fi
    done

    return 1
}

# Main logic
error_detected=""
error_source=""

case "$TOOL_NAME" in
    Bash|bash)
        # Check exit code first
        if [[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]]; then
            error_detected="$TOOL_OUTPUT"
            error_source="bash"
        else
            # Check output for error patterns even if exit code is 0
            if detected=$(detect_error "$TOOL_OUTPUT"); then
                error_detected="$detected"
                error_source="bash"
            fi
        fi
        ;;

    Read|read)
        # Check file content for error logs
        if detected=$(detect_error "$TOOL_OUTPUT"); then
            error_detected="$detected"
            error_source="read"
        fi
        ;;

    mcp__*playwright*|*browser*)
        # Playwright/browser tool errors
        if detected=$(detect_error "$TOOL_OUTPUT"); then
            error_detected="$detected"
            error_source="playwright"
        fi
        ;;

    WebFetch|webfetch)
        # API/HTTP errors
        if detected=$(detect_error "$TOOL_OUTPUT"); then
            error_detected="$detected"
            error_source="api"
        fi
        ;;

    *)
        # Generic error detection for other tools
        if detected=$(detect_error "$TOOL_OUTPUT"); then
            error_detected="$detected"
            error_source="other"
        fi
        ;;
esac

# If error detected, output for Claude to handle
if [[ -n "$error_detected" ]]; then
    # Escape for JSON
    error_escaped=$(echo "$error_detected" | head -c 2000 | jq -Rs .)

    cat << EOF
{
  "error_detected": true,
  "error_message": $error_escaped,
  "source": "$error_source",
  "tool": "$TOOL_NAME",
  "suggestion": "Consider searching for similar errors: /error:search <error message>"
}
EOF
else
    echo '{"error_detected": false}'
fi
