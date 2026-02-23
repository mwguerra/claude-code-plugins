---
description: Migrate errors from the old solved-errors.md format to the new database
arguments:
  - name: options
    description: "Optional: --dry-run to preview without saving, --file <path> for custom source"
    required: false
---

# Error Memory Migration

Migrate errors from the old `solved-errors.md` markdown format to the new JSON database.

## Usage

```
/error:migrate [--dry-run] [--file <path>]
```

## Process

1. First, do a dry run to see what would be migrated:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/migrate.sh --dry-run
```

2. Review the output to verify errors are being parsed correctly.

3. If everything looks good, run the actual migration:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/migrate.sh
```

## Options

- **--dry-run**: Parse and show what would be migrated without actually saving
- **--file, -f**: Specify a custom source file (default: `~/.claude/solved-errors.md`)

## Expected Source Format

The migration script expects the old markdown format:

```markdown
## Project Name
- Project: project-name
- Path: /path/to/project
- Error: the error message
- About: what the error is about
- Why: why it happened
- Context: some context
- Solution: how it was solved
- Rationale: why the solution works
- Tags: tag1, tag2, tag3
```

## Migration Mapping

| Old Field | New Field |
|-----------|-----------|
| Project | context.project |
| Path | context.projectPath |
| Error | error.message |
| About + Context | context.whatHappened |
| Why | analysis.cause |
| Solution | analysis.solution |
| Rationale | analysis.rationale |
| Tags | tags |

## Duplicate Handling

- Errors are hashed after normalization
- If a similar error already exists, the existing entry is updated
- No duplicate entries are created

## Example

```bash
# Preview migration
/error:migrate --dry-run

# Migrate from default file
/error:migrate

# Migrate from custom file
/error:migrate --file ~/my-errors.md
```
