---
description: Import external files or folders into the vault with proper frontmatter
allowed-tools: Bash(bash:*)
argument-hint: <file-or-folder> [--to <category>] [--recursive] [--no-frontmatter]
---

# Import Files to Vault

Import external markdown files or folders into your Obsidian vault. Automatically adds frontmatter if missing.

## Usage

```bash
# Import a single file
/obsidian-vault:import ./README.md --to projects/my-app

# Import to auto-detected category
/obsidian-vault:import ./docs/api.md

# Import a folder (non-recursive)
/obsidian-vault:import ./docs --to references

# Import a folder recursively
/obsidian-vault:import ./documentation --to references --recursive

# Import without adding frontmatter
/obsidian-vault:import ./notes.md --to references --no-frontmatter
```

Runs: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/import-files.sh" $ARGUMENTS`

## Options

| Option | Description |
|--------|-------------|
| `--to <category>` | Target category/path in vault |
| `--recursive` | Import subdirectories |
| `--no-frontmatter` | Don't add frontmatter to files |

## Auto-Detection

If `--to` is not specified:
- `README.md` files → `projects/`
- Other `.md` files → `references/`

## Frontmatter Handling

**Files without frontmatter:**
- Title extracted from first `# Heading` or filename
- Description defaults to title
- Tags include `imported` and source directory name
- Created/updated dates set to today

**Files with existing frontmatter:**
- Frontmatter preserved
- `updated` date refreshed

## Examples

```bash
# Import project documentation
/obsidian-vault:import ~/projects/my-app/README.md --to projects/my-app

# Import a docs folder
/obsidian-vault:import ~/projects/my-app/docs --to projects/my-app/docs --recursive

# Import cheatsheets
/obsidian-vault:import ~/Downloads/laravel-cheatsheet.md --to references
```

## After Importing

- Review imported files in Obsidian
- Update tags with `/obsidian-vault:update`
- Link related notes with `/obsidian-vault:link`
