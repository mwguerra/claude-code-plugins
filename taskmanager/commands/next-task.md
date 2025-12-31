---
allowed-tools: Skill(taskmanager)
description: Find and display the next task ready for execution based on dependencies and priority
argument-hint: "[--debug]"
---

# Next Task Command

You are implementing `/mwguerra:taskmanager:next-task`.

## Arguments

- `--debug` or `-d`: Enable verbose debug logging to `.taskmanager/logs/debug.log`

## Behavior

### 0. Initialize logging (if --debug provided)

If `--debug` / `-d` flag is present:
1. Generate a unique session ID.
2. Set `state.json.logging.debugEnabled = true` and `logging.sessionId`.

### 1. Find next available task (Token-Efficient)

**IMPORTANT:** When the `tasks.json` file is large (exceeds ~25k tokens), you MUST use token-efficient methods:

**Option A: Use stats command**
```
/mwguerra:taskmanager:stats --next
```
This returns the next recommended task without loading the full file.

**Option B: Use jq directly**
```bash
jq -r '
def flatten_all: . as $t | [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);
[.tasks[] | flatten_all] | add // [] |
[.[] | select(.status == "done" or .status == "canceled" or .status == "duplicate") | .id] as $done_ids |
[.[] | select(
  (.status != "done" and .status != "canceled" and .status != "duplicate" and .status != "blocked") and
  ((.subtasks | length) == 0 or .subtasks == null)
) | select(
  (.dependencies == null) or (.dependencies | length == 0) or
  (.dependencies | all(. as $dep | $done_ids | index($dep) != null))
)] |
sort_by(
  (if .priority == "critical" then 0 elif .priority == "high" then 1 elif .priority == "medium" then 2 else 3 end),
  (.complexity.score // 3)
) | .[0] | {id, title, status, priority, complexity: .complexity.scale, estimate_hours: ((.estimateSeconds // 0) / 3600)}
' .taskmanager/tasks.json
```

**When to read full file:** Only use the standard approach below if:
- The file is small enough (< 25k tokens)
- You need additional task details

Standard approach (for small files):
Ask the `taskmanager` skill to:
- Read `.taskmanager/tasks.json`.
- Compute the **next available task** using the selection rules:
  - Status is not `"done"`, `"canceled"`, or `"duplicate"`.
  - All dependencies (if any) are in one of those finished states.
  - Task is a leaf or all its subtasks are completed.

### 2. Display result

If a candidate is found:
- Display:
  - `id`
  - `title`
  - `status`
  - `priority`
  - `complexity` (score + scale)
  - Any `dependencies`
- Do **not** modify `tasks.json` or `state.json`.

If no candidate is found:
- Inform the user that there are no available tasks with satisfied dependencies.

### 3. Cleanup

If `--debug` was enabled:
- Reset `state.json.logging.debugEnabled = false`
- Reset `state.json.logging.sessionId = null`

## Logging Requirements

**To debug.log** (ONLY when `--debug` enabled):
- Task tree loading details
- Task selection algorithm steps
- Why specific tasks were skipped
