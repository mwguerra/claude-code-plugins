#!/bin/bash
# Obsidian Vault Plugin - Update an existing note

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
NOTE_PATH=""
NEW_TITLE=""
NEW_DESCRIPTION=""
ADD_TAGS=""
ADD_RELATED=""
APPEND_CONTENT=""
SHOW_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title|-t)
            NEW_TITLE="$2"
            shift 2
            ;;
        --description|-d)
            NEW_DESCRIPTION="$2"
            shift 2
            ;;
        --add-tags)
            ADD_TAGS="$2"
            shift 2
            ;;
        --add-related|-r)
            ADD_RELATED="$2"
            shift 2
            ;;
        --append)
            APPEND_CONTENT="$2"
            shift 2
            ;;
        --show)
            SHOW_ONLY=true
            shift
            ;;
        *)
            if [[ -z "$NOTE_PATH" ]]; then
                NOTE_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)

if [[ -z "$NOTE_PATH" ]]; then
    echo "ERROR: Note path or title required"
    echo "Usage: update-note.sh <path-or-title> [--title \"...\"] [--description \"...\"] [--add-tags \"tag1,tag2\"]"
    exit 1
fi

# Find the note
FILE_PATH=""

# Check if it's a direct path
if [[ -f "$VAULT_PATH/$NOTE_PATH" ]]; then
    FILE_PATH="$VAULT_PATH/$NOTE_PATH"
elif [[ -f "$VAULT_PATH/$NOTE_PATH.md" ]]; then
    FILE_PATH="$VAULT_PATH/$NOTE_PATH.md"
else
    # Search by title
    FOUND=$(find "$VAULT_PATH" -name "*.md" -type f | while read -r file; do
        title=$(get_frontmatter_value "$file" "title")
        if echo "$title" | grep -qi "^$NOTE_PATH$"; then
            echo "$file"
            break
        fi
    done | head -1)

    if [[ -n "$FOUND" ]]; then
        FILE_PATH="$FOUND"
    else
        # Fuzzy search
        FOUND=$(find "$VAULT_PATH" -name "*.md" -type f | while read -r file; do
            title=$(get_frontmatter_value "$file" "title")
            if echo "$title" | grep -qi "$NOTE_PATH"; then
                echo "$file"
            fi
        done | head -1)

        if [[ -n "$FOUND" ]]; then
            FILE_PATH="$FOUND"
        fi
    fi
fi

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    echo "ERROR: Note not found: $NOTE_PATH"
    echo ""
    echo "Try searching: /obsidian:search $NOTE_PATH"
    exit 1
fi

REL_PATH="${FILE_PATH#$VAULT_PATH/}"
echo "Found: $REL_PATH"
echo ""

if [[ "$SHOW_ONLY" == true ]]; then
    echo "Current content:"
    echo "----------------"
    cat "$FILE_PATH"
    exit 0
fi

# Track if any changes were made
CHANGES_MADE=false

# Update title
if [[ -n "$NEW_TITLE" ]]; then
    sed -i "s/^title:.*$/title: \"$NEW_TITLE\"/" "$FILE_PATH"
    echo "Updated title: $NEW_TITLE"
    CHANGES_MADE=true
fi

# Update description
if [[ -n "$NEW_DESCRIPTION" ]]; then
    sed -i "s/^description:.*$/description: \"$NEW_DESCRIPTION\"/" "$FILE_PATH"
    echo "Updated description: $NEW_DESCRIPTION"
    CHANGES_MADE=true
fi

# Add tags
if [[ -n "$ADD_TAGS" ]]; then
    current_tags=$(get_frontmatter_value "$FILE_PATH" "tags")
    # Remove brackets and clean up
    current_tags=$(echo "$current_tags" | sed 's/^\[//' | sed 's/\]$//')

    if [[ -z "$current_tags" ]] || [[ "$current_tags" == "[]" ]]; then
        all_tags="$ADD_TAGS"
    else
        all_tags="$current_tags, $ADD_TAGS"
    fi

    # Format tags as quoted strings
    formatted_tags=""
    IFS=',' read -ra TAG_ARRAY <<< "$all_tags"
    for tag in "${TAG_ARRAY[@]}"; do
        # Remove surrounding whitespace and quotes
        tag=$(echo "$tag" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')
        if [[ -n "$tag" ]]; then
            if [[ -n "$formatted_tags" ]]; then
                formatted_tags="$formatted_tags, \"$tag\""
            else
                formatted_tags="\"$tag\""
            fi
        fi
    done

    sed -i "s/^tags:.*$/tags: [$formatted_tags]/" "$FILE_PATH"
    echo "Updated tags: [$formatted_tags]"
    CHANGES_MADE=true
fi

# Add related links
if [[ -n "$ADD_RELATED" ]]; then
    IFS=',' read -ra RELATED_ARRAY <<< "$ADD_RELATED"
    for rel in "${RELATED_ARRAY[@]}"; do
        rel=$(echo "$rel" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        add_related_link "$FILE_PATH" "$rel"
        echo "Added related: [[$rel]]"
    done
    CHANGES_MADE=true
fi

# Append content
if [[ -n "$APPEND_CONTENT" ]]; then
    echo "" >> "$FILE_PATH"
    echo "$APPEND_CONTENT" >> "$FILE_PATH"
    echo "Appended content"
    CHANGES_MADE=true
fi

# Update the updated date if any changes were made
if [[ "$CHANGES_MADE" == true ]]; then
    update_frontmatter_date "$FILE_PATH"
    echo ""
    echo "Updated: $REL_PATH"
    echo ""
    echo "Current frontmatter:"
    sed -n '/^---$/,/^---$/p' "$FILE_PATH"
else
    echo "No changes specified. Use options to update:"
    echo "  --title \"New Title\""
    echo "  --description \"New description\""
    echo "  --add-tags \"tag1,tag2\""
    echo "  --add-related \"path/to/note\""
    echo "  --append \"Content to add\""
    echo "  --show (view current content)"
fi
