---
description: Diagnose and fix common documentation issues
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[--check] [--fix] [--interactive]"
---

# Documentation Health Check

Diagnose and fix common documentation issues.

## Syntax

```
/docs-specialist:doctor [options]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--check` | No | Check only, don't fix anything |
| `--fix` | No | Auto-fix issues with safe defaults |
| `--interactive` | No | Interactive mode - confirm each fix (default) |

## Checks Performed

### 1. Structure Health

| Check | Description | Auto-Fix |
|-------|-------------|----------|
| Docs folder exists | `docs/` directory present | Create with `init` |
| README exists | `docs/README.md` present | Create from template |
| Orphaned files | Docs not linked from anywhere | Add to index |
| Empty directories | Folders with no content | Remove or add placeholder |

### 2. File Health

| Check | Description | Auto-Fix |
|-------|-------------|----------|
| Valid markdown | Files parse without errors | Report only |
| Has title | Every file has H1 header | Add based on filename |
| Consistent encoding | UTF-8 encoding | Convert to UTF-8 |
| Line endings | Consistent line endings | Normalize to LF |
| Trailing whitespace | No trailing spaces | Trim whitespace |

### 3. Content Health

| Check | Description | Auto-Fix |
|-------|-------------|----------|
| Broken internal links | Links to non-existent files | Report with suggestions |
| Missing code languages | Code blocks without language | Suggest language |
| TODO markers | Incomplete documentation | Report count |
| Empty sections | Headers with no content | Report locations |

### 4. Navigation Health

| Check | Description | Auto-Fix |
|-------|-------------|----------|
| Index completeness | All docs listed in README | Add missing links |
| Breadcrumbs | Back links to parent docs | Add navigation |
| Cross-references | Related docs linked | Suggest links |

## Process

```
1. SCAN DOCUMENTATION
   ├── Find all markdown files
   ├── Parse each file
   └── Build documentation graph

2. RUN CHECKS
   ├── Structure checks
   ├── File checks
   ├── Content checks
   └── Navigation checks

3. CATEGORIZE ISSUES
   ├── Critical (broken, unusable)
   ├── Warning (degraded quality)
   └── Info (improvements possible)

4. REPORT OR FIX
   ├── --check: Report only
   ├── --fix: Auto-fix safe issues
   └── --interactive: Confirm each fix
```

## Report Format

```
Documentation Health Check
==========================

Overall: HEALTHY | NEEDS ATTENTION | CRITICAL

Summary:
  Critical:  0
  Warning:   3
  Info:      5

STRUCTURE
─────────
  ✓ docs/ folder exists
  ✓ docs/README.md exists
  ⚠ 2 orphaned files found
  ✓ No empty directories

FILES
─────
  ✓ All files are valid markdown
  ✓ All files have titles
  ⚠ 1 file has TODO markers
  ℹ 3 code blocks missing language

CONTENT
───────
  ⚠ 2 broken internal links
    • docs/api/users.md:45 → ../guides/auth.md (not found)
    • docs/guides/setup.md:23 → ./install.md (not found)
  ℹ 5 empty sections found
  ℹ 12 TODO markers remaining

NAVIGATION
──────────
  ✓ Index is complete
  ℹ 3 files missing breadcrumbs

DETAILED ISSUES
───────────────

[WARNING] Broken Link
  File: docs/api/users.md:45
  Link: ../guides/auth.md
  Suggestion: Did you mean ../guides/authentication.md?

[WARNING] Broken Link
  File: docs/guides/setup.md:23
  Link: ./install.md
  Suggestion: File doesn't exist. Create it or update link.

[INFO] Code Block Without Language
  File: docs/api/auth.md:67
  Content starts with: curl -X POST...
  Suggestion: Add ```bash

[INFO] TODO Marker
  File: docs/guides/getting-started.md:34
  Content: TODO: Add database setup instructions

RECOMMENDATIONS
───────────────

1. Fix broken links (2 issues)
   /docs-specialist:doctor --fix

2. Add language to code blocks
   /docs-specialist:docs validate --fix

3. Complete TODO items
   Search: rg "TODO" docs/

Run with --fix to auto-repair safe issues
Run with --interactive to review each fix
```

## Examples

```bash
# Full health check (report only)
/docs-specialist:doctor --check

# Interactive fix mode (default)
/docs-specialist:doctor

# Auto-fix all safe issues
/docs-specialist:doctor --fix
```

## Interactive Mode

```
Documentation Doctor - Issue 1 of 5
═══════════════════════════════════

[WARNING] Broken Internal Link

File: docs/api/users.md
Line: 45
Link: ../guides/auth.md

The linked file does not exist.

Suggestions:
  1. ../guides/authentication.md (similar name exists)
  2. Create ../guides/auth.md
  3. Remove the link

Actions:
  [1] Use suggestion 1 (authentication.md)
  [2] Create the missing file
  [3] Remove the link
  [S] Skip this issue
  [Q] Quit

Choice [1/2/3/S/Q]: 1

✓ Updated link to ../guides/authentication.md

Press Enter to continue...
```

## Auto-Fix Actions

When using `--fix`, these actions are applied automatically:

| Issue Type | Auto-Fix Action |
|------------|-----------------|
| Missing docs/README.md | Create from template |
| Trailing whitespace | Trim |
| Inconsistent line endings | Normalize to LF |
| Orphaned files | Add to docs/README.md index |
| Missing breadcrumbs | Add "← Back to [Index](../README.md)" |
| Empty directories | Remove |

**NOT auto-fixed** (requires `--interactive`):
- Broken links (needs human decision)
- Missing code languages (needs verification)
- TODO completion (needs content)
- Empty sections (needs content)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Healthy - no issues |
| 1 | Info - minor improvements possible |
| 2 | Warning - issues should be addressed |
| 3 | Critical - immediate attention needed |

## Notes

- Run `doctor` after `init` to verify setup
- Run `doctor` before releases to ensure quality
- Use `--check` in CI/CD to catch issues
- Critical issues should be fixed before merging
