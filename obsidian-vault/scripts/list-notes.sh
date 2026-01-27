#!/bin/bash
# Obsidian Vault Plugin - List notes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
CATEGORY=""
SORT_BY="updated"  # updated, created, title
LIMIT=50
SHOW_STATS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sort|-s)
            SORT_BY="$2"
            shift 2
            ;;
        --limit|-n)
            LIMIT="$2"
            shift 2
            ;;
        --stats)
            SHOW_STATS=true
            shift
            ;;
        *)
            if [[ -z "$CATEGORY" ]]; then
                CATEGORY="$1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)

# Set search path
if [[ -n "$CATEGORY" ]]; then
    SEARCH_PATH="$VAULT_PATH/$CATEGORY"
    if [[ ! -d "$SEARCH_PATH" ]]; then
        echo "ERROR: Category not found: $CATEGORY"
        echo ""
        echo "Available categories:"
        ls -1 "$VAULT_PATH" | grep -v "^_" | grep -v "^\." | sed 's/^/  /'
        exit 1
    fi
    echo "Notes in: $CATEGORY"
else
    SEARCH_PATH="$VAULT_PATH"
    echo "All notes in vault"
fi
echo ""

# Show stats if requested
if [[ "$SHOW_STATS" == true ]]; then
    total=$(find "$SEARCH_PATH" -name "*.md" -type f | wc -l)
    echo "Statistics:"
    echo "  Total notes: $total"

    if [[ -z "$CATEGORY" ]]; then
        echo "  By category:"
        for dir in "$VAULT_PATH"/*/; do
            if [[ -d "$dir" ]]; then
                dir_name=$(basename "$dir")
                count=$(find "$dir" -name "*.md" -type f 2>/dev/null | wc -l)
                if [[ $count -gt 0 ]]; then
                    printf "    %-20s %d\n" "$dir_name" "$count"
                fi
            fi
        done
    fi
    echo ""
fi

echo "Notes (sorted by $SORT_BY):"
echo "----------------------------"

# Create temp file for sorting
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Collect note info
find "$SEARCH_PATH" -name "*.md" -type f | while read -r file; do
    # Skip hidden files and archive
    [[ "$(basename "$file")" == .* ]] && continue
    [[ "$file" == *"/_archive/"* ]] && continue

    title=$(get_frontmatter_value "$file" "title")
    title="${title:-$(basename "$file" .md)}"
    updated=$(get_frontmatter_value "$file" "updated")
    created=$(get_frontmatter_value "$file" "created")
    tags=$(get_frontmatter_value "$file" "tags")
    rel_path="${file#$VAULT_PATH/}"

    case "$SORT_BY" in
        updated)
            sort_key="${updated:-0000-00-00}"
            ;;
        created)
            sort_key="${created:-0000-00-00}"
            ;;
        title)
            sort_key="$title"
            ;;
    esac

    echo "$sort_key|$rel_path|$title|$updated|$tags" >> "$TEMP_FILE"
done

# Sort and display
sort -t'|' -k1 -r "$TEMP_FILE" | head -n "$LIMIT" | while IFS='|' read -r _ rel_path title updated tags; do
    echo "[$title]"
    echo "  Path: $rel_path"
    [[ -n "$updated" ]] && echo "  Updated: $updated"
    [[ -n "$tags" ]] && echo "  Tags: $tags"
    echo ""
done

echo "----------------------------"
total_shown=$(sort -t'|' -k1 -r "$TEMP_FILE" | head -n "$LIMIT" | wc -l)
total_all=$(wc -l < "$TEMP_FILE")
echo "Showing $total_shown of $total_all notes"
[[ $total_all -gt $LIMIT ]] && echo "Use --limit to show more"
