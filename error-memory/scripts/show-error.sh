#!/bin/bash
# Error Memory Plugin - Show full details of an error

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"
source "$SCRIPT_DIR/lib/hash.sh"
source "$SCRIPT_DIR/lib/normalize.sh"
source "$SCRIPT_DIR/lib/match.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"

# Check dependencies
check_jq

# Parse arguments
ERROR_ID=""
FORMAT="text"  # text or json

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            FORMAT="json"
            shift
            ;;
        --help|-h)
            echo "Usage: show-error.sh <error-id> [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json     Output as JSON"
            echo "  --help     Show this help"
            exit 0
            ;;
        *)
            if [[ -z "$ERROR_ID" ]]; then
                ERROR_ID="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$ERROR_ID" ]]; then
    echo "ERROR: Error ID required"
    echo "Usage: show-error.sh <error-id>"
    exit 1
fi

# Initialize if needed
if [[ ! -f "$ERRORS_FILE" ]]; then
    echo "ERROR: No errors database found. Run /error:init first."
    exit 1
fi

# Get error
error=$(get_error "$ERROR_ID")

if [[ -z "$error" ]] || [[ "$error" == "{}" ]]; then
    echo "ERROR: Error not found: $ERROR_ID"
    exit 1
fi

if [[ "$FORMAT" == "json" ]]; then
    echo "$error"
    exit 0
fi

# Text output
echo "Error Details: $ERROR_ID"
echo "=================================================="
echo ""

# Basic info
created=$(echo "$error" | jq -r '.createdAt')
updated=$(echo "$error" | jq -r '.updatedAt')
echo "Created: $created"
echo "Updated: $updated"
echo ""

# Error info
echo "ERROR INFORMATION"
echo "-----------------"
type=$(echo "$error" | jq -r '.error.type')
message=$(echo "$error" | jq -r '.error.message')
normalized=$(echo "$error" | jq -r '.error.normalized')
keywords=$(echo "$error" | jq -r '.error.keywords | join(", ")')

echo "Type: $type"
echo "Keywords: $keywords"
echo ""
echo "Original Message:"
echo "$message"
echo ""
echo "Normalized:"
echo "$normalized"
echo ""

# Context
echo "CONTEXT"
echo "-------"
project=$(echo "$error" | jq -r '.context.project // "unknown"')
project_path=$(echo "$error" | jq -r '.context.projectPath // "N/A"')
source=$(echo "$error" | jq -r '.context.source // "other"')
what_happened=$(echo "$error" | jq -r '.context.whatHappened // "N/A"')

echo "Project: $project"
echo "Path: $project_path"
echo "Source: $source"
echo "What Happened: $what_happened"
echo ""

# Analysis
echo "ANALYSIS"
echo "--------"
cause=$(echo "$error" | jq -r '.analysis.cause')
solution=$(echo "$error" | jq -r '.analysis.solution')
rationale=$(echo "$error" | jq -r '.analysis.rationale // "N/A"')

echo "Cause:"
echo "$cause"
echo ""
echo "Solution:"
echo "$solution"
echo ""
echo "Rationale:"
echo "$rationale"
echo ""

# Code changes (if present)
has_code=$(echo "$error" | jq -r '.code != null')
if [[ "$has_code" == "true" ]]; then
    echo "CODE CHANGES"
    echo "------------"
    file_changed=$(echo "$error" | jq -r '.code.fileChanged')
    code_before=$(echo "$error" | jq -r '.code.before // "N/A"')
    code_after=$(echo "$error" | jq -r '.code.after // "N/A"')

    echo "File: $file_changed"
    echo ""
    echo "Before:"
    echo '```'
    echo "$code_before"
    echo '```'
    echo ""
    echo "After:"
    echo '```'
    echo "$code_after"
    echo '```'
    echo ""
fi

# Tags
tags=$(echo "$error" | jq -r '.tags | join(", ")')
echo "TAGS"
echo "----"
echo "$tags"
echo ""

# Stats
echo "USAGE STATS"
echo "-----------"
usage=$(echo "$error" | jq -r '.stats.usageCount // 0')
last_used=$(echo "$error" | jq -r '.stats.lastUsedAt // "Never"')
success_rate=$(echo "$error" | jq -r '.stats.successRate // 1.0')

echo "Times Used: $usage"
echo "Last Used: $last_used"
echo "Success Rate: ${success_rate}"
echo ""

echo "=================================================="
echo "Commands:"
echo "  Search similar: /error:search <query>"
echo "  List all: /error:list"
