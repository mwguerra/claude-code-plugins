---
allowed-tools: Skill(taskmanager)
description: Show the next available task or subtask that is ready to execute.
---

# Next Task Command

You are implementing `/mwguerra:taskmanager:next-task`.

## Behavior

1. Ask the `taskmanager` skill to:
   - Read `.taskmanager/tasks.json`.
   - Compute the **next available task** using the selection rules:
     - Status is not `"done"`, `"canceled"`, or `"duplicate"`.
     - All dependencies (if any) are in one of those finished states.
     - Task is a leaf or all its subtasks are completed.

2. If a candidate is found:
   - Display:
     - `id`
     - `title`
     - `status`
     - `priority`
     - `complexity` (score + scale)
     - Any `dependencies`
   - Do **not** modify `tasks.json` or `state.json`.

3. If no candidate is found:
   - Inform the user that there are no available tasks with satisfied dependencies.
