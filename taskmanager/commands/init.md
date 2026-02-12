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
        # Check version
        VERSION=$(sqlite3 .taskmanager/taskmanager.db "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null)
        if [[ "$VERSION" == "2.0.0" ]]; then
            echo "Found v2.0.0 database. Run the migration scripts to upgrade:"
            echo "  bash \$PLUGIN_DIR/schemas/migrate-v2-to-v3.sh"
            echo "  bash \$PLUGIN_DIR/schemas/migrate-v3-to-v3.1.sh"
            exit 0
        elif [[ "$VERSION" == "3.0.0" ]]; then
            echo "Found v3.0.0 database. Run the migration script to upgrade to v3.1.0:"
            echo "  bash \$PLUGIN_DIR/schemas/migrate-v3-to-v3.1.sh"
            exit 0
        elif [[ "$VERSION" == "3.1.0" ]]; then
            echo "Taskmanager already initialized (v3.1.0)"
            exit 0
        fi
    elif [[ -f ".taskmanager/tasks.json" ]]; then
        echo "Found JSON v1 installation. Run v1->v2 migration first, then v2->v3."
        exit 0
    fi
fi
```

### 2. Create fresh installation

If no `.taskmanager/` exists:

```bash
# Create directory structure
mkdir -p .taskmanager/logs
mkdir -p .taskmanager/docs

# Create database with schema
sqlite3 .taskmanager/taskmanager.db < "$PLUGIN_DIR/schemas/schema.sql"

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

# Initialize log file
touch .taskmanager/logs/activity.log

# Copy default configuration
cp "$PLUGIN_DIR/schemas/default-config.json" .taskmanager/config.json

# Log initialization
echo "$(date -Iseconds) [DECISION] [init] Initialized taskmanager v3.1.0 (SQLite)" >> .taskmanager/logs/activity.log
```

### 3. Verify installation

```bash
# Check database is valid
sqlite3 .taskmanager/taskmanager.db "SELECT version FROM schema_version;"
# Should output: 3.1.0

# Check tables exist
sqlite3 .taskmanager/taskmanager.db ".tables"
# Should output: deferrals memories memories_fts schema_version state tasks
```

### 4. Report to user

```
Taskmanager initialized successfully! (v3.1.0)

Created:
  .taskmanager/
  ├── taskmanager.db    # SQLite database (tasks, memories, state)
  ├── config.json       # Project configuration
  ├── docs/
  │   └── prd.md        # Project requirements template
  └── logs/
      └── activity.log  # All logging

Quick start:
  1. Edit .taskmanager/docs/prd.md with your project requirements
  2. Run taskmanager:plan to generate tasks from the PRD
  3. Run taskmanager:show --next to see what to work on
  4. Run taskmanager:run to start executing tasks

Available commands (8):
  taskmanager:init      Initialize project
  taskmanager:plan      Create tasks from PRD or expand existing tasks
  taskmanager:show      View dashboard, tasks, stats
  taskmanager:run       Execute tasks
  taskmanager:update    Modify tasks, status, tags, dependencies
  taskmanager:research  Research topics and store findings
  taskmanager:memory    Manage project memories
  taskmanager:export    Export data to JSON or markdown
```

## Notes

- SQLite WAL mode is enabled for better concurrent access
- The schema enforces data integrity via CHECK constraints
- Full-text search is available for memories via FTS5
- Single `activity.log` file replaces the previous 3-file logging system
