---
description: Validate and fix article-tasks.json and authors.json against their schemas - repairs missing fields, renames keys, ensures compliance
allowed-tools: Bash(bun:*)
argument-hint: [--check | --fix | --interactive]
---

# Doctor - Schema Validation & Repair

Validate and repair `.article_writer/` JSON files against their schemas.

## Usage

```bash
# Check only (report issues, don't fix)
/article-writer:doctor --check

# Auto-fix with defaults (non-interactive)
/article-writer:doctor --fix

# Interactive mode (ask for each issue)
/article-writer:doctor --interactive

# Default: interactive mode
/article-writer:doctor
```

## What It Checks

### article-tasks.json
- All required fields present on each article
- Field types match schema (string, integer, array, etc.)
- Enum values are valid (status, difficulty, area, content_type, etc.)
- Author reference structure is correct
- Output files and sources_used arrays are properly formatted
- Example info structure is valid
- Date fields are ISO format

### authors.json
- All required fields present (id, name, languages)
- ID format is valid (slug-like)
- Languages is a non-empty array
- Tone values are 1-10 range
- Optional fields have correct types

### settings.json
- example_defaults object exists
- Each example type is valid (code, document, diagram, etc.)
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
| Missing author reference | Use first author or ask |

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

Checking schemas...
✓ article-tasks.schema.json found
✓ authors.schema.json found

Validating authors.json...
✓ 2 authors validated

Validating article-tasks.json...
⚠ Article #3: Missing 'created_at' field
  → Auto-fix: Set to "2025-01-15T10:00:00Z"? [Y/n]

⚠ Article #5: Invalid status "wip" 
  → Valid options: pending, in_progress, draft, review, published, archived
  → Select replacement: [1-6]

Summary:
- Checked: 10 articles, 2 authors
- Issues found: 3
- Auto-fixed: 2
- Skipped: 1

✅ Files are now schema-compliant
```

## Process

1. Load schema files from `.article_writer/schemas/`
2. Load data files (article_tasks.json, authors.json)
3. Validate each item against schema
4. Collect all issues
5. Present issues to user (or auto-fix in --fix mode)
6. Apply fixes
7. Save updated files
8. Report summary
