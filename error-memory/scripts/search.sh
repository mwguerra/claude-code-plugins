#!/bin/bash
# Error Memory Plugin - Search for similar errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"
source "$SCRIPT_DIR/lib/hash.sh"
source "$SCRIPT_DIR/lib/normalize.sh"
source "$SCRIPT_DIR/lib/match.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"
STATS_FILE="$CONFIG_DIR/stats.json"

# Check dependencies
check_jq

# Parse arguments
QUERY=""
MAX_RESULTS=5
FORMAT="text"  # text or json

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max|-n)
            MAX_RESULTS="$2"
            shift 2
            ;;
        --json)
            FORMAT="json"
            shift
            ;;
        *)
            if [[ -z "$QUERY" ]]; then
                QUERY="$1"
            else
                QUERY="$QUERY $1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$QUERY" ]]; then
    echo "ERROR: Search query required"
    echo "Usage: search.sh <error message or keywords> [--max N] [--json]"
    exit 1
fi

# Initialize if needed
if [[ ! -f "$ERRORS_FILE" ]]; then
    bash "$SCRIPT_DIR/init.sh" >/dev/null
fi

# Search for matches
results=$(search_errors "$QUERY" "$MAX_RESULTS")
match_count=$(echo "$results" | jq 'length')

# Update stats
if [[ -f "$STATS_FILE" ]]; then
    jq --argjson matches "$match_count" '
        .totalSearches = (.totalSearches + 1) |
        .totalMatches = (.totalMatches + $matches)
    ' "$STATS_FILE" > "$STATS_FILE.tmp" && mv "$STATS_FILE.tmp" "$STATS_FILE"
fi

if [[ "$FORMAT" == "json" ]]; then
    echo "$results"
    exit 0
fi

# Text output
if [[ "$match_count" -eq 0 ]]; then
    echo "No similar errors found."
    echo ""
    echo "This appears to be a new error. After solving it, run:"
    echo "  /error:log"
    exit 0
fi

best_confidence=$(echo "$results" | jq '.[0].confidence')
echo "Found $match_count similar error(s) (best match: ${best_confidence}% confidence)"
echo ""

# Display results
index=1
echo "$results" | jq -r '.[] | @base64' | while read -r encoded; do
    result=$(echo "$encoded" | base64 -d)

    id=$(echo "$result" | jq -r '.id')
    confidence=$(echo "$result" | jq -r '.confidence')
    match_type=$(echo "$result" | jq -r '.matchType')
    project=$(echo "$result" | jq -r '.project // "unknown"')
    tags=$(echo "$result" | jq -r '.tags | join(", ")')
    cause=$(echo "$result" | jq -r '.cause')
    solution=$(echo "$result" | jq -r '.solution')
    usage=$(echo "$result" | jq -r '.usageCount // 0')

    if [[ $index -eq 1 ]]; then
        echo "[$index] BEST MATCH - $id (${confidence}% match, used ${usage}x)"
    else
        echo "[$index] RELATED - $id (${confidence}% match)"
    fi

    echo "    Project: $project"
    echo "    Tags: $tags"
    echo "    Cause: $cause"
    echo "    Solution: $solution"
    echo ""

    ((index++))
done

echo "---"
echo "View full details: /error:show <id>"
echo "Mark as used (if it helped): update usage stats automatically"
