---
description: Initialize the error memory database
---

# Error Memory Initialize

Initialize the error memory database structure. This creates the necessary configuration directory and JSON files.

## Usage

```
/error:init
```

## Process

Run the initialization script:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/init.sh
```

## What Gets Created

The initialization creates the following structure at `~/.claude/error-memory/`:

```
~/.claude/error-memory/
├── errors.json    # Main error database
├── index.json     # Search indexes (by hash, by tag)
└── stats.json     # Usage statistics
```

### errors.json
- Stores all error entries with full metadata
- Includes error message, normalization, context, analysis, and stats

### index.json
- Hash-based index for fast exact matching
- Tag-based index for filtered searches

### stats.json
- Total errors, searches, matches
- Last updated timestamp

## When to Use

- First time using the error memory plugin
- After clearing/corrupting the database
- The scripts auto-initialize if needed, so manual init is optional

## Idempotent

Running init multiple times is safe:
- Existing files are preserved
- Only missing files are created
- Existing data is not modified

## Example

```
/error:init

Output:
Error Memory Initialization
============================

Created: ~/.claude/error-memory
Created: errors.json
Created: index.json
Created: stats.json

Initialization complete!
```
