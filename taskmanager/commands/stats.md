---
allowed-tools: Bash, Read
description: Get quick task statistics without loading entire tasks.json - saves tokens and context
---

# Task Statistics Command

You are implementing `/mwguerra:taskmanager:stats`.

## Purpose

This command provides quick, efficient access to task statistics without loading the entire `tasks.json` file into context. This saves significant tokens when the tasks file is large (50k+ tokens).

## Arguments

- `[mode]` (optional): The type of statistics to retrieve. Defaults to `--summary`.

Available modes:

**Read-only statistics:**
- `--summary` - Full text summary with all statistics
- `--json` - Full JSON output for programmatic use
- `--next` - Next recommended task only
- `--next5` - Next 5 recommended tasks
- `--status` - Task counts by status
- `--priority` - Task counts by priority
- `--levels` - Task counts by level/depth
- `--remaining` - Count of remaining tasks
- `--time` - Estimated time remaining
- `--completion` - Completion statistics

**Task query:**
- `--get <id> [key]` - Get task by ID, optionally extract specific property
  - Examples: `--get 1.2.3`, `--get 1.2.3 status`, `--get 1.2.3 complexity.scale`

**Write modes (modify tasks.json):**
- `--set-status <status> <id1> [id2...]` - Update status for one or more tasks
  - Valid statuses: draft, planned, in-progress, blocked, paused, done, canceled, duplicate, needs-review
  - Examples: `--set-status done 1.2.3`, `--set-status done 1.2.3 1.2.4 1.2.5`

## Behavior

1. Check if `.taskmanager/tasks.json` exists:
   ```bash
   test -f .taskmanager/tasks.json && echo "exists" || echo "not found"
   ```

2. Check if `jq` is installed (required for parsing):
   ```bash
   command -v jq &> /dev/null && echo "jq available" || echo "jq not found"
   ```

3. Use the `task-stats.sh` script from the plugin directory:
   ```bash
   ./scripts/task-stats.sh .taskmanager/tasks.json [mode]
   ```

4. Run the appropriate query based on the requested mode.

### Script Usage

ALWAYS use the script for all task statistics operations. The script handles shell escaping and provides consistent output.

IMPORTANT: Never call jq directly with inline queries. Always use the script to avoid shell escaping issues.

```bash
# ALWAYS USE THE SCRIPT - never run jq directly!
# The script handles shell escaping properly.

# Summary (default)
./scripts/task-stats.sh .taskmanager/tasks.json --summary

# Next task
./scripts/task-stats.sh .taskmanager/tasks.json --next

# Next 5 tasks
./scripts/task-stats.sh .taskmanager/tasks.json --next5

# JSON output for programmatic use
./scripts/task-stats.sh .taskmanager/tasks.json --json

# Get task by ID
./scripts/task-stats.sh .taskmanager/tasks.json --get 1.2.3

# Get specific property
./scripts/task-stats.sh .taskmanager/tasks.json --get 1.2.3 status
./scripts/task-stats.sh .taskmanager/tasks.json --get 1.2.3 complexity.scale

# Update status (single or multiple tasks)
./scripts/task-stats.sh .taskmanager/tasks.json --set-status done 1.2.3
./scripts/task-stats.sh .taskmanager/tasks.json --set-status done 1.2.3 1.2.4 1.2.5

# Other statistics
./scripts/task-stats.sh .taskmanager/tasks.json --status
./scripts/task-stats.sh .taskmanager/tasks.json --priority
./scripts/task-stats.sh .taskmanager/tasks.json --levels
./scripts/task-stats.sh .taskmanager/tasks.json --remaining
./scripts/task-stats.sh .taskmanager/tasks.json --time
./scripts/task-stats.sh .taskmanager/tasks.json --completion
```

---

## Output Format

Present the statistics in a clean, readable format. For the json mode, output raw JSON that can be piped to other tools.

Example summary output:
```
=== Task Statistics ===

Total: 150
Done: 45
In Progress: 3
Blocked: 2
Remaining: 100
Completion: 30%

--- By Status ---
blocked: 2
done: 45
draft: 5
in-progress: 3
planned: 95

--- By Priority ---
critical: 5
high: 25
medium: 80
low: 40

--- By Level ---
Level 1: 10 tasks
Level 2: 40 tasks
Level 3: 100 tasks

Estimated remaining: 360000 seconds (100 hours / 12.5 days)

=== Next Recommended Task ===
ID: 2.3.1
Title: Implement user authentication
Status: planned
Priority: high
Complexity: M (3)
Estimate: 4 hours

=== Next 5 Recommended Tasks ===
1. [2.3.1] Implement user authentication (high, M)
2. [2.3.2] Add password reset flow (high, S)
3. [1.4.1] Create database migrations (medium, S)
4. [1.4.2] Setup model relationships (medium, M)
5. [3.1.1] Design API endpoints (medium, M)
```

## Notes

- Most modes are **read-only** and do not modify any files.
- The `--set-status` mode **modifies** `.taskmanager/tasks.json` (creates backup first).
- Uses `jq` for efficient JSON parsing without loading entire file into context.
- Ideal for quick status checks before starting work.
- For full dashboard with critical path analysis, use `/mwguerra:taskmanager:dashboard`.
- For getting a single task, use `/mwguerra:taskmanager:get-task <id> [key]`.
- For updating status, use `/mwguerra:taskmanager:update-status <status> <id1> [id2...]`.
