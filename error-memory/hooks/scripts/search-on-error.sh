#!/bin/bash
# Error Memory Plugin - Automatically search for similar errors when one is detected
# This hook runs after error detection and searches the database

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PLUGIN_ROOT/scripts/lib/platform.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"

# Only proceed if database exists and has errors
if [[ ! -f "$ERRORS_FILE" ]]; then
    exit 0
fi

error_count=$(jq '.errors | length' "$ERRORS_FILE" 2>/dev/null || echo "0")
if [[ "$error_count" -eq 0 ]]; then
    exit 0
fi

# Read hook input from environment variables (Claude Code provides these)
TOOL_OUTPUT="${CLAUDE_TOOL_OUTPUT:-}"
EXIT_CODE="${CLAUDE_EXIT_CODE:-0}"

# Skip if no output
if [[ -z "$TOOL_OUTPUT" ]]; then
    exit 0
fi

# Quick check for error indicators
has_error=false

# Check exit code
if [[ "$EXIT_CODE" != "0" ]] && [[ "$EXIT_CODE" != "null" ]]; then
    has_error=true
fi

# Check for common error patterns
if echo "$TOOL_OUTPUT" | grep -qiE "(error|exception|fatal|failed|SQLSTATE|TypeError|Cannot)"; then
    has_error=true
fi

if [[ "$has_error" != "true" ]]; then
    exit 0
fi

# Extract a searchable query from the error
# Take the first meaningful error line
error_query=$(echo "$TOOL_OUTPUT" | grep -iE "(error|exception|fatal|failed|SQLSTATE|TypeError|Cannot)" | head -1 | head -c 200)

if [[ -z "$error_query" ]]; then
    # Fallback: just take first non-empty line of output
    error_query=$(echo "$TOOL_OUTPUT" | grep -v '^$' | head -1 | head -c 200)
fi

if [[ -z "$error_query" ]]; then
    exit 0
fi

# Search for similar errors (silently, just get results)
results=$("$PLUGIN_ROOT/scripts/search.sh" "$error_query" --max 3 --json 2>/dev/null || echo "[]")
match_count=$(echo "$results" | jq 'length' 2>/dev/null || echo "0")

if [[ "$match_count" -gt 0 ]]; then
    best_confidence=$(echo "$results" | jq '.[0].confidence // 0')
    best_id=$(echo "$results" | jq -r '.[0].id // ""')
    best_solution=$(echo "$results" | jq -r '.[0].solution // ""' | head -c 300)

    if [[ "$best_confidence" -ge 50 ]]; then
        # High confidence match - provide context to Claude
        cat << EOF

---
**Error Memory Match Found** (${best_confidence}% confidence)

A similar error was previously solved:
- ID: $best_id
- Solution: $best_solution

View full details: \`/error:show $best_id\`
---

EOF
    fi
fi
