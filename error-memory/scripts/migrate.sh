#!/bin/bash
# Error Memory Plugin - Migrate from solved-errors.md
# Handles the actual format used in ~/.claude/solved-errors.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"
OLD_FILE="$HOME/.claude/solved-errors.md"

# Check dependencies
check_jq

# Parse arguments
DRY_RUN=false
SOURCE_FILE="$OLD_FILE"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --file|-f)
            SOURCE_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: migrate.sh [OPTIONS]"
            echo ""
            echo "Migrates errors from solved-errors.md format to JSON database."
            echo ""
            echo "Options:"
            echo "  --file, -f   Source file to migrate (default: ~/.claude/solved-errors.md)"
            echo "  --dry-run    Parse and show what would be migrated without saving"
            echo "  --help       Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "ERROR: Source file not found: $SOURCE_FILE"
    exit 1
fi

# Initialize if needed
if [[ ! -f "$ERRORS_FILE" ]]; then
    bash "$SCRIPT_DIR/init.sh" >/dev/null
fi

echo "Error Memory Migration"
echo "======================"
echo ""
echo "Source: $SOURCE_FILE"
echo "Target: $ERRORS_FILE"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN - No changes will be made"
    echo ""
fi

# Variables to track current error being parsed
migrated=0
skipped=0
current_project=""
current_folder=""
current_error=""
current_about=""
current_why=""
current_context=""
current_solution=""
current_rationale=""
current_tags=""
in_error_block=false
in_code_block=false
current_section=""
section_content=""

