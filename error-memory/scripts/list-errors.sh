#!/bin/bash
# Error Memory Plugin - List all errors with filtering

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"

# Check dependencies
check_jq

# Parse arguments
PROJECT=""
TAG=""
SOURCE=""
MAX_RESULTS=20
FORMAT="text"  # text or json

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project|-p)
            PROJECT="$2"
            shift 2
            ;;
        --tag|-t)
            TAG="$2"
            shift 2
            ;;
        --source|-s)
            SOURCE="$2"
            shift 2
            ;;
        --max|-n)
            MAX_RESULTS="$2"
            shift 2
            ;;
        --json)
            FORMAT="json"
            shift
            ;;
        --help|-h)
            echo "Usage: list-errors.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --project, -p  Filter by project name"
            echo "  --tag, -t      Filter by tag"
            echo "  --source, -s   Filter by source (bash|playwright|read|user|build|api|other)"
            echo "  --max, -n      Maximum results (default: 20)"
            echo "  --json         Output as JSON"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Initialize if needed
if [[ ! -f "$ERRORS_FILE" ]]; then
    bash "$SCRIPT_DIR/init.sh" >/dev/null
fi

# Build jq filter
JQ_FILTER='.errors'

if [[ -n "$PROJECT" ]]; then
    JQ_FILTER="$JQ_FILTER | map(select(.context.project | ascii_downcase | contains(\"$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]')\")))"
fi

if [[ -n "$TAG" ]]; then
    JQ_FILTER="$JQ_FILTER | map(select(.tags[] | ascii_downcase | contains(\"$(echo "$TAG" | tr '[:upper:]' '[:lower:]')\")))"
fi

if [[ -n "$SOURCE" ]]; then
    JQ_FILTER="$JQ_FILTER | map(select(.context.source == \"$SOURCE\"))"
fi

# Sort by most recently created and limit
JQ_FILTER="$JQ_FILTER | sort_by(.createdAt) | reverse | .[0:$MAX_RESULTS]"

# Get results
results=$(jq "$JQ_FILTER" "$ERRORS_FILE" 2>/dev/null)
count=$(echo "$results" | jq 'length')

if [[ "$FORMAT" == "json" ]]; then
    echo "$results"
    exit 0
fi

# Text output
echo "Error Memory - $count error(s) found"
echo ""

if [[ "$count" -eq 0 ]]; then
    echo "No errors match the filters."
    echo ""
    echo "Try:"
    echo "  list-errors.sh                    # List all errors"
    echo "  list-errors.sh --project myapp    # Filter by project"
    echo "  list-errors.sh --tag laravel      # Filter by tag"
    exit 0
fi

# Display results
echo "$results" | jq -r '.[] | @base64' | while read -r encoded; do
    error=$(echo "$encoded" | base64 -d)

    id=$(echo "$error" | jq -r '.id')
    created=$(echo "$error" | jq -r '.createdAt')
    type=$(echo "$error" | jq -r '.error.type')
    project=$(echo "$error" | jq -r '.context.project // "unknown"')
    source=$(echo "$error" | jq -r '.context.source // "other"')
    tags=$(echo "$error" | jq -r '.tags | join(", ")')
    usage=$(echo "$error" | jq -r '.stats.usageCount // 0')

    # Truncate message for display
    message=$(echo "$error" | jq -r '.error.message' | head -c 80)
    [[ ${#message} -eq 80 ]] && message="${message}..."

    echo "[$id] $type ($source)"
    echo "  Project: $project | Tags: $tags | Used: ${usage}x"
    echo "  Message: $message"
    echo "  Created: $created"
    echo ""
done

echo "---"
echo "View details: /error:show <id>"
echo "Search errors: /error:search <query>"
