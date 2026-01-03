---
description: Initialize the Plugin Usage Tracker system
allowed-tools: Bash(bun:*)
argument-hint: [--force]
---

# Initialize Plugin Usage Tracker

Initialize the Plugin Usage Tracker to start logging your Claude Code activity.

## What this does:
1. Creates the tracking directory at `~/.claude/.plugin-history/`
2. Initializes an empty usage log file with the proper schema
3. Creates a configuration file for customization
4. Copies the JSON schema for reference

## Usage:
- `/usage-init` - Initialize if not already set up
- `/usage-init --force` - Reinitialize and reset all tracking data

## After initialization:
- All tool usage, sessions, and events will be automatically logged
- Use `/usage-stats` to view your usage statistics
- Use `/usage-logs` to browse your activity history
- Ask the `usage-analyzer` agent for insights about your workflow

Please run the initialization script:

```bash
bun run ${CLAUDE_PLUGIN_ROOT}/scripts/init-tracker.ts $ARGUMENTS
```
