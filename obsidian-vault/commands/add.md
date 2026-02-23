---
description: Create a new note in the vault with proper frontmatter
allowed-tools: Bash(bash:*)
argument-hint: <category> <title> [--description "..."] [--tags "tag1,tag2"] [--related "Note1,Note2"]
---

# Add Note to Vault

Create a new note in your Obsidian vault with proper frontmatter.

## Usage

```bash
# Basic usage
/obsidian-vault:add technologies "Laravel Queue Configuration"

# With description and tags
/obsidian-vault:add projects "My SaaS App" --description "Main project documentation" --tags "saas,laravel,api"

# With related notes
/obsidian-vault:add ideas "Rate Limiting Improvements" --related "projects/my-saas-app,technologies/redis"

# Claude Code components
/obsidian-vault:add claude-code/agents "Code Reviewer Agent"
/obsidian-vault:add claude-code/hooks "Pre-commit Linting"
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/add-note.sh" $ARGUMENTS`

## Categories

| Category | Description |
|----------|-------------|
| `projects` | Project-specific documentation |
| `technologies` | Technology knowledge and tutorials |
| `claude-code` | Claude Code components |
| `claude-code/agents` | Agent documentation |
| `claude-code/hooks` | Hook documentation |
| `claude-code/skills` | Skill documentation |
| `claude-code/tools` | Tool/MCP server documentation |
| `ideas` | Feature ideas and experiments |
| `personal` | Career and learning goals |
| `todo` | Tasks and checklists |
| `references` | Bookmarks, snippets, cheatsheets |

## Generated Frontmatter

The note will be created with this frontmatter:

```yaml
---
title: "Laravel Queue Configuration"
description: "Laravel Queue Configuration"
tags: [laravel, queues, technologies]
related: []
created: 2026-01-27
updated: 2026-01-27
---
```

## Options

| Option | Description |
|--------|-------------|
| `--description` | Detailed description (defaults to title) |
| `--tags` | Comma-separated tags |
| `--related` | Comma-separated related note paths |
| `--content` | Initial content for the note body |

## After Creating

The command outputs the file path so you can:
- Open it in Obsidian
- Continue editing with `/obsidian-vault:update`
- Link it from other notes with `/obsidian-vault:link`
