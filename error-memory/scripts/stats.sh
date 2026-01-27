#!/bin/bash
# Error Memory Plugin - Show statistics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"
STATS_FILE="$CONFIG_DIR/stats.json"

# Check dependencies
check_jq

# Parse arguments
FORMAT="text"  # text or json

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            FORMAT="json"
            shift
            ;;
        --help|-h)
            echo "Usage: stats.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --json     Output as JSON"
            echo "  --help     Show this help"
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

# Gather statistics
total_errors=$(jq '.errors | length' "$ERRORS_FILE" 2>/dev/null || echo "0")

# Get stats from stats file
total_searches=$(jq '.totalSearches // 0' "$STATS_FILE" 2>/dev/null || echo "0")
total_matches=$(jq '.totalMatches // 0' "$STATS_FILE" 2>/dev/null || echo "0")
last_updated=$(jq -r '.lastUpdated // "Never"' "$STATS_FILE" 2>/dev/null || echo "Never")

# Calculate derived stats from errors
if [[ "$total_errors" -gt 0 ]]; then
    # By source
    by_source=$(jq '[.errors[].context.source // "unknown"] | group_by(.) | map({key: .[0], value: length}) | from_entries' "$ERRORS_FILE" 2>/dev/null || echo "{}")

    # By type
    by_type=$(jq '[.errors[].error.type // "Unknown"] | group_by(.) | map({key: .[0], value: length}) | from_entries' "$ERRORS_FILE" 2>/dev/null || echo "{}")

    # By project
    by_project=$(jq '[.errors[].context.project // "unknown"] | group_by(.) | map({key: .[0], value: length}) | from_entries' "$ERRORS_FILE" 2>/dev/null || echo "{}")

    # Top tags
    top_tags=$(jq '[.errors[].tags[]? // empty] | group_by(.) | map({tag: .[0], count: length}) | sort_by(-.count) | .[0:10]' "$ERRORS_FILE" 2>/dev/null || echo "[]")

    # Most used errors
    most_used=$(jq '[.errors[] | {id: .id, type: (.error.type // "Unknown"), usage: (.stats.usageCount // 0)}] | sort_by(-(.usage // 0)) | .[0:5]' "$ERRORS_FILE" 2>/dev/null || echo "[]")

    # Total usage
    total_usage=$(jq '[.errors[].stats.usageCount // 0] | add' "$ERRORS_FILE" 2>/dev/null || echo "0")

    # Average success rate
    avg_success=$(jq '[.errors[] | .stats.successRate // 1.0] | add / length' "$ERRORS_FILE" 2>/dev/null || echo "1.0")
else
    by_source="{}"
    by_type="{}"
    by_project="{}"
    top_tags="[]"
    most_used="[]"
    total_usage=0
    avg_success=1.0
fi

# Calculate match rate
if [[ "$total_searches" -gt 0 ]]; then
    match_rate=$(echo "scale=2; $total_matches * 100 / $total_searches" | bc 2>/dev/null || echo "0")
else
    match_rate="N/A"
fi

if [[ "$FORMAT" == "json" ]]; then
    jq -n \
        --argjson totalErrors "$total_errors" \
        --argjson totalSearches "$total_searches" \
        --argjson totalMatches "$total_matches" \
        --arg matchRate "$match_rate" \
        --argjson totalUsage "${total_usage:-0}" \
        --argjson avgSuccess "${avg_success:-1.0}" \
        --arg lastUpdated "$last_updated" \
        --argjson bySource "$by_source" \
        --argjson byType "$by_type" \
        --argjson byProject "$by_project" \
        --argjson topTags "$top_tags" \
        --argjson mostUsed "$most_used" \
        '{
            totalErrors: $totalErrors,
            totalSearches: $totalSearches,
            totalMatches: $totalMatches,
            matchRate: $matchRate,
            totalUsage: $totalUsage,
            avgSuccessRate: $avgSuccess,
            lastUpdated: $lastUpdated,
            bySource: $bySource,
            byType: $byType,
            byProject: $byProject,
            topTags: $topTags,
            mostUsed: $mostUsed
        }'
    exit 0
fi

# Text output
echo "Error Memory Statistics"
echo "========================"
echo ""

echo "OVERVIEW"
echo "--------"
echo "Total Errors:     $total_errors"
echo "Total Searches:   $total_searches"
echo "Total Matches:    $total_matches"
echo "Match Rate:       ${match_rate}%"
echo "Total Usage:      ${total_usage:-0} times"
echo "Avg Success Rate: ${avg_success:-1.0}"
echo "Last Updated:     $last_updated"
echo ""

if [[ "$total_errors" -gt 0 ]]; then
    echo "BY ERROR TYPE"
    echo "-------------"
    echo "$by_type" | jq -r 'to_entries | sort_by(-.value) | .[] | "  \(.key): \(.value)"'
    echo ""

    echo "BY SOURCE"
    echo "---------"
    echo "$by_source" | jq -r 'to_entries | sort_by(-.value) | .[] | "  \(.key): \(.value)"'
    echo ""

    echo "BY PROJECT"
    echo "----------"
    echo "$by_project" | jq -r 'to_entries | sort_by(-.value) | .[0:5] | .[] | "  \(.key): \(.value)"'
    echo ""

    echo "TOP TAGS"
    echo "--------"
    echo "$top_tags" | jq -r '.[] | "  \(.tag): \(.count)"'
    echo ""

    echo "MOST USED SOLUTIONS"
    echo "-------------------"
    echo "$most_used" | jq -r '.[] | "  \(.id) (\(.type)): \(.usage)x"'
    echo ""
fi

echo "========================"
echo "Commands:"
echo "  List errors: /error:list"
echo "  Search: /error:search <query>"
