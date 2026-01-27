#!/bin/bash
# Obsidian Vault Plugin - Archive a note

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
NOTE=""
RESTORE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --restore|-r)
            RESTORE=true
            shift
            ;;
        *)
            if [[ -z "$NOTE" ]]; then
                NOTE="$1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)
ARCHIVE_DIR="$VAULT_PATH/_archive"
ensure_dir "$ARCHIVE_DIR"

if [[ -z "$NOTE" ]]; then
    echo "ERROR: Note path or title required"
    echo "Usage: archive-note.sh <note> [--restore]"
    exit 1
fi

# Function to resolve note path
resolve_note() {
    local note="$1"
    local search_path="$2"

    # Check if it's a direct path
    if [[ -f "$search_path/$note" ]]; then
        echo "$search_path/$note"
        return
    fi

    if [[ -f "$search_path/$note.md" ]]; then
        echo "$search_path/$note.md"
        return
    fi

    # Search by title
    local found
    found=$(find "$search_path" -name "*.md" -type f | while read -r file; do
        title=$(get_frontmatter_value "$file" "title")
        if echo "$title" | grep -qi "^$note$"; then
            echo "$file"
            break
        fi
    done | head -1)

    if [[ -n "$found" ]]; then
        echo "$found"
        return
    fi

    # Fuzzy match
    found=$(find "$search_path" -name "*.md" -type f | while read -r file; do
        title=$(get_frontmatter_value "$file" "title")
        if echo "$title" | grep -qi "$note"; then
            echo "$file"
        fi
    done | head -1)

    echo "$found"
}

if [[ "$RESTORE" == true ]]; then
    # Restore from archive
    FILE=$(resolve_note "$NOTE" "$ARCHIVE_DIR")

    if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
        echo "ERROR: Note not found in archive: $NOTE"
        echo ""
        echo "Archived notes:"
        find "$ARCHIVE_DIR" -name "*.md" -type f | while read -r f; do
            title=$(get_frontmatter_value "$f" "title")
            echo "  - $title (${f#$ARCHIVE_DIR/})"
        done
        exit 1
    fi

    # Get original category from frontmatter or use default
    original_category=$(get_frontmatter_value "$FILE" "archived_from")
    original_category="${original_category:-references}"

    # Create target directory
    TARGET_DIR="$VAULT_PATH/$original_category"
    ensure_dir "$TARGET_DIR"

    # Move file back
    FILENAME=$(basename "$FILE")
    TARGET="$TARGET_DIR/$FILENAME"

    mv "$FILE" "$TARGET"

    # Remove archived_from tag
    sed -i '/^archived_from:/d' "$TARGET"

    # Update date
    update_frontmatter_date "$TARGET"

    echo "Restored: $FILENAME"
    echo "Location: $original_category/$FILENAME"

else
    # Archive note
    FILE=$(resolve_note "$NOTE" "$VAULT_PATH")

    if [[ -z "$FILE" ]] || [[ ! -f "$FILE" ]]; then
        echo "ERROR: Note not found: $NOTE"
        exit 1
    fi

    # Don't archive files already in archive
    if [[ "$FILE" == *"/_archive/"* ]]; then
        echo "ERROR: Note is already archived"
        exit 1
    fi

    REL_PATH="${FILE#$VAULT_PATH/}"
    ORIGINAL_CATEGORY=$(dirname "$REL_PATH")
    FILENAME=$(basename "$FILE")

    # Add archived_from to frontmatter
    sed -i "/^---$/,/^---$/ { /^updated:/a archived_from: $ORIGINAL_CATEGORY
    }" "$FILE"

    # Move to archive
    mv "$FILE" "$ARCHIVE_DIR/$FILENAME"

    # Update date
    update_frontmatter_date "$ARCHIVE_DIR/$FILENAME"

    echo "Archived: $REL_PATH"
    echo "Location: _archive/$FILENAME"
    echo ""
    echo "To restore: /obsidian:archive --restore \"$NOTE\""
fi
