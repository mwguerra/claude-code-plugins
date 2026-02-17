---
description: Validate and fix database records against schemas
allowed-tools: Bash(bun:*)
argument-hint: [--check | --fix | --interactive]
---

# Doctor - Database Validation & Repair

Validate and repair records in the SQLite database (`.article_writer/article_writer.db`).

**Tables validated:**
- `authors` - Author profiles
- `settings` - Global configuration
- `articles` - Article queue

**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writerdoctor)

## Usage

```bash
# Interactive mode (default) - ask for each issue
/article-writer:doctor

# Check only - report issues without fixing
/article-writer:doctor --check

# Auto-fix - fix with defaults, no prompts
/article-writer:doctor --fix
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/doctor.ts [--check | --fix]`

## What It Checks

### Database Integrity
- SQLite `PRAGMA integrity_check`
- `PRAGMA foreign_key_check` for referential integrity

### Articles Table
- All required fields present on each article
- Field types match schema (string, integer, array, etc.)
- Enum values are valid (status, difficulty, area, content_type, etc.)
- Author reference structure is correct
- Output files and sources_used JSON columns are properly formatted
- Companion project info structure is valid

### Authors Table
- All required fields present (id, name, languages)
- ID format is valid (slug-like)
- Languages is a non-empty array
- Tone values are 1-10 range
- Optional fields have correct types

### Settings Table
- companion_project_defaults object exists
- Each companion project type is valid (code, node, python, document, diagram, template, dataset, config, script, spreadsheet, other)
- technologies arrays are valid
- has_tests is boolean
- setup_commands and file_structure are arrays

## Auto-Fix Capabilities

| Issue | Auto-Fix Action |
|-------|-----------------|
| Missing required string | Set to `""` or ask user |
| Missing required array | Set to `[]` |
| Missing status | Set to `"pending"` |
| Missing created_at | Set to current timestamp |
| Invalid enum value | Ask user to select valid option |
| Wrong field type | Attempt conversion or ask user |
| Unknown fields | Report (keep by default) |
| Missing author reference | Use default author or ask |

## Interactive Mode

When issues require user input:
- Shows the problematic item
- Explains the issue
- Offers options (fix with default, enter value, skip)
- Confirms before making changes

## Output

```
🔍 Article Writer Doctor
========================

Checking database integrity...
✓ Database integrity: OK
✓ Foreign key constraints: OK

Validating authors...
✓ 2 authors valid

Validating settings...
✓ Settings valid

Validating articles...
  Article #3: Missing 'created_at' field
  → Auto-fix: Set to "2025-01-15T10:00:00Z"? [Y/n]

  Article #5: Invalid status "wip"
  → Valid options: pending, in_progress, draft, review, published, archived
  → Select replacement: [1-6]

Summary:
  Checked: 10 articles, 2 authors, settings
  Issues found: 3
  Fixed: 2

✅ Database has been repaired
```

## Process

1. Run SQLite integrity checks (PRAGMA integrity_check, foreign_key_check)
2. Check schema files exist in `.article_writer/schemas/`
3. Load all records from database
4. Validate each record against expected schema
5. Collect all issues
6. Present issues to user (or auto-fix in --fix mode)
7. Apply fixes via individual UPDATE statements
8. Report summary
