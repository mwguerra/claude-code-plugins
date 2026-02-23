---
description: List notes in the vault, optionally filtered by category
allowed-tools: Bash(bash:*)
argument-hint: [category] [--sort <updated|created|title>] [--limit <n>] [--stats]
---

# List Notes

List notes in your Obsidian vault, optionally filtered by category.

## Usage

```bash
# List all notes
/obsidian-vault:list

# List notes in a category
/obsidian-vault:list technologies
/obsidian-vault:list projects
/obsidian-vault:list journal/commits

# Sort by different fields
/obsidian-vault:list --sort title
/obsidian-vault:list technologies --sort created

# Show statistics
/obsidian-vault:list --stats

# Limit results
/obsidian-vault:list --limit 10
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/list-notes.sh" $ARGUMENTS`

## Categories

| Category | Contents |
|----------|----------|
| `projects` | Project documentation |
| `technologies` | Tech knowledge |
| `claude-code` | Claude Code components |
| `claude-code/agents` | Agent docs |
| `claude-code/hooks` | Hook docs |
| `claude-code/skills` | Skill docs |
| `claude-code/tools` | Tool docs |
| `ideas` | Ideas and experiments |
| `personal` | Career and learning |
| `todo` | Tasks and checklists |
| `references` | Snippets and bookmarks |
| `journal/commits` | Commit documentation |
| `journal/tasks` | Task summaries |
| `journal/creations` | Component creation logs |

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--sort` | Sort by: `updated`, `created`, `title` | `updated` |
| `--limit` | Maximum notes to show | 50 |
| `--stats` | Show category statistics | off |

## Output

```
Notes in: technologies

[Laravel Queue Configuration]
  Path: technologies/laravel-queues.md
  Updated: 2026-01-27
  Tags: [laravel, queues, redis]

[Redis Caching Guide]
  Path: technologies/redis-caching.md
  Updated: 2026-01-26
  Tags: [redis, caching, performance]
```
