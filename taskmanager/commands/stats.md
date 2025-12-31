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

3. If the utility script exists at the plugin location, use it. Otherwise, use inline jq commands.

4. Run the appropriate jq query based on the requested mode.

### Quick Inline Commands

If you need to run quick stats without the full script, use these jq commands:

**Get summary counts:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
{
  total: length,
  done: [.[] | select(.status == "done")] | length,
  in_progress: [.[] | select(.status == "in-progress")] | length,
  blocked: [.[] | select(.status == "blocked")] | length,
  remaining: [.[] | select(.status != "done" and .status != "canceled" and .status != "duplicate")] | length
}
' .taskmanager/tasks.json
```

**Get next recommended task:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
[.[] | select(.status == "done" or .status == "canceled" or .status == "duplicate") | .id] as $done_ids |
[
  .[] |
  select(
    (.status != "done" and .status != "canceled" and .status != "duplicate" and .status != "blocked") and
    ((.subtasks | length) == 0 or .subtasks == null)
  ) |
  select(
    (.dependencies == null) or (.dependencies | length == 0) or
    (.dependencies | all(. as $dep | $done_ids | index($dep) != null))
  )
] |
sort_by(
  (if .priority == "critical" then 0 elif .priority == "high" then 1 elif .priority == "medium" then 2 else 3 end),
  (.complexity.score // 3)
) |
.[0] // null |
if . then {id, title, priority, status, complexity: .complexity.scale, estimate_hours: ((.estimateSeconds // 0) / 3600)} else null end
' .taskmanager/tasks.json
```

**Get next 5 tasks (compact):**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
[.[] | select(.status == "done" or .status == "canceled" or .status == "duplicate") | .id] as $done_ids |
[
  .[] |
  select(
    (.status != "done" and .status != "canceled" and .status != "duplicate" and .status != "blocked") and
    ((.subtasks | length) == 0 or .subtasks == null)
  ) |
  select(
    (.dependencies == null) or (.dependencies | length == 0) or
    (.dependencies | all(. as $dep | $done_ids | index($dep) != null))
  )
] |
sort_by(
  (if .priority == "critical" then 0 elif .priority == "high" then 1 elif .priority == "medium" then 2 else 3 end),
  (.complexity.score // 3)
) |
.[0:5] | map({id, title, priority})
' .taskmanager/tasks.json
```

**Get counts by status:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
group_by(.status) | map({status: .[0].status, count: length}) | sort_by(.status)
' .taskmanager/tasks.json
```

**Get counts by level:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
map({level: (.id | split(".") | length)}) |
group_by(.level) | map({level: .[0].level, count: length}) | sort_by(.level)
' .taskmanager/tasks.json
```

**Get estimated time remaining:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
[
  .[] |
  select(
    (.status != "done" and .status != "canceled" and .status != "duplicate") and
    ((.subtasks | length) == 0 or .subtasks == null)
  ) |
  .estimateSeconds // 0
] | add // 0 |
{seconds: ., hours: (. / 3600 | floor), days: (. / 86400 | . * 10 | floor / 10)}
' .taskmanager/tasks.json
```

## Output Format

Present the statistics in a clean, readable format. For `--json` mode, output raw JSON that can be piped to other tools.

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
