---
allowed-tools: Skill(taskmanager)
description: Show the next available task or subtask that is ready to execute.
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

### 1. Find next available task

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
