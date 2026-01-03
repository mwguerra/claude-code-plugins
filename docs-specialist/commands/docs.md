---
description: Core documentation management - validate, generate, update, and check status
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "<validate | generate | update | status> [target] [--fix] [--format md|html]"
---

# Documentation Operations

Core documentation management: validate, generate, update, and check status.

## Syntax

```
/docs-specialist:docs <action> [target] [options]
```

## Actions

- `validate` - Check documentation quality, accuracy, and links
- `generate` - Generate documentation from source code
- `update` - Update documentation based on code changes
- `status` - Show documentation health overview

---

## validate

Run comprehensive validation checks on project documentation.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `[target]` | No | Specific path or file to validate (default: all docs) |
| `--type=<type>` | No | Filter by doc type: `api`, `readme`, `architecture`, `guides`, `all` (default: all) |
| `--checks=<list>` | No | Comma-separated checks: `links`, `accuracy`, `structure`, `examples`, `completeness`, `all` (default: all) |
| `--fix` | No | Attempt to auto-fix simple issues (broken links, formatting) |
| `--report=<format>` | No | Output format: `text`, `json`, `markdown` (default: text) |
| `--min-score=<n>` | No | Minimum quality score threshold 1-100 (default: 70) |

### Process

1. **Discover Documentation**
   - Scan project for all markdown files
   - Categorize by type (README, API, guides, architecture, etc.)
   - Identify tool-specific files (CLAUDE.md, .cursorrules) to preserve location

2. **Run Validation Checks**

   **Links Check:**
   - Find all internal links `[text](path)`
   - Verify each target file exists
   - Check anchor links resolve to valid headers
   - Sample-check external URLs (HEAD request)

   **Accuracy Check:**
   - Extract code examples from documentation
   - Verify syntax is valid for declared language
   - Cross-reference API endpoints with route files
   - Check configuration examples against actual config files

   **Structure Check:**
   - Verify header hierarchy (no skipped levels)
   - Check required sections exist (varies by doc type)
   - Validate table formatting
   - Ensure code blocks have language specifier

   **Examples Check:**
   - Extract all code blocks
   - Verify language is specified
   - Check import statements reference real modules
   - Validate syntax for the declared language

   **Completeness Check:**
   - README has: description, installation, usage, license
   - API docs have: endpoint, method, params, response, example
   - Guides have: prerequisites, steps, expected outcome

3. **Calculate Score**
   - Weight each check category
   - Produce overall score 0-100
   - Flag critical vs warning vs info issues

4. **Generate Report**
   ```
   Documentation Validation Report
   ================================
   Score: 78/100

   By Category:
     Links:        95/100 (2 broken)
     Accuracy:     70/100 (5 outdated)
     Structure:    85/100 (minor issues)
     Examples:     60/100 (3 need updating)
     Completeness: 80/100 (missing sections)

   Critical Issues:
     [BROKEN] docs/api/users.md:45 - Link to /auth not found
     [OUTDATED] README.md:23 - Install command differs from package.json

   Warnings:
     [STRUCTURE] docs/guides/setup.md - Skipped header level (h2 to h4)
     [EXAMPLE] docs/api/auth.md:67 - Code block missing language

   Recommendations:
     1. Fix broken internal links
     2. Update installation instructions
     3. Add language to code blocks
   ```

### Examples

```bash
# Full validation
/docs-specialist:docs validate

# Validate only API documentation
/docs-specialist:docs validate --type=api

# Validate specific file
/docs-specialist:docs validate docs/guides/getting-started.md

# Check only links and examples
/docs-specialist:docs validate --checks=links,examples

# Validate and auto-fix simple issues
/docs-specialist:docs validate --fix

# Generate JSON report
/docs-specialist:docs validate --report=json
```

---

## generate

Generate documentation from source code analysis.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<target>` | Yes | What to document: `api`, `models`, `components`, `services`, `all`, or specific path |
| `--template=<name>` | No | Template to use: `readme`, `api-endpoint`, `component`, `model`, `guide`, `architecture` |
| `--output=<path>` | No | Output location (default: `docs/`) |
| `--depth=<level>` | No | Analysis depth: `shallow`, `normal`, `deep` (default: normal) |
| `--include-private` | No | Include private methods/properties |
| `--dry-run` | No | Preview what would be generated without writing files |

### Process

1. **Scan Code**
   ```
   SCAN TARGET
   ├── Identify files by target type or path
   ├── Parse file structure:
   │   ├── Classes, interfaces, types
   │   ├── Functions and methods
   │   ├── Exports and imports
   │   └── Route definitions
   ├── Extract existing documentation:
   │   ├── JSDoc comments
   │   ├── Docstrings
   │   ├── Inline comments
   │   └── Type annotations
   └── Build code inventory
   ```

2. **Analyze Structure**
   ```
   ANALYZE
   ├── Map dependencies and relationships
   ├── Identify public vs private interfaces
   ├── Extract:
   │   ├── Function signatures
   │   ├── Parameter types and defaults
   │   ├── Return types
   │   └── Thrown exceptions
   ├── Find usage examples in tests
   └── Determine complexity level
   ```

3. **Generate Documentation**
   ```
   GENERATE
   ├── Select appropriate template
   ├── Fill sections:
   │   ├── Description (from comments or inferred)
   │   ├── Parameters (from signatures)
   │   ├── Return values (from types)
   │   ├── Examples (from tests or generated)
   │   └── Related items (from imports/exports)
   ├── Format according to style
   └── Add cross-references
   ```

4. **Output**
   - Preview with `--dry-run`
   - Write files to specified location
   - Report what was generated

### Target Types

| Target | What It Analyzes | Output Location |
|--------|------------------|-----------------|
| `api` | Route files, controllers, handlers | `docs/api/` |
| `models` | Database models, schemas, entities | `docs/models/` |
| `components` | React/Vue/Livewire components | `docs/components/` |
| `services` | Service classes, utilities | `docs/services/` |
| `all` | Everything above | `docs/` subdirectories |
| `<path>` | Specific file or directory | `docs/` or `--output` |

### Examples

```bash
# Generate API documentation
/docs-specialist:docs generate api

