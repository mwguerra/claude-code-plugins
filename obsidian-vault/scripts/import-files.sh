#!/bin/bash
# Obsidian Vault Plugin - Import files into the vault

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Parse arguments
SOURCE=""
TARGET_CATEGORY=""
ADD_FRONTMATTER=true
RECURSIVE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --to|-t)
            TARGET_CATEGORY="$2"
            shift 2
            ;;
        --no-frontmatter)
            ADD_FRONTMATTER=false
            shift
            ;;
        --recursive|-r)
            RECURSIVE=true
            shift
            ;;
        *)
            if [[ -z "$SOURCE" ]]; then
                SOURCE="$1"
            fi
            shift
            ;;
    esac
done

# Validate
VAULT_PATH=$(check_vault_configured)

if [[ -z "$SOURCE" ]]; then
    echo "ERROR: Source file or folder required"
    echo "Usage: import-files.sh <source> --to <category> [--recursive] [--no-frontmatter]"
    exit 1
fi

# Expand source path
if [[ "$SOURCE" != /* ]]; then
    SOURCE="$(pwd)/$SOURCE"
fi

if [[ ! -e "$SOURCE" ]]; then
    echo "ERROR: Source not found: $SOURCE"
    exit 1
fi

# Default category based on content type
if [[ -z "$TARGET_CATEGORY" ]]; then
    if [[ -f "$SOURCE" ]]; then
        case "$(basename "$SOURCE")" in
            README.md|readme.md)
                TARGET_CATEGORY="projects"
                ;;
            *.md)
                TARGET_CATEGORY="references"
                ;;
            *)
                TARGET_CATEGORY="references"
                ;;
        esac
    else
        TARGET_CATEGORY="references"
    fi
    echo "Auto-detected category: $TARGET_CATEGORY"
fi

TARGET_DIR="$VAULT_PATH/$TARGET_CATEGORY"
ensure_dir "$TARGET_DIR"

# Function to add frontmatter to a file
add_frontmatter_to_file() {
    local source_file="$1"
    local target_file="$2"

    # Get title from filename or first heading
    local title
    title=$(basename "$source_file" .md | sed 's/-/ /g' | sed 's/_/ /g')

    # Try to get title from first heading
    local first_heading
    first_heading=$(grep -m1 "^# " "$source_file" 2>/dev/null | sed 's/^# //')
    if [[ -n "$first_heading" ]]; then
        title="$first_heading"
    fi

    # Get description from first paragraph after heading
    local description="$title"

    # Determine tags from path
    local tags="imported"
    local source_dir
    source_dir=$(dirname "$source_file")
    if [[ "$source_dir" != "." ]]; then
        local dir_name
        dir_name=$(basename "$source_dir")
        tags="$tags, $dir_name"
    fi

    # Check if file already has frontmatter
    if has_frontmatter "$source_file"; then
        # Just copy the file, update the updated date
        cp "$source_file" "$target_file"
        update_frontmatter_date "$target_file"
        echo "Imported (existing frontmatter): $(basename "$target_file")"
    else
        # Add frontmatter
        {
            create_frontmatter "$title" "$description" "$tags" "" "$(get_date)"
            echo ""
            cat "$source_file"
        } > "$target_file"
        echo "Imported (added frontmatter): $(basename "$target_file")"
    fi
}

# Import single file
import_file() {
    local source_file="$1"
    local target_dir="$2"

    local filename
    filename=$(basename "$source_file")
    local target_file="$target_dir/$filename"

    # Handle non-markdown files
    if [[ "$filename" != *.md ]]; then
        cp "$source_file" "$target_file"
        echo "Copied (non-markdown): $filename"
        return
    fi

    if [[ "$ADD_FRONTMATTER" == true ]]; then
        add_frontmatter_to_file "$source_file" "$target_file"
    else
        cp "$source_file" "$target_file"
        echo "Copied: $filename"
    fi
}

# Import
echo "Importing to: $TARGET_CATEGORY"
echo ""

if [[ -f "$SOURCE" ]]; then
    # Single file
    import_file "$SOURCE" "$TARGET_DIR"
elif [[ -d "$SOURCE" ]]; then
    # Directory
    if [[ "$RECURSIVE" == true ]]; then
        find "$SOURCE" -type f -name "*.md" | while read -r file; do
            rel_path="${file#$SOURCE/}"
            target_subdir="$TARGET_DIR/$(dirname "$rel_path")"
            ensure_dir "$target_subdir"
            import_file "$file" "$target_subdir"
        done
    else
        for file in "$SOURCE"/*.md; do
            if [[ -f "$file" ]]; then
                import_file "$file" "$TARGET_DIR"
            fi
        done
    fi
fi

echo ""
echo "Import complete!"
echo "Files are in: $TARGET_DIR"
