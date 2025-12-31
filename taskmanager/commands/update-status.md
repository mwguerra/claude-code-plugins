---
allowed-tools: Bash
description: Update task status by ID or list of IDs without loading the full tasks.json
argument-hint: "<status> <id1> [id2...] | Example: done 1.2.3 1.2.4"
---

# Update Status Command

You are implementing `/mwguerra:taskmanager:update-status`.

## Purpose

This command provides a token-efficient way to update task status for one or more tasks by their IDs, without needing to load and parse the entire `tasks.json` file.

## Arguments

- `$1` (required): The new status to set
- `$2...` (required): One or more task IDs to update

### Valid Statuses

- `draft` - Task is in draft state
- `planned` - Task is planned but not started
- `in-progress` - Task is currently being worked on
- `blocked` - Task is blocked by dependencies or issues
- `paused` - Task is temporarily paused
- `done` - Task is completed
- `canceled` - Task has been canceled
- `duplicate` - Task is a duplicate of another
- `needs-review` - Task needs review before proceeding

## Behavior

### 1. Validate arguments

```bash
# Check status and IDs are provided
if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Usage: /mwguerra:taskmanager:update-status <status> <id1> [id2...]"
    exit 1
fi
```

### 2. Run the update using jq

Use jq to efficiently update the status without loading the full file into context:

```bash
# Single task
jq --arg status "done" --arg id "1.2.3" '
def update_status:
  if .id == $id then
    .status = $status |
    if $status == "done" or $status == "canceled" or $status == "duplicate" then
      .completedAt = (now | todate)
    else . end |
    if $status == "in-progress" and .startedAt == null then
      .startedAt = (now | todate)
    else . end
  else . end |
  if .subtasks then .subtasks = [.subtasks[] | update_status] else . end;
.tasks = [.tasks[] | update_status]
' .taskmanager/tasks.json > .taskmanager/tasks.json.tmp && mv .taskmanager/tasks.json.tmp .taskmanager/tasks.json

# Multiple tasks
jq --arg status "done" --argjson ids '["1.2.3", "1.2.4", "1.2.5"]' '
def update_status:
  if .id as $tid | $ids | index($tid) != null then
    .status = $status |
    if $status == "done" or $status == "canceled" or $status == "duplicate" then
      .completedAt = (now | todate)
    else . end |
    if $status == "in-progress" and .startedAt == null then
      .startedAt = (now | todate)
    else . end
  else . end |
  if .subtasks then .subtasks = [.subtasks[] | update_status] else . end;
.tasks = [.tasks[] | update_status]
' .taskmanager/tasks.json > .taskmanager/tasks.json.tmp && mv .taskmanager/tasks.json.tmp .taskmanager/tasks.json
```

### 3. Automatic timestamp handling

When updating status, the script automatically:

- Sets `completedAt` to current timestamp when status becomes terminal (`done`, `canceled`, `duplicate`)
- Sets `startedAt` to current timestamp when status becomes `in-progress` (only if not already set)

### 4. Output confirmation

After updating, display confirmation:

```
Successfully updated 3 task(s) to status 'done':
  - 1.2.3
  - 1.2.4
  - 1.2.5
```

## Examples

**Mark single task as done:**
```
/mwguerra:taskmanager:update-status done 1.2.3
```

**Mark multiple tasks as done:**
```
/mwguerra:taskmanager:update-status done 1.2.3 1.2.4 1.2.5
```

**Set tasks to in-progress:**
```
/mwguerra:taskmanager:update-status in-progress 2.1.1
```

**Mark tasks as blocked:**
```
/mwguerra:taskmanager:update-status blocked 3.1 3.2
```

## Notes

- This command modifies `.taskmanager/tasks.json` directly
- Creates a backup before modification (`.taskmanager/tasks.json.bak`)
- Does NOT trigger status propagation to parent tasks - use with care
- For full status propagation, use `/mwguerra:taskmanager:execute-task` instead
- Requires `jq` to be installed