# Generate docs for specific file
/docs-specialist:docs generate src/services/AuthService.ts

# Preview what would be generated
/docs-specialist:docs generate models --dry-run

# Generate with specific template
/docs-specialist:docs generate api --template=api-endpoint

# Full project documentation with deep analysis
/docs-specialist:docs generate all --depth=deep

# Include private members
/docs-specialist:docs generate components --include-private

# Custom output location
/docs-specialist:docs generate api --output=documentation/api/
```

---

## update

Update existing documentation based on code changes.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `[target]` | No | Specific doc file or area to update (default: auto-detect from changes) |
| `--from-git` | No | Analyze recent git commits to find what changed |
| `--commits=<n>` | No | Number of commits to analyze (default: 10) |
| `--scope=<scope>` | No | What to update: `outdated`, `missing`, `all` (default: outdated) |
| `--interactive` | No | Confirm each change before applying (default: true) |
| `--auto` | No | Apply all changes without confirmation |

### Process

1. **Identify Changes**
   ```
   DETECT CHANGES
   ├── If --from-git:
   │   ├── Get list of modified files from git log
   │   ├── Filter to source code files
   │   └── Identify what changed in each file
   ├── Else:
   │   ├── Run sync check
   │   └── Get list of drift items
   └── Build change inventory
   ```

2. **Map to Documentation**
   ```
   MAP CHANGES TO DOCS
   ├── For each changed code item:
   │   ├── Find corresponding documentation
   │   ├── Identify what needs updating:
   │   │   ├── Function signatures
   │   │   ├── Parameter descriptions
   │   │   ├── Return values
   │   │   ├── Code examples
   │   │   └── Related references
   │   └── Queue update
   └── Sort by priority (breaking changes first)
   ```

3. **Apply Updates**
   ```
   UPDATE DOCS
   ├── For each queued update:
   │   ├── Show diff preview
   │   ├── If interactive: prompt for confirmation
   │   ├── Apply change
   │   └── Log update
   └── Report summary
   ```

### Examples

```bash
# Update based on recent git changes
/docs-specialist:docs update --from-git

# Update specific documentation file
/docs-specialist:docs update docs/api/users.md

# Update all outdated documentation
/docs-specialist:docs update --scope=outdated

# Add missing documentation
/docs-specialist:docs update --scope=missing

# Full update without prompts
/docs-specialist:docs update --scope=all --auto

# Analyze more commits
/docs-specialist:docs update --from-git --commits=50
```

---

## status

Display documentation health overview.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--detailed` | No | Show detailed breakdown by category |

### Process

1. **Gather Metrics**
   - Count documentation files by type
   - Check last modified dates
   - Run quick validation
   - Check sync status

2. **Calculate Health Score**
   - Coverage: % of code items documented
   - Freshness: % of docs updated recently
   - Quality: validation score
   - Sync: % of docs in sync with code

3. **Generate Overview**
   ```
   Documentation Status
   ====================

   Overall Health: 82/100

   Coverage:
     API Endpoints:  45/52 documented (87%)
     Models:         12/15 documented (80%)
     Components:      8/20 documented (40%)
     Services:       10/10 documented (100%)

   Freshness:
     Current (< 30 days):    35 files
     Needs review (30-90d):   8 files
     Stale (> 90 days):       3 files

   Quality Score: 78/100
     Links:       95/100
     Accuracy:    70/100
     Structure:   85/100

   Sync Status:
     In sync:         32 items
     Partial match:    5 items
     Out of sync:      8 items
     Undocumented:     7 items

   Quick Actions:
     /docs-specialist:docs validate     - Full quality check
     /docs-specialist:sync check        - Detailed sync report
     /docs-specialist:docs update       - Update outdated docs
   ```

### Examples

```bash
# Quick status overview
/docs-specialist:docs status

# Detailed breakdown
/docs-specialist:docs status --detailed
```

---

## Notes

- Always run `validate` before major releases
- Use `generate` for new code, `update` for changed code
- Combine with `/docs-specialist:sync check` for accuracy verification
- Tool-specific files (CLAUDE.md, .cursorrules) are preserved in their locations
