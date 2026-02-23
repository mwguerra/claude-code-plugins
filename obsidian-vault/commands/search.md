---
description: Find notes by title, tags, or content
allowed-tools: Bash(bash:*)
argument-hint: <query> [--title|--content|--tag] [--category <cat>] [--limit <n>]
---

# Search Vault

Find notes in your Obsidian vault by title, content, or tags.

## Usage

```bash
# Search everywhere (title, content, tags)
/obsidian-vault:search rate limiting

# Search titles only
/obsidian-vault:search --title "Laravel Queue"

# Search content only
/obsidian-vault:search --content Redis configuration

# Search by tag
/obsidian-vault:search --tag laravel

# Search within a category
/obsidian-vault:search --category projects authentication

# Limit results
/obsidian-vault:search rate limiting --limit 10
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/search-vault.sh" $ARGUMENTS`

## Search Types

| Flag | Searches In |
|------|-------------|
| (none) | Title, content, and tags |
| `--title` | Note titles only |
| `--content` | Note body content |
| `--tag` | Tags in frontmatter |

## Options

| Option | Description |
|--------|-------------|
| `--category <cat>` | Limit search to a specific category |
| `--limit <n>` | Maximum results (default: 20) |

## Output Format

```
[Note Title]
  Path: category/note-name.md
  Desc: Note description from frontmatter
  Tags: [tag1, tag2, tag3]
```

## Examples

```bash
# Find all Laravel-related notes
/obsidian-vault:search laravel

# Find commit documentation for rate limiting
/obsidian-vault:search --category journal/commits rate limiting

# Find all notes tagged with 'api'
/obsidian-vault:search --tag api

# Find notes mentioning Redis in their content
/obsidian-vault:search --content Redis
```
