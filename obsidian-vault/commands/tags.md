---
description: View and manage all tags in the vault
allowed-tools: Bash(bash:*)
argument-hint: [--stats] [--find <tag>] [--limit <n>]
---

# Manage Tags

View and analyze tags across your Obsidian vault.

## Usage

```bash
# List all unique tags
/obsidian-vault:tags

# Show tag usage statistics (count per tag)
/obsidian-vault:tags --stats

# Find notes with a specific tag
/obsidian-vault:tags --find laravel

# Limit results
/obsidian-vault:tags --stats --limit 20
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/manage-tags.sh" $ARGUMENTS`

## Options

| Option | Description |
|--------|-------------|
| (none) | List all unique tags |
| `--stats` | Show tag counts, sorted by usage |
| `--find <tag>` | Find all notes with a specific tag |
| `--limit <n>` | Maximum results (default: 50) |

## Output Examples

**List tags:**
```
All Tags in Vault
=================

  api
  claude-code
  commit
  laravel
  redis
  security

Total unique tags: 42
```

**Statistics:**
```
Tag Usage Statistics
====================

TAG                            COUNT
---                            -----
laravel                        23
commit                         18
api                            12
security                       8
```

**Find by tag:**
```
Notes tagged with: laravel
========================

[Laravel Queue Configuration]
  Path: technologies/laravel-queues.md

[Rate Limiting Implementation]
  Path: journal/commits/2026-01-27-rate-limiting.md
```
