#!/bin/bash
# Obsidian Vault Plugin - Link related notes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
NOTE1=""
NOTE2=""
BIDIRECTIONAL=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --one-way)
            BIDIRECTIONAL=false
            shift
            ;;
        *)
            if [[ -z "$NOTE1" ]]; then
                NOTE1="$1"
            elif [[ -z "$NOTE2" ]]; then
                NOTE2="$1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)

if [[ -z "$NOTE1" ]] || [[ -z "$NOTE2" ]]; then
    echo "ERROR: Two notes required"
    echo "Usage: link-notes.sh <note1> <note2> [--one-way]"
    exit 1
fi

# Function to resolve note path
resolve_note() {
    local note="$1"
    local file_path=""

    # Check if it's a direct path
    if [[ -f "$VAULT_PATH/$note" ]]; then
        echo "$VAULT_PATH/$note"
        return
    fi

    if [[ -f "$VAULT_PATH/$note.md" ]]; then
        echo "$VAULT_PATH/$note.md"
        return
    fi

    # Search by title
    local found
    found=$(find "$VAULT_PATH" -name "*.md" -type f | while read -r file; do
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
    found=$(find "$VAULT_PATH" -name "*.md" -type f | while read -r file; do
        title=$(get_frontmatter_value "$file" "title")
        if echo "$title" | grep -qi "$note"; then
            echo "$file"
        fi
    done | head -1)

    echo "$found"
}

# Resolve both notes
FILE1=$(resolve_note "$NOTE1")
FILE2=$(resolve_note "$NOTE2")

if [[ -z "$FILE1" ]] || [[ ! -f "$FILE1" ]]; then
    echo "ERROR: Note not found: $NOTE1"
    exit 1
fi

if [[ -z "$FILE2" ]] || [[ ! -f "$FILE2" ]]; then
    echo "ERROR: Note not found: $NOTE2"
    exit 1
fi

REL1="${FILE1#$VAULT_PATH/}"
REL2="${FILE2#$VAULT_PATH/}"

# Remove .md extension for wiki links
LINK1="${REL1%.md}"
LINK2="${REL2%.md}"

echo "Linking notes:"
echo "  1: $REL1"
echo "  2: $REL2"
echo ""

# Add link from note1 to note2
add_related_link "$FILE1" "$LINK2"
echo "Added [[$LINK2]] to $REL1"

# Add reverse link if bidirectional
if [[ "$BIDIRECTIONAL" == true ]]; then
    add_related_link "$FILE2" "$LINK1"
    echo "Added [[$LINK1]] to $REL2"
fi

echo ""
echo "Links created successfully!"
