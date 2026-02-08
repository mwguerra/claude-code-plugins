---
allowed-tools: Bash
description: Get task details or specific property by ID without loading full database
argument-hint: "<id> [key] | Examples: 1.2.3 | 1.2.3 status | 1.2.3 complexity_scale"
---

# Get Task Command

You are implementing `taskmanager:get-task`.

## Purpose

Retrieve task information by ID efficiently via SQL.

## Arguments

- `$1` (required): The task ID to retrieve
- `$2` (optional): A specific column to extract

## Behavior

### 1. Validate arguments

```bash
if [[ -z "$1" ]]; then
    echo "Usage: taskmanager:get-task <id> [column]"
    echo "Examples:"
    echo "  taskmanager:get-task 1.2.3"
    echo "  taskmanager:get-task 1.2.3 status"
    echo "  taskmanager:get-task 1.2.3 title"
    exit 1
fi
```

### 2. Query the task

**Get full task (no column specified):**

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks WHERE id = '$1';
" | jq '.[0] // empty'
```

If no result, output:
```
Error: Task '$1' not found
```

**Get specific column:**

```bash
sqlite3 .taskmanager/taskmanager.db "
SELECT $2 FROM tasks WHERE id = '$1';
"
```

## Available Columns

| Column | Description |
|--------|-------------|
| `id` | Task ID |
| `title` | Task title |
| `status` | Current status |
| `priority` | Task priority |
| `type` | Task type |
| `description` | Task description |
| `details` | Implementation details |
| `test_strategy` | How to verify task completion |
| `complexity_score` | Complexity score (0-5) |
| `complexity_scale` | Complexity scale (XS-XL) |
| `estimate_seconds` | Estimated time |
| `started_at` | Start timestamp |
| `completed_at` | Completion timestamp |
| `duration_seconds` | Actual duration |
| `dependencies` | JSON array of dependency IDs |
| `parent_id` | Parent task ID |
| `tags` | JSON array of tags |

## Examples

**Get full task:**
```bash
sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM tasks WHERE id = '1.2.3';"
```

**Get task status:**
```bash
sqlite3 .taskmanager/taskmanager.db "SELECT status FROM tasks WHERE id = '1.2.3';"
```

**Get task with subtask count:**
```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT t.*, (SELECT COUNT(*) FROM tasks c WHERE c.parent_id = t.id) as subtask_count
FROM tasks t WHERE t.id = '1.2.3';
"
```

## Notes

- This command is **read-only**
- Uses direct SQL queries, very efficient
- Returns JSON for full task, plain text for single column
