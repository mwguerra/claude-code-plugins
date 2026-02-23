---
description: Move a note to the archive folder or restore from archive
allowed-tools: Bash(bash:*)
argument-hint: <note> [--restore]
---

# Archive Note

Move a note to the `_archive/` folder. Archived notes are preserved but hidden from regular listings.

## Usage

```bash
# Archive a note
/obsidian-vault:archive "Old Project Notes"
/obsidian-vault:archive technologies/outdated-guide.md

# Restore from archive
/obsidian-vault:archive "Old Project Notes" --restore
/obsidian-vault:archive --restore outdated-guide.md
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/archive-note.sh" $ARGUMENTS`

## Options

| Option | Description |
|--------|-------------|
| `--restore` | Restore a note from the archive |

## How It Works

**Archive:**
1. Finds the note by path or title
2. Records the original category in frontmatter (`archived_from`)
3. Moves the note to `_archive/` folder
4. Updates the `updated` date

**Restore:**
1. Finds the note in `_archive/`
2. Reads the original category from `archived_from`
3. Moves the note back to its original location
4. Removes the `archived_from` field
5. Updates the `updated` date

## Archive Location

```
guerra_vault/
├── _archive/                  # Archived notes live here
│   ├── old-project.md
│   └── outdated-guide.md
└── ...
```

## Viewing Archived Notes

```bash
# List archived notes
/obsidian-vault:list _archive
```

## Why Archive Instead of Delete?

- Preserves historical context
- Easy to restore if needed later
- Notes may have valuable links or references
- Better than permanent deletion