# Function to process a completed error entry
process_error() {
    # Skip if no error message
    if [[ -z "$current_error" ]]; then
        return
    fi

    # Build tags array
    local tags_json="[]"
    if [[ -n "$current_tags" ]]; then
        tags_json=$(echo "$current_tags" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/`//g' | grep -v '^$' | jq -R . | jq -s .)
    fi

    # Combine about and context into whatHappened
    local what_happened=""
    [[ -n "$current_about" ]] && what_happened="$current_about"
    [[ -n "$current_context" ]] && [[ -n "$what_happened" ]] && what_happened="$what_happened. $current_context"
    [[ -n "$current_context" ]] && [[ -z "$what_happened" ]] && what_happened="$current_context"

    # Use why as cause, default to about if no why
    local cause="${current_why:-$current_about}"
    if [[ -z "$cause" ]]; then
        cause="Not documented"
    fi

    # Use solution, default to a placeholder
    local solution="${current_solution:-Not documented}"

    # Build JSON input for log-error.sh
    local input_json
    input_json=$(jq -n \
        --arg errorMessage "$current_error" \
        --arg project "${current_project:-unknown}" \
        --arg projectPath "${current_folder:-}" \
        --arg source "user" \
        --arg whatHappened "$what_happened" \
        --arg cause "$cause" \
        --arg solution "$solution" \
        --arg rationale "${current_rationale:-}" \
        --argjson tags "$tags_json" \
        '{
            errorMessage: $errorMessage,
            project: $project,
            projectPath: $projectPath,
            source: $source,
            whatHappened: $whatHappened,
            cause: $cause,
            solution: $solution,
            rationale: $rationale,
            tags: $tags
        }')

    # Display or execute
    local error_preview="${current_error:0:60}"
    [[ ${#current_error} -gt 60 ]] && error_preview="${error_preview}..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [WOULD MIGRATE] ${current_project:-unknown}: $error_preview"
        migrated=$((migrated + 1))
    else
        # Call log-error.sh
        local result
        if result=$(bash "$SCRIPT_DIR/log-error.sh" --json "$input_json" 2>&1); then
            if echo "$result" | grep -q "WARNING: Similar error"; then
                echo "  [UPDATED] ${current_project:-unknown}: $error_preview"
            else
                echo "  [OK] ${current_project:-unknown}: $error_preview"
            fi
            migrated=$((migrated + 1))
        else
            echo "  [FAIL] $error_preview - $result"
            skipped=$((skipped + 1))
        fi
    fi
}

# Reset current error variables
reset_error() {
    current_error=""
    current_about=""
    current_why=""
    current_context=""
    current_solution=""
    current_rationale=""
    current_tags=""
    current_section=""
    section_content=""
    in_code_block=false
}

# Store section content into appropriate variable
store_section() {
    case "$current_section" in
        "error")
            [[ -z "$current_error" ]] && current_error="$section_content"
            ;;
        "about")
            current_about="$section_content"
            ;;
        "why")
            current_why="$section_content"
            ;;
        "context")
            current_context="$section_content"
            ;;
        "solution")
            current_solution="$section_content"
            ;;
        "rationale")
            current_rationale="$section_content"
            ;;
        "tags")
            current_tags="$section_content"
            ;;
    esac
    section_content=""
}

echo "Processing..."
echo ""

while IFS= read -r line || [[ -n "$line" ]]; do
    # Handle code blocks
    if [[ "$line" =~ ^\`\`\` ]]; then
        if [[ "$in_code_block" == "true" ]]; then
            in_code_block=false
        else
            in_code_block=true
        fi
        # Include code block content for error messages
        if [[ "$current_section" == "error" ]]; then
            continue
        fi
        continue
    fi

    # If in code block and parsing error section, accumulate
    if [[ "$in_code_block" == "true" ]]; then
        if [[ "$current_section" == "error" ]]; then
            [[ -n "$section_content" ]] && section_content="$section_content"$'\n'"$line" || section_content="$line"
        fi
        continue
    fi

    # New major section (## header) - process previous error and start new one
    if [[ "$line" =~ ^##[[:space:]]+ ]] && [[ ! "$line" =~ ^###[[:space:]]+ ]]; then
        # Store any pending section content
        store_section

        # Process previous error if exists
        if [[ "$in_error_block" == "true" ]]; then
            process_error
        fi

        # Start new error block
        reset_error
        in_error_block=true

        # Try to extract project from header if format is "## Date - Title"
        # We'll rely on **Project:** line for actual project name
        continue
    fi

    # Skip if not in error block
    [[ "$in_error_block" != "true" ]] && continue

    # Parse **Project:** or **Projeto:**
    if [[ "$line" =~ ^\*\*Projec?t[oa]?:\*\*[[:space:]]*(.*) ]]; then
        current_project="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse **Folder:** or **Pasta:**
    if [[ "$line" =~ ^\*\*Folder:\*\*[[:space:]]*(.*) ]] || [[ "$line" =~ ^\*\*Pasta:\*\*[[:space:]]*(.*) ]]; then
        current_folder="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse section headers (### headers)
    if [[ "$line" =~ ^###[[:space:]]+ ]]; then
        # Store previous section content
        store_section

        # Determine new section type
        header_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')

        if [[ "$header_lower" =~ error.*message ]]; then
            current_section="error"
        elif [[ "$header_lower" =~ what.*is.*about ]] || [[ "$header_lower" =~ what.*it.*about ]]; then
            current_section="about"
        elif [[ "$header_lower" =~ why.*happened ]] || [[ "$header_lower" =~ por.*que ]]; then
            current_section="why"
        elif [[ "$header_lower" =~ context ]] || [[ "$header_lower" =~ contexto ]]; then
            current_section="context"
        elif [[ "$header_lower" =~ how.*solved ]] || [[ "$header_lower" =~ solution ]] || [[ "$header_lower" =~ como.*resolv ]]; then
            current_section="solution"
        elif [[ "$header_lower" =~ why.*works ]] || [[ "$header_lower" =~ rationale ]] || [[ "$header_lower" =~ porque.*funciona ]]; then
            current_section="rationale"
        elif [[ "$header_lower" =~ tags ]]; then
            current_section="tags"
        else
            current_section=""
        fi
        continue
    fi

    # Parse compact format: **Error Message:** or **Erro:**
    if [[ "$line" =~ ^\*\*Error\ Message:\*\*[[:space:]]*(.*) ]] || [[ "$line" =~ ^\*\*Erro:\*\*[[:space:]]*(.*) ]]; then
        store_section
        current_error="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse compact format: **What it's about:** or **Sobre o erro:**
    if [[ "$line" =~ ^\*\*What.*about:\*\*[[:space:]]*(.*) ]] || [[ "$line" =~ ^\*\*Sobre.*erro:\*\*[[:space:]]*(.*) ]]; then
        current_about="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse compact format: **Why it happened:**
    if [[ "$line" =~ ^\*\*Why.*happened:\*\*[[:space:]]*(.*) ]]; then
        current_why="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse compact format: **Context:**
    if [[ "$line" =~ ^\*\*Context[o]?:\*\*[[:space:]]*(.*) ]]; then
        current_context="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse compact format: **Solution:** or **Como foi resolvido:**
    if [[ "$line" =~ ^\*\*Solution:\*\*[[:space:]]*(.*) ]] || [[ "$line" =~ ^\*\*Como.*resolv.*:\*\*[[:space:]]*(.*) ]]; then
        current_solution="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse compact format: **Why it works:** or **Porque funciona:**
    if [[ "$line" =~ ^\*\*Why.*works:\*\*[[:space:]]*(.*) ]] || [[ "$line" =~ ^\*\*Porque.*funciona:\*\*[[:space:]]*(.*) ]]; then
        current_rationale="${BASH_REMATCH[1]}"
        continue
    fi

    # Parse Tags line
    if [[ "$line" =~ ^\*\*Tags:\*\*[[:space:]]*(.*) ]] || [[ "$line" =~ ^Tags:[[:space:]]*(.*) ]]; then
        current_tags="${BASH_REMATCH[1]}"
        continue
    fi

    # Accumulate section content (non-empty lines only)
    if [[ -n "$current_section" ]] && [[ -n "$line" ]] && [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
        # Skip divider lines
        [[ "$line" =~ ^---+ ]] && continue
        [[ "$line" =~ ^\| ]] && continue  # Skip tables

        [[ -n "$section_content" ]] && section_content="$section_content "
        section_content="$section_content$line"
    fi
done < "$SOURCE_FILE"

# Process final error
store_section
if [[ "$in_error_block" == "true" ]]; then
    process_error
fi

echo ""
echo "======================"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN COMPLETE"
    echo "Would migrate: $migrated errors"
    echo "Would skip: $skipped errors"
    echo ""
    echo "Run without --dry-run to perform migration."
else
    echo "Migration Complete!"
    echo "Migrated: $migrated errors"
    echo "Skipped: $skipped errors"
    echo ""
    echo "View stats: /error:stats"
    echo "List errors: /error:list"
fi
