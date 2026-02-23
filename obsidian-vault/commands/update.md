---
description: Edit an existing note's frontmatter or append content
allowed-tools: Bash(bash:*), Read, Edit
argument-hint: <path-or-title> [--title "..."] [--description "..."] [--add-tags "..."] [--add-related "..."] [--append "..."] [--show]
---

# Update Note

Edit an existing note's frontmatter or append content. Automatically updates the `updated` date.

## Usage

```bash
# View current content
/obsidian-vault:update "Laravel Queue Configuration" --show

# Update title
/obsidian-vault:update technologies/laravel-queues.md --title "Laravel Queue & Horizon Setup"

# Update description
/obsidian-vault:update "Laravel Queue Configuration" --description "Complete guide to Redis queues with Horizon"

# Add tags
/obsidian-vault:update "Laravel Queue Configuration" --add-tags "horizon,redis"

# Add related notes
/obsidian-vault:update "Laravel Queue Configuration" --add-related "technologies/redis,projects/my-app"

# Append content
/obsidian-vault:update "Laravel Queue Configuration" --append "## New Section\n\nAdditional content here."
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-note.sh" $ARGUMENTS`

## Finding Notes

The command accepts:
- **Full path**: `technologies/laravel-queues.md`
- **Path without extension**: `technologies/laravel-queues`
- **Note title**: `"Laravel Queue Configuration"` (searches frontmatter)
- **Partial title**: `"Laravel Queue"` (fuzzy match)

## Options

| Option | Description |
|--------|-------------|
| `--title` | Update the note title |
| `--description` | Update the description |
| `--add-tags` | Add tags (comma-separated, appends to existing) |
| `--add-related` | Add related notes (comma-separated) |
| `--append` | Append content to end of note |
| `--show` | Display current content without making changes |

## Direct Editing

For more complex edits, use the Read and Edit tools directly:

```bash
# Read the note
Read: ~/guerra_vault/technologies/laravel-queues.md

# Edit specific content
Edit: ~/guerra_vault/technologies/laravel-queues.md
```

The script will still update the `updated` date in frontmatter when you use the command options.
