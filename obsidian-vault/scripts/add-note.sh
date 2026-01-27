#!/bin/bash
# Obsidian Vault Plugin - Add a new note

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
CATEGORY=""
TITLE=""
DESCRIPTION=""
TAGS=""
RELATED=""
CONTENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --category|-c)
            CATEGORY="$2"
            shift 2
            ;;
        --title|-t)
            TITLE="$2"
            shift 2
            ;;
        --description|-d)
            DESCRIPTION="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --related|-r)
            RELATED="$2"
            shift 2
            ;;
        --content)
            CONTENT="$2"
            shift 2
            ;;
        *)
            # First positional arg is category, rest is title
            if [[ -z "$CATEGORY" ]]; then
                CATEGORY="$1"
            elif [[ -z "$TITLE" ]]; then
                TITLE="$1"
            else
                TITLE="$TITLE $1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)

if [[ -z "$CATEGORY" ]]; then
    echo "ERROR: Category required"
    echo ""
    echo "Available categories:"
    echo "  - projects"
    echo "  - technologies"
    echo "  - claude-code"
    echo "  - ideas"
    echo "  - personal"
    echo "  - todo"
    echo "  - references"
    echo ""
    echo "Usage: add-note.sh <category> <title> [--description \"...\"] [--tags \"tag1,tag2\"]"
    exit 1
fi

if [[ -z "$TITLE" ]]; then
    echo "ERROR: Title required"
    echo "Usage: add-note.sh <category> <title> [--description \"...\"] [--tags \"tag1,tag2\"]"
    exit 1
fi

# Validate category
VALID_CATEGORIES="projects technologies claude-code ideas personal todo references"
if ! echo "$VALID_CATEGORIES" | grep -qw "$CATEGORY"; then
    # Check for subcategories
    case "$CATEGORY" in
        claude-code/agents|claude-code/hooks|claude-code/skills|claude-code/tools)
            # Valid subcategory
            ;;
        *)
            echo "ERROR: Invalid category: $CATEGORY"
            echo ""
            echo "Valid categories: $VALID_CATEGORIES"
            echo "Valid subcategories: claude-code/agents, claude-code/hooks, claude-code/skills, claude-code/tools"
            exit 1
            ;;
    esac
fi

# Generate filename
SLUG=$(slugify "$TITLE")
DATE=$(get_date)
FILENAME="$SLUG.md"
FILE_PATH="$VAULT_PATH/$CATEGORY/$FILENAME"

# Check if file already exists
if [[ -f "$FILE_PATH" ]]; then
    echo "ERROR: Note already exists: $FILE_PATH"
    echo "Use /obsidian:update to modify existing notes"
    exit 1
fi

# Use title as description if not provided
DESCRIPTION="${DESCRIPTION:-$TITLE}"

# Add category to tags
if [[ -n "$TAGS" ]]; then
    TAGS="$TAGS, $CATEGORY"
else
    TAGS="$CATEGORY"
fi

# Create the note
ensure_dir "$(dirname "$FILE_PATH")"

{
    create_frontmatter "$TITLE" "$DESCRIPTION" "$TAGS" "$RELATED"
    echo ""
    echo "# $TITLE"
    echo ""
    if [[ -n "$CONTENT" ]]; then
        echo "$CONTENT"
    else
        echo "<!-- Add your content here -->"
        echo ""
    fi
} > "$FILE_PATH"

echo "Created: $FILE_PATH"
echo ""
echo "Frontmatter:"
head -10 "$FILE_PATH"
