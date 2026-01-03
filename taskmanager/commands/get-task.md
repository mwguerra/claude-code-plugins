---
allowed-tools: Bash
description: Get task details or specific property by ID without loading full tasks.json
argument-hint: "<id> [key] | Examples: 1.2.3 | 1.2.3 status | 1.2.3 complexity.scale"
---

# Get Task Command

You are implementing `taskmanager:get-task`.

## Purpose

This command provides a token-efficient way to retrieve task information by ID, without needing to load and parse the entire `tasks.json` file. You can get the full task object or extract a specific property.

## Arguments

- `$1` (required): The task ID to retrieve
- `$2` (optional): A specific key/property to extract (supports nested keys with dot notation)

## Behavior

### 1. Validate arguments

```bash
if [[ -z "$1" ]]; then
    echo "Usage: taskmanager:get-task <id> [key]"
    exit 1
fi
```

### 2. Query the task using jq

**Get full task object:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
.[] | select(.id == "1.2.3")
' .taskmanager/tasks.json
```

**Get specific property:**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
.[] | select(.id == "1.2.3") | .status
' .taskmanager/tasks.json
```

**Get nested property (e.g., complexity.scale):**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
.[] | select(.id == "1.2.3") | .complexity.scale
' .taskmanager/tasks.json
```

### 3. Handle not found

If the task ID doesn't exist, output an error:

```
Error: Task '1.2.3' not found
```

## Examples

**Get full task object:**
```
taskmanager:get-task 1.2.3
```

Output:
```json
{
  "id": "1.2.3",
  "title": "Implement user authentication",
  "status": "planned",
  "priority": "high",
  "complexity": {
    "score": 3,
    "scale": "M"
  },
  ...
}
```

**Get task status:**
```
taskmanager:get-task 1.2.3 status
```

Output:
```
planned
```

**Get task title:**
```
taskmanager:get-task 1.2.3 title
```

Output:
```
Implement user authentication
```

**Get nested property:**
```
taskmanager:get-task 1.2.3 complexity.scale
```

Output:
```
M
```

**Get task priority:**
```
taskmanager:get-task 1.2.3 priority
```

Output:
```
high
```

**Get estimate in seconds:**
```
taskmanager:get-task 1.2.3 estimateSeconds
```

Output:
```
7200
```

## Available Properties

Common properties you can query:

| Property | Description |
|----------|-------------|
| `id` | Task ID |
| `title` | Task title |
| `status` | Current status |
| `priority` | Task priority (low, medium, high, critical) |
| `type` | Task type (feature, bug, chore, analysis, spike) |
| `description` | Task description |
| `complexity` | Full complexity object |
| `complexity.score` | Complexity score (0-5) |
| `complexity.scale` | Complexity scale (XS, S, M, L, XL) |
| `estimateSeconds` | Estimated time in seconds |
| `startedAt` | When task was started |
| `completedAt` | When task was completed |
| `durationSeconds` | Actual duration |
| `dependencies` | Array of dependency task IDs |
| `parentId` | Parent task ID |

## Notes

- This command is **read-only** - it does not modify any files
- Uses `jq` for efficient JSON parsing without loading full file
- Supports nested property access using dot notation
- Returns `null` if the property doesn't exist on the task
- Requires `jq` to be installed
