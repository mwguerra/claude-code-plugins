---
allowed-tools: Bash, Read, Write
description: Initialize a .taskmanager directory in the project if it does not exist
---

# Init Command

You are implementing `taskmanager:init`.

## Purpose

Initialize a new `.taskmanager/` directory with SQLite database for task management.

## Behavior

### 1. Check for existing installation

```bash
if [[ -d ".taskmanager" ]]; then
    if [[ -f ".taskmanager/taskmanager.db" ]]; then
        echo "Taskmanager already initialized (SQLite v2)"
        exit 0
    elif [[ -f ".taskmanager/tasks.json" ]]; then
        echo "Found JSON v1 installation. Run migration."
        # Trigger auto-migration
    fi
fi
```

### 2. Check for JSON files needing migration

If `.taskmanager/tasks.json` exists but `taskmanager.db` does not:
1. Inform user: "Found existing JSON-based taskmanager. Migrating to SQLite..."
2. Run the migration script from the plugin's db/ directory
3. Verify migration succeeded

### 3. Create fresh installation

If no `.taskmanager/` exists:

```bash
# Create directory structure
mkdir -p .taskmanager/logs
mkdir -p .taskmanager/docs

# Create database with schema
sqlite3 .taskmanager/taskmanager.db < "$PLUGIN_DIR/skills/taskmanager/db/schema.sql"

# Create default PRD file
cat > .taskmanager/docs/prd.md << 'EOF'
# Project Requirements Document

## Overview

Describe your project here.

## Features

1. Feature one
2. Feature two

## Technical Requirements

- Requirement one
- Requirement two
EOF

# Initialize empty log files
touch .taskmanager/logs/decisions.log
touch .taskmanager/logs/errors.log
touch .taskmanager/logs/debug.log

# Log initialization
echo "$(date -Iseconds) [DECISION] [init] Initialized taskmanager v2 (SQLite)" >> .taskmanager/logs/decisions.log
```

### 4. Verify installation

```bash
# Check database is valid
sqlite3 .taskmanager/taskmanager.db "SELECT version FROM schema_version;"
# Should output: 2.0.0

# Check tables exist
sqlite3 .taskmanager/taskmanager.db ".tables"
# Should output: memories memories_fts schema_version state sync_log tasks
```

### 5. Report to user

```
Taskmanager initialized successfully!

Created:
  .taskmanager/
  ├── taskmanager.db    # SQLite database (tasks, memories, state)
  ├── docs/
  │   └── prd.md        # Project requirements template
  └── logs/
      ├── decisions.log
      ├── errors.log
      └── debug.log

Next steps:
  1. Edit .taskmanager/docs/prd.md with your project requirements
  2. Run taskmanager:plan to generate tasks from the PRD
  3. Run taskmanager:next-task to see what to work on
```

## Notes

- SQLite WAL mode is enabled for better concurrent access
- The schema enforces data integrity via CHECK constraints
- Full-text search is available for memories via FTS5
