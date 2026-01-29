#!/bin/bash
# Diagnostic hook to capture what Claude Code sends to hooks

LOG_FILE="$HOME/.claude/my-workflow/hook-diagnostic.log"

{
    echo "==================== $(date -u +%Y-%m-%dT%H:%M:%SZ) ===================="
    echo "ENVIRONMENT VARIABLES:"
    echo "  CLAUDE_TOOL_OUTPUT length: ${#CLAUDE_TOOL_OUTPUT}"
    echo "  CLAUDE_TOOL_INPUT length: ${#CLAUDE_TOOL_INPUT}"
    echo "  CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-NOT_SET}"
    echo "  CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-NOT_SET}"
    echo ""

    if [[ -n "$CLAUDE_TOOL_OUTPUT" ]]; then
        echo "CLAUDE_TOOL_OUTPUT (first 500 chars):"
        echo "$CLAUDE_TOOL_OUTPUT" | head -c 500
        echo ""
    else
        echo "CLAUDE_TOOL_OUTPUT is EMPTY"
    fi

    if [[ -n "$CLAUDE_TOOL_INPUT" ]]; then
        echo "CLAUDE_TOOL_INPUT (first 500 chars):"
        echo "$CLAUDE_TOOL_INPUT" | head -c 500
        echo ""
    else
        echo "CLAUDE_TOOL_INPUT is EMPTY"
    fi

    echo ""
    echo "STDIN CONTENT:"
    STDIN_CONTENT=$(timeout 1 cat 2>/dev/null || echo "")
    if [[ -n "$STDIN_CONTENT" ]]; then
        echo "$STDIN_CONTENT" | head -c 2000
    else
        echo "(empty or timed out)"
    fi
    echo ""
    echo "=========================================================================="
    echo ""
} >> "$LOG_FILE"

exit 0
