---
description: Add bidirectional related links between notes
allowed-tools: Bash(bash:*)
argument-hint: <note1> <note2> [--one-way]
---

# Link Notes

Create related links between two notes. By default, creates bidirectional links (both notes link to each other).

## Usage

```bash
# Create bidirectional link
/obsidian:link "Laravel Queue Configuration" "Redis Caching Guide"

# Link by path
/obsidian:link technologies/laravel-queues.md technologies/redis.md

# One-way link (only adds to first note)
/obsidian:link "Laravel Queue Configuration" "Redis Caching Guide" --one-way
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/link-notes.sh" $ARGUMENTS`

## Options

| Option | Description |
|--------|-------------|
| `--one-way` | Only add link to the first note |

## How It Works

1. Finds both notes (by path or title)
2. Adds the second note to the first note's `related` frontmatter
3. (Unless `--one-way`) Adds the first note to the second note's `related` frontmatter
4. Updates the `updated` date on both notes

## Finding Notes

Notes can be specified by:
- **Full path**: `technologies/laravel-queues.md`
- **Path without extension**: `technologies/laravel-queues`
- **Exact title**: `"Laravel Queue Configuration"`
- **Partial title**: `"Laravel Queue"` (fuzzy match)

## Result

**Before:**
```yaml
# technologies/laravel-queues.md
related: []
```

**After:**
```yaml
# technologies/laravel-queues.md
related: [[technologies/redis]]

# technologies/redis.md
related: [[technologies/laravel-queues]]
```

## Tips

- Use quotes around titles with spaces
- Links use Obsidian wiki-link format `[[path]]`
- The `updated` date is automatically refreshed
