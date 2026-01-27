#!/bin/bash
# Error Memory Plugin - Log a new error and its solution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"
source "$SCRIPT_DIR/lib/hash.sh"
source "$SCRIPT_DIR/lib/normalize.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"
INDEX_FILE="$CONFIG_DIR/index.json"
STATS_FILE="$CONFIG_DIR/stats.json"

# Check dependencies
check_jq

# Initialize if needed
if [[ ! -f "$ERRORS_FILE" ]]; then
    bash "$SCRIPT_DIR/init.sh" >/dev/null
fi

# Parse arguments - all should be JSON input
INPUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            INPUT="$2"
            shift 2
            ;;
        *)
            # If not --json flag, treat as JSON directly
            INPUT="$1"
            shift
            ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo "ERROR: JSON input required"
    echo ""
    echo "Usage: log-error.sh --json '<json>'"
    echo ""
    echo "Expected JSON structure:"
    cat << 'EOF'
{
  "errorMessage": "The full error message",
  "project": "project-name",
  "projectPath": "/path/to/project",
  "source": "bash|playwright|read|user|build|api|other",
  "whatHappened": "Context of what was happening",
  "cause": "Why the error occurred",
  "solution": "How it was fixed",
  "rationale": "Why the solution works",
  "fileChanged": "path/to/file.php (optional)",
  "codeBefore": "code before fix (optional)",
  "codeAfter": "code after fix (optional)",
  "tags": ["tag1", "tag2"]
}
EOF
    exit 1
fi

# Validate JSON
if ! echo "$INPUT" | jq . >/dev/null 2>&1; then
    echo "ERROR: Invalid JSON input"
    exit 1
fi

# Extract fields
error_message=$(echo "$INPUT" | jq -r '.errorMessage')
project=$(echo "$INPUT" | jq -r '.project // "unknown"')
project_path=$(echo "$INPUT" | jq -r '.projectPath // ""')
source=$(echo "$INPUT" | jq -r '.source // "other"')
what_happened=$(echo "$INPUT" | jq -r '.whatHappened // ""')
cause=$(echo "$INPUT" | jq -r '.cause')
solution=$(echo "$INPUT" | jq -r '.solution')
rationale=$(echo "$INPUT" | jq -r '.rationale // ""')
file_changed=$(echo "$INPUT" | jq -r '.fileChanged // ""')
code_before=$(echo "$INPUT" | jq -r '.codeBefore // ""')
code_after=$(echo "$INPUT" | jq -r '.codeAfter // ""')
tags=$(echo "$INPUT" | jq -c '.tags // []')

# Validate required fields
if [[ -z "$error_message" ]] || [[ "$error_message" == "null" ]]; then
    echo "ERROR: errorMessage is required"
    exit 1
fi

if [[ -z "$cause" ]] || [[ "$cause" == "null" ]]; then
    echo "ERROR: cause is required"
    exit 1
fi

if [[ -z "$solution" ]] || [[ "$solution" == "null" ]]; then
    echo "ERROR: solution is required"
    exit 1
fi

# Generate ID and process error
id=$(generate_id "err")
now=$(format_date)

# Normalize and hash
normalized=$(normalize_error "$error_message")
hash=$(sha256 "$normalized")
error_type=$(extract_error_type "$error_message")
keywords=$(extract_keywords "$error_message")
keywords_json=$(echo "$keywords" | tr ' ' '\n' | jq -R . | jq -s .)

# Check for duplicate
existing=$(jq -r --arg hash "$hash" '
    .errors[] | select(.error.hash == $hash) | .id
' "$ERRORS_FILE" 2>/dev/null | head -1)

if [[ -n "$existing" ]]; then
    echo "WARNING: Similar error already exists: $existing"
    echo "Updating existing entry instead of creating new one."

    # Update existing entry
    jq --arg id "$existing" \
       --arg solution "$solution" \
       --arg rationale "$rationale" \
       --arg now "$now" '
        .errors = [.errors[] |
            if .id == $id then
                .analysis.solution = $solution |
                .analysis.rationale = $rationale |
                .updatedAt = $now
            else .
            end
        ]
    ' "$ERRORS_FILE" > "$ERRORS_FILE.tmp" && mv "$ERRORS_FILE.tmp" "$ERRORS_FILE"

    echo "Updated: $existing"
    exit 0
fi

# Create new error entry
new_error=$(jq -n \
    --arg id "$id" \
    --arg now "$now" \
    --arg message "$error_message" \
    --arg normalized "$normalized" \
    --arg hash "$hash" \
    --arg type "$error_type" \
    --argjson keywords "$keywords_json" \
    --arg project "$project" \
    --arg projectPath "$project_path" \
    --arg source "$source" \
    --arg whatHappened "$what_happened" \
    --arg cause "$cause" \
    --arg solution "$solution" \
    --arg rationale "$rationale" \
    --arg fileChanged "$file_changed" \
    --arg codeBefore "$code_before" \
    --arg codeAfter "$code_after" \
    --argjson tags "$tags" \
    '{
        id: $id,
        createdAt: $now,
        updatedAt: $now,
        error: {
            message: $message,
            normalized: $normalized,
            hash: $hash,
            type: $type,
            keywords: $keywords
        },
        context: {
            project: $project,
            projectPath: $projectPath,
            source: $source,
            whatHappened: $whatHappened
        },
        analysis: {
            cause: $cause,
            solution: $solution,
            rationale: $rationale
        },
        code: (if $fileChanged != "" then {
            fileChanged: $fileChanged,
            before: $codeBefore,
            after: $codeAfter
        } else null end),
        tags: $tags,
        stats: {
            usageCount: 0,
            lastUsedAt: null,
            successRate: 1.0
        }
    }'
)

# Add to errors file
jq --argjson new "$new_error" '.errors += [$new]' "$ERRORS_FILE" > "$ERRORS_FILE.tmp" && mv "$ERRORS_FILE.tmp" "$ERRORS_FILE"

# Update index
jq --arg id "$id" --arg hash "$hash" --argjson tags "$tags" '
    .byHash[$hash] = $id |
    .byTag = (.byTag + (reduce ($tags[]) as $tag (.byTag; .[$tag] = ((.[$tag] // []) + [$id] | unique))))
' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

# Update stats
jq '.totalErrors += 1 | .lastUpdated = now | .lastUpdated = (now | todate)' "$STATS_FILE" > "$STATS_FILE.tmp" && mv "$STATS_FILE.tmp" "$STATS_FILE"

echo "Logged error: $id"
echo ""
echo "Details:"
echo "  Type: $error_type"
echo "  Project: $project"
echo "  Tags: $(echo "$tags" | jq -r 'join(", ")')"
echo ""
echo "View: /error:show $id"
