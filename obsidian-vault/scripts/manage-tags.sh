#!/bin/bash
# Obsidian Vault Plugin - Manage tags

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
ACTION="list"  # list, stats, find
TAG=""
LIMIT=50

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stats|-s)
            ACTION="stats"
            shift
            ;;
        --find|-f)
            ACTION="find"
            TAG="$2"
            shift 2
            ;;
        --limit|-n)
            LIMIT="$2"
            shift 2
            ;;
        *)
            if [[ -z "$TAG" ]]; then
                TAG="$1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)

case "$ACTION" in
    list)
        echo "All Tags in Vault"
        echo "================="
        echo ""

        # Extract and list all unique tags
        find "$VAULT_PATH" -name "*.md" -type f -exec grep -h "^tags:" {} \; 2>/dev/null | \
            sed 's/tags:[[:space:]]*\[//' | sed 's/\]//' | tr ',' '\n' | \
            sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | \
            sort -u | grep -v "^$" | head -n "$LIMIT" | while read -r tag; do
                echo "  $tag"
            done

        echo ""
        total=$(find "$VAULT_PATH" -name "*.md" -type f -exec grep -h "^tags:" {} \; 2>/dev/null | \
            sed 's/tags:[[:space:]]*\[//' | sed 's/\]//' | tr ',' '\n' | \
            sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | \
            sort -u | grep -v "^$" | wc -l)
        echo "Total unique tags: $total"
        ;;

    stats)
        echo "Tag Usage Statistics"
        echo "===================="
        echo ""
        printf "%-30s %s\n" "TAG" "COUNT"
        printf "%-30s %s\n" "---" "-----"

        find "$VAULT_PATH" -name "*.md" -type f -exec grep -h "^tags:" {} \; 2>/dev/null | \
            sed 's/tags:[[:space:]]*\[//' | sed 's/\]//' | tr ',' '\n' | \
            sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | \
            sort | grep -v "^$" | uniq -c | sort -rn | head -n "$LIMIT" | \
            while read -r count tag; do
                printf "%-30s %d\n" "$tag" "$count"
            done

        echo ""
        ;;

    find)
        if [[ -z "$TAG" ]]; then
            echo "ERROR: Tag required for --find"
            echo "Usage: manage-tags.sh --find <tag>"
            exit 1
        fi

        echo "Notes tagged with: $TAG"
        echo "========================"
        echo ""

        grep -rl "tags:.*$TAG" "$VAULT_PATH" --include="*.md" 2>/dev/null | head -n "$LIMIT" | while read -r file; do
            rel_path="${file#$VAULT_PATH/}"
            title=$(get_frontmatter_value "$file" "title")
            title="${title:-$(basename "$file" .md)}"
            echo "[$title]"
            echo "  Path: $rel_path"
            echo ""
        done
        ;;
esac
