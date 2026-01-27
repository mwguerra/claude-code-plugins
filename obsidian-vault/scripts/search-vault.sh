#!/bin/bash
# Obsidian Vault Plugin - Search notes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
QUERY=""
SEARCH_TYPE="all"  # all, title, content, tag
CATEGORY=""
LIMIT=20

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title|-t)
            SEARCH_TYPE="title"
            shift
            ;;
        --content|-c)
            SEARCH_TYPE="content"
            shift
            ;;
        --tag)
            SEARCH_TYPE="tag"
            shift
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --limit|-n)
            LIMIT="$2"
            shift 2
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

# Validate
VAULT_PATH=$(check_vault_configured)

if [[ -z "$QUERY" ]]; then
    echo "ERROR: Search query required"
    echo "Usage: search-vault.sh <query> [--title|--content|--tag] [--category <cat>]"
    exit 1
fi

# Set search path
SEARCH_PATH="$VAULT_PATH"
if [[ -n "$CATEGORY" ]]; then
    SEARCH_PATH="$VAULT_PATH/$CATEGORY"
    if [[ ! -d "$SEARCH_PATH" ]]; then
        echo "ERROR: Category not found: $CATEGORY"
        exit 1
    fi
fi

echo "Searching for: $QUERY"
echo "Search type: $SEARCH_TYPE"
if [[ -n "$CATEGORY" ]]; then
    echo "Category: $CATEGORY"
fi
echo ""
echo "Results:"
echo "--------"

count=0

case "$SEARCH_TYPE" in
    title)
        # Search in titles only
        find "$SEARCH_PATH" -name "*.md" -type f | while read -r file; do
            [[ "$count" -ge "$LIMIT" ]] && break
            title=$(get_frontmatter_value "$file" "title")
            if echo "$title" | grep -qi "$QUERY"; then
                rel_path="${file#$VAULT_PATH/}"
                echo "[$title]"
                echo "  Path: $rel_path"
                desc=$(get_frontmatter_value "$file" "description")
                [[ -n "$desc" ]] && echo "  Desc: $desc"
                tags=$(get_frontmatter_value "$file" "tags")
                [[ -n "$tags" ]] && echo "  Tags: $tags"
                echo ""
                ((count++)) || true
            fi
        done
        ;;

    content)
        # Search in content only
        grep -ril "$QUERY" "$SEARCH_PATH" --include="*.md" 2>/dev/null | head -n "$LIMIT" | while read -r file; do
            rel_path="${file#$VAULT_PATH/}"
            title=$(get_frontmatter_value "$file" "title")
            title="${title:-$(basename "$file" .md)}"
            echo "[$title]"
            echo "  Path: $rel_path"
            # Show matching lines
            echo "  Matches:"
            grep -in "$QUERY" "$file" 2>/dev/null | head -3 | sed 's/^/    /'
            echo ""
        done
        ;;

    tag)
        # Search by tag
        grep -rl "tags:.*$QUERY" "$SEARCH_PATH" --include="*.md" 2>/dev/null | head -n "$LIMIT" | while read -r file; do
            rel_path="${file#$VAULT_PATH/}"
            title=$(get_frontmatter_value "$file" "title")
            title="${title:-$(basename "$file" .md)}"
            tags=$(get_frontmatter_value "$file" "tags")
            echo "[$title]"
            echo "  Path: $rel_path"
            echo "  Tags: $tags"
            echo ""
        done
        ;;

    all|*)
        # Search everywhere
        {
            # First search titles
            find "$SEARCH_PATH" -name "*.md" -type f | while read -r file; do
                title=$(get_frontmatter_value "$file" "title")
                if echo "$title" | grep -qi "$QUERY"; then
                    echo "TITLE|$file|$title"
                fi
            done

            # Then search content
            grep -ril "$QUERY" "$SEARCH_PATH" --include="*.md" 2>/dev/null | while read -r file; do
                echo "CONTENT|$file|"
            done

            # Then search tags
            grep -rl "tags:.*$QUERY" "$SEARCH_PATH" --include="*.md" 2>/dev/null | while read -r file; do
                echo "TAG|$file|"
            done
        } | sort -u -t'|' -k2 | head -n "$LIMIT" | while IFS='|' read -r match_type file _; do
            rel_path="${file#$VAULT_PATH/}"
            title=$(get_frontmatter_value "$file" "title")
            title="${title:-$(basename "$file" .md)}"
            desc=$(get_frontmatter_value "$file" "description")
            tags=$(get_frontmatter_value "$file" "tags")

            echo "[$title]"
            echo "  Path: $rel_path"
            [[ -n "$desc" ]] && echo "  Desc: $desc"
            [[ -n "$tags" ]] && echo "  Tags: $tags"
            echo ""
        done
        ;;
esac

echo "--------"
echo "Tip: Use --title, --content, or --tag to narrow search"
