#!/bin/bash
# Obsidian Vault Plugin - Initialize vault configuration and structure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE="$HOME/.claude/obsidian-vault.json"
DEFAULT_VAULT_PATH="$HOME/guerra_vault"

# Parse arguments
VAULT_PATH=""
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vault)
            VAULT_PATH="$2"
            shift 2
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        *)
            # Assume it's the vault path if no flag
            if [[ -z "$VAULT_PATH" ]]; then
                VAULT_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Use default if not specified
VAULT_PATH="${VAULT_PATH:-$DEFAULT_VAULT_PATH}"

# Expand ~ to home directory
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

echo "Obsidian Vault Initialization"
echo "=============================="
echo ""
echo "Vault path: $VAULT_PATH"
echo ""

# Define folder structure
FOLDERS=(
    "projects"
    "technologies"
    "claude-code/agents"
    "claude-code/hooks"
    "claude-code/skills"
    "claude-code/tools"
    "ideas"
    "personal"
    "todo"
    "references"
    "journal/commits"
    "journal/tasks"
    "journal/creations"
    "_archive"
)

if [[ "$CHECK_ONLY" == true ]]; then
    echo "CHECK MODE - No changes will be made"
    echo ""

    # Check config
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "[OK] Config file exists: $CONFIG_FILE"
        current_vault=$(get_vault_path)
        echo "     Current vault: $current_vault"
    else
        echo "[MISSING] Config file: $CONFIG_FILE"
    fi
    echo ""

    # Check vault directory
    if [[ -d "$VAULT_PATH" ]]; then
        echo "[OK] Vault directory exists"
    else
        echo "[MISSING] Vault directory: $VAULT_PATH"
    fi
    echo ""

    # Check folders
    echo "Folder Status:"
    for folder in "${FOLDERS[@]}"; do
        if [[ -d "$VAULT_PATH/$folder" ]]; then
            echo "  [OK] $folder"
        else
            echo "  [MISSING] $folder"
        fi
    done

    exit 0
fi

# Create config file
echo "Creating configuration..."
ensure_dir "$(dirname "$CONFIG_FILE")"

cat > "$CONFIG_FILE" << EOF
{
  "vaultPath": "$VAULT_PATH",
  "autoCapture": {
    "commits": true,
    "tasks": true,
    "sessionSummaries": true,
    "claudeCodeComponents": true
  },
  "defaultTags": ["claude-generated"],
  "categories": {
    "projects": "Project-specific documentation",
    "technologies": "Technology knowledge and tutorials",
    "claude-code": "Claude Code components (agents, hooks, skills, tools)",
    "ideas": "Feature ideas and experiments",
    "personal": "Career and learning goals",
    "todo": "Tasks and checklists",
    "references": "Bookmarks, snippets, and cheatsheets"
  }
}
EOF

echo "  Created: $CONFIG_FILE"

# Create vault directory if needed
if [[ ! -d "$VAULT_PATH" ]]; then
    mkdir -p "$VAULT_PATH"
    echo "  Created vault directory: $VAULT_PATH"
else
    echo "  Vault directory exists: $VAULT_PATH"
fi

# Create folder structure
echo ""
echo "Creating folder structure..."
for folder in "${FOLDERS[@]}"; do
    folder_path="$VAULT_PATH/$folder"
    if [[ ! -d "$folder_path" ]]; then
        mkdir -p "$folder_path"
        echo "  Created: $folder"
    else
        echo "  Exists:  $folder"
    fi
done

# Create .gitkeep files to preserve empty directories
for folder in "${FOLDERS[@]}"; do
    folder_path="$VAULT_PATH/$folder"
    if [[ ! -f "$folder_path/.gitkeep" ]]; then
        touch "$folder_path/.gitkeep"
    fi
done

# Create vault README
README_PATH="$VAULT_PATH/README.md"
if [[ ! -f "$README_PATH" ]]; then
    cat > "$README_PATH" << 'EOF'
---
title: "Development Knowledge Base"
description: "Personal Obsidian vault for developer documentation, project notes, and work journal"
tags: [index, vault, documentation]
related: []
created: $(date +%Y-%m-%d)
updated: $(date +%Y-%m-%d)
---

# Development Knowledge Base

Welcome to your development knowledge base powered by the Obsidian Vault plugin for Claude Code.

## Structure

- **[[projects/]]** - Project-specific documentation
- **[[technologies/]]** - Technology knowledge (Laravel, React, etc.)
- **[[claude-code/]]** - Claude Code components (agents, hooks, skills, tools)
- **[[ideas/]]** - Feature ideas and experiments
- **[[personal/]]** - Career and learning goals
- **[[todo/]]** - Tasks and checklists
- **[[references/]]** - Bookmarks, snippets, and cheatsheets
- **[[journal/]]** - Automatic work journal
  - `commits/` - Git commit documentation
  - `tasks/` - Completed task summaries
  - `creations/` - New components created

## Auto-Captured Content

This vault automatically captures:
- Git commits with context and reasoning
- Task completions with summaries
- Claude Code component creation (agents, hooks, skills, tools)
- Session summaries

## Commands

Use these Claude Code commands to manage your vault:

| Command | Description |
|---------|-------------|
| `/obsidian:init` | Initialize or check vault setup |
| `/obsidian:add` | Add a new note |
| `/obsidian:search` | Search notes |
| `/obsidian:update` | Edit a note |
| `/obsidian:import` | Import external files |
| `/obsidian:list` | List notes by category |
| `/obsidian:tags` | View all tags |
| `/obsidian:link` | Link related notes |
| `/obsidian:archive` | Archive a note |
EOF
    # Fix the date placeholders
    sed -i "s/\$(date +%Y-%m-%d)/$(date +%Y-%m-%d)/g" "$README_PATH"
    echo ""
    echo "  Created: README.md"
fi

echo ""
echo "Initialization complete!"
echo ""
echo "Next steps:"
echo "  1. Open your vault in Obsidian: $VAULT_PATH"
echo "  2. Start adding notes: /obsidian:add technologies \"Your First Note\""
echo "  3. Auto-capture is enabled for commits, tasks, and components"
