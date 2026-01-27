#!/bin/bash
# Obsidian Vault Plugin - Capture Claude Code Component Creation
# Triggered by PostToolUse on Write/Bash commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "capture-component-creation.sh triggered"

# Check if capture is enabled
if ! is_capture_enabled "claudeCodeComponents"; then
    debug_log "Component capture disabled"
    exit 0
fi

# Check vault configuration
VAULT_PATH=$(check_vault)
if [[ -z "$VAULT_PATH" ]]; then
    debug_log "Vault not configured"
    exit 0
fi

# Get tool information
TOOL_INPUT=$(get_tool_input)
TOOL_OUTPUT=$(get_tool_output)

debug_log "Tool input: $TOOL_INPUT"

# Detect what type of component was created
COMPONENT_TYPE=""
COMPONENT_PATH=""
COMPONENT_NAME=""

# Check for agent creation
if echo "$TOOL_INPUT" | grep -qE "agents/.*\.md|/agents/"; then
    COMPONENT_TYPE="agent"
    COMPONENT_PATH=$(echo "$TOOL_INPUT" | grep -oE "[^ ]*agents/[^ ]*\.md" | head -1)
fi

# Check for hook creation
if echo "$TOOL_INPUT" | grep -qE "hooks\.json|hooks/.*\.sh|/hooks/"; then
    COMPONENT_TYPE="hook"
    COMPONENT_PATH=$(echo "$TOOL_INPUT" | grep -oE "[^ ]*hooks[^ ]*" | head -1)
fi

# Check for skill creation
if echo "$TOOL_INPUT" | grep -qE "skills/.*SKILL\.md|/skills/"; then
    COMPONENT_TYPE="skill"
    COMPONENT_PATH=$(echo "$TOOL_INPUT" | grep -oE "[^ ]*skills/[^ ]*" | head -1)
fi

# Check for MCP/tool creation
if echo "$TOOL_INPUT" | grep -qE "\.mcp\.json|mcp-servers"; then
    COMPONENT_TYPE="tool"
    COMPONENT_PATH=$(echo "$TOOL_INPUT" | grep -oE "[^ ]*\.mcp\.json" | head -1)
fi

# Skip if no component detected
if [[ -z "$COMPONENT_TYPE" ]]; then
    debug_log "No Claude Code component detected"
    exit 0
fi

debug_log "Detected $COMPONENT_TYPE at $COMPONENT_PATH"

# Extract component name from path
if [[ -n "$COMPONENT_PATH" ]]; then
    COMPONENT_NAME=$(basename "$COMPONENT_PATH" .md)
    COMPONENT_NAME=$(basename "$COMPONENT_NAME" .json)
    COMPONENT_NAME=$(basename "$COMPONENT_NAME" .sh)
fi

# Use a default name if extraction failed
COMPONENT_NAME="${COMPONENT_NAME:-unknown-$COMPONENT_TYPE}"

# Generate filename
DATE=$(get_date)
DATETIME=$(get_datetime)
SLUG=$(slugify "$COMPONENT_NAME")
FILENAME="${SLUG}.md"
FILE_PATH="$VAULT_PATH/claude-code/${COMPONENT_TYPE}s/$FILENAME"

# Ensure directory exists
ensure_dir "$VAULT_PATH/claude-code/${COMPONENT_TYPE}s"

# Skip if file already exists (update instead of recreate)
if [[ -f "$FILE_PATH" ]]; then
    # Update the updated date
    sed -i "s/^updated:.*$/updated: $DATE/" "$FILE_PATH" 2>/dev/null || true
    debug_log "Updated existing component note: $FILE_PATH"
    exit 0
fi

# Get project info
PROJECT=$(get_project_name)

# Create description based on type
case "$COMPONENT_TYPE" in
    agent)
        DESCRIPTION="Claude Code agent for specialized tasks"
        ;;
    hook)
        DESCRIPTION="Claude Code hook for event handling"
        ;;
    skill)
        DESCRIPTION="Claude Code skill for domain expertise"
        ;;
    tool)
        DESCRIPTION="MCP server/tool integration"
        ;;
esac

# Create tags
TAGS="claude-code, $COMPONENT_TYPE, $PROJECT"

# Create the note
{
    create_frontmatter "$COMPONENT_NAME" "$DESCRIPTION" "$TAGS" ""
    echo ""
    echo "# $COMPONENT_NAME"
    echo ""
    echo "**Type:** ${COMPONENT_TYPE^}"
    echo "**Created:** $DATETIME"
    if [[ -n "$COMPONENT_PATH" ]]; then
        echo "**Location:** \`$COMPONENT_PATH\`"
    fi
    echo "**Project:** $PROJECT"
    echo ""

    echo "## Purpose"
    echo ""
    echo "<!-- What does this $COMPONENT_TYPE do? -->"
    echo ""

    case "$COMPONENT_TYPE" in
        agent)
            echo "## Capabilities"
            echo ""
            echo "<!-- What tasks can this agent perform? -->"
            echo "- "
            echo ""
            echo "## When It's Used"
            echo ""
            echo "<!-- What triggers this agent? -->"
            echo ""
            ;;
        hook)
            echo "## Event"
            echo ""
            echo "<!-- Which event triggers this hook? -->"
            echo ""
            echo "## What It Does"
            echo ""
            echo "<!-- Describe the hook's behavior -->"
            echo ""
            echo "## Configuration"
            echo ""
            echo '```json'
            echo "// Hook configuration"
            echo '```'
            echo ""
            ;;
        skill)
            echo "## When to Use"
            echo ""
            echo "<!-- When should this skill be activated? -->"
            echo ""
            echo "## Key Features"
            echo ""
            echo "<!-- Main capabilities of this skill -->"
            echo "- "
            echo ""
            ;;
        tool)
            echo "## Integration"
            echo ""
            echo "<!-- How does this tool integrate with Claude Code? -->"
            echo ""
            echo "## Available Functions"
            echo ""
            echo "<!-- What functions does this MCP server provide? -->"
            echo "- "
            echo ""
            ;;
    esac

    echo "## Notes"
    echo ""
    echo "<!-- Additional context, gotchas, or tips -->"
    echo ""

} > "$FILE_PATH"

debug_log "Created component note: $FILE_PATH"

# Also create a note in journal/creations
JOURNAL_PATH="$VAULT_PATH/journal/creations/${DATE}-${SLUG}.md"
ensure_dir "$VAULT_PATH/journal/creations"

if [[ ! -f "$JOURNAL_PATH" ]]; then
    {
        create_frontmatter "Created: $COMPONENT_NAME" "Created new $COMPONENT_TYPE in $PROJECT" "creation, claude-code, $COMPONENT_TYPE" "[[claude-code/${COMPONENT_TYPE}s/$SLUG]]"
        echo ""
        echo "# Created: $COMPONENT_NAME"
        echo ""
        echo "**Date:** $DATETIME"
        echo "**Type:** ${COMPONENT_TYPE^}"
        echo "**Project:** $PROJECT"
        echo ""
        echo "Created a new Claude Code $COMPONENT_TYPE."
        echo ""
        echo "See: [[claude-code/${COMPONENT_TYPE}s/$SLUG]]"
        echo ""
    } > "$JOURNAL_PATH"
    debug_log "Created journal entry: $JOURNAL_PATH"
fi

echo "OBSIDIAN_COMPONENT_NOTE_CREATED: $FILE_PATH"

exit 0
