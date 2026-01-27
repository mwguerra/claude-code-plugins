---
description: Set up vault path config, create folder structure, validate existing vault
allowed-tools: Bash(bash:*)
argument-hint: [--check] [--vault <path>]
---

# Initialize Obsidian Vault

Set up the obsidian-vault plugin configuration and folder structure.

## Usage

```bash
# Initialize with default vault path (~/guerra_vault)
/obsidian:init

# Initialize with custom vault path
/obsidian:init --vault ~/my-vault

# Check current setup without making changes
/obsidian:init --check
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh" $ARGUMENTS`

## What It Creates

### Configuration File

Creates `~/.claude/obsidian-vault.json`:
```json
{
  "vaultPath": "/home/user/guerra_vault",
  "autoCapture": {
    "commits": true,
    "tasks": true,
    "sessionSummaries": true,
    "claudeCodeComponents": true
  },
  "defaultTags": ["claude-generated"]
}
```

### Vault Structure

```
guerra_vault/
├── projects/              # Project-specific documentation
├── technologies/          # Tech knowledge (Laravel, React, etc.)
├── claude-code/           # Claude Code components
│   ├── agents/
│   ├── hooks/
│   ├── skills/
│   └── tools/
├── ideas/                 # Feature ideas, experiments
├── personal/              # Career, learning goals
├── todo/                  # Tasks and checklists
├── references/            # Bookmarks, snippets, cheatsheets
├── journal/               # Auto-captured events
│   ├── commits/
│   ├── tasks/
│   └── creations/
├── _archive/              # Archived notes
└── README.md              # Vault index
```

## Re-running Init

Running `/obsidian:init` again is safe:
- Creates any missing folders
- Skips existing files (won't overwrite your data)
- Updates config file with current settings

## After Initialization

1. **Open in Obsidian**: Open the vault folder in Obsidian app
2. **Add your first note**: `/obsidian:add technologies "Getting Started"`
3. **Auto-capture enabled**: Commits, tasks, and components will be documented automatically
