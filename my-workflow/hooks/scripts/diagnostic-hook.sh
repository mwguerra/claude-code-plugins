#!/bin/bash
# Diagnostic hook to capture what Claude Code sends to hooks
# Run this to debug what environment variables and data are available

LOG_FILE="$HOME/.claude/my-workflow/hook-diagnostic.log"
mkdir -p "$(dirname "$LOG_FILE")"

{
    echo "==================== $(date -u +%Y-%m-%dT%H:%M:%SZ) ===================="
    echo "HOOK EVENT: ${1:-unknown}"
    echo ""

    echo "ALL CLAUDE_* ENVIRONMENT VARIABLES:"
    env | grep -i "^CLAUDE" | while read -r line; do
        varname=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        echo "  $varname: (${#value} chars)"
        if [[ ${#value} -gt 0 && ${#value} -lt 500 ]]; then
            echo "    -> $value"
        elif [[ ${#value} -ge 500 ]]; then
            echo "    -> $(echo "$value" | head -c 200)..."
        fi
    done
    echo ""

    echo "KEY VARIABLES:"
    echo "  CLAUDE_STOP_SUMMARY length: ${#CLAUDE_STOP_SUMMARY}"
    echo "  CLAUDE_TOOL_OUTPUT length: ${#CLAUDE_TOOL_OUTPUT}"
    echo "  CLAUDE_TOOL_INPUT length: ${#CLAUDE_TOOL_INPUT}"
    echo "  CLAUDE_USER_PROMPT length: ${#CLAUDE_USER_PROMPT}"
    echo "  CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-NOT_SET}"
    echo "  CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-NOT_SET}"
    echo ""

    if [[ -n "$CLAUDE_STOP_SUMMARY" ]]; then
        echo "CLAUDE_STOP_SUMMARY (first 1000 chars):"
        echo "$CLAUDE_STOP_SUMMARY" | head -c 1000
        echo ""
        echo "---"
    fi

    if [[ -n "$CLAUDE_TOOL_OUTPUT" ]]; then
        echo "CLAUDE_TOOL_OUTPUT (first 500 chars):"
        echo "$CLAUDE_TOOL_OUTPUT" | head -c 500
        echo ""
        echo "---"
    fi

    # Try reading from stdin (some hooks pass data via stdin)
    echo "CHECKING STDIN:"
    if read -t 1 -N 1 stdin_char; then
        STDIN_CONTENT="${stdin_char}$(timeout 2 cat 2>/dev/null || echo "")"
        echo "  STDIN has content (${#STDIN_CONTENT} chars):"
        echo "$STDIN_CONTENT" | head -c 1000
    else
        echo "  STDIN is empty or timed out"
    fi
    echo ""

    echo "=========================================================================="
    echo ""
} >> "$LOG_FILE"

exit 0
