---
allowed-tools: Skill(taskmanager)
description: Execute a single task or subtask by ID, handling dependencies interactively if needed.
argument-hint: "<task-id>"
---

# Execute Task Command

You are implementing `/mwguerra:taskmanager:execute-task`.

## Behavior

1. Require a task ID:
   - `$1` must be provided (e.g., `1.2.3`).
   - If not provided, ask the user to specify an ID or suggest running `/mwguerra:taskmanager:next-task`.

2. Ask the `taskmanager` skill to:
   - Load `.taskmanager/tasks.json` and find the task with `id == $1`.
   - If not found, inform the user and stop.

3. Check dependencies:
   - If the task has `dependencies` that are not `"done"`, `"canceled"`, or `"duplicate"`:
     - Use the AskUserQuestion tool to ask how to proceed, with options such as:
       - "Execute a dependency task first"
       - "Mark dependencies as done and continue"
       - "Abort execution of this task"
     - Act according to the user's answer:
       - If they choose to execute a dependency, recursively run this command for that dependency or delegate to the skill.
       - If they choose to abort, stop.

4. At the **start** of execution:
   - Update the task `status` to `"in-progress"` if appropriate.
   - Update `.taskmanager/state.json`:
     - `currentStep = "execution"`
     - `mode = "interactive"`
     - `currentTaskId = $1`
     - `currentSubtaskPath = $1`
     - `lastUpdate` and `lastDecision`.

5. Execute the task:
   - Perform the code changes, file edits, or other work implied by the task.

6. At the **end** of execution (for the leaf task you just executed):
   - Update the leaf task `status` based on outcome:
     - `"done"`, `"blocked"`, `"paused"`, or `"needs-review"`.
   - **Immediately after updating the leaf status, recompute the macro status for all of its ancestor tasks using the _Status propagation helper_ rules below.**
   - Write the updated `.taskmanager/tasks.json` back to disk.
   - Update `.taskmanager/state.json`:
     - `currentTaskId = null`
     - `currentSubtaskPath = null`
     - `currentStep = "idle"` (or `"done"` if requested by the user)
     - `lastUpdate` / `lastDecision`.

7. Summarize for the user:
   - Final status of the task
   - Any follow-up tasks or dependencies suggested.

---

## Status propagation helper (macro parent status)

Whenever this command changes the status of any **leaf** task (the specific ID the user asked to execute), it MUST also update the status of all its **ancestor** tasks so that parents reflect the aggregate state of their subtasks.

Conceptual algorithm (per parent, based on its **direct** children):

1. For the parent, collect the `status` of all its direct `subtasks`.

2. Apply these precedence rules in order:

   1. If **any** child is `"in-progress"`  
      → parent `status = "in-progress"`.

   2. Else if no child is `"in-progress"` and **any** child is `"blocked"`  
      → parent `status = "blocked"`.

   3. Else if no child is `"in-progress"` or `"blocked"` and **any** child is `"needs-review"`  
      → parent `status = "needs-review"`.

   4. Else if no child is `"in-progress"`, `"blocked"`, or `"needs-review"` and **any** child is in:  
      `"planned"`, `"draft"`, `"todo"`, `"paused"`  
      → parent `status = "planned"` (macro “not-started / planned” state).

   5. Else if **all** children are in `{"done", "canceled", "duplicate"}`:
      - If at least one child is `"done"` → parent `status = "done"`.
      - Else (all `"canceled"` or `"duplicate"`) → parent `status = "canceled"`.

3. After computing the parent’s new status, repeat this algorithm for its parent, and so on, up to the root.

Implementation notes:

- This helper should walk **bottom-up** from the executed leaf task to the root.
- You MUST NOT set a parent’s status by hand; always derive it from its children using these rules.
- Always write back `.taskmanager/tasks.json` after propagation so other commands (like `/dashboard` and `/next-task`) see a consistent, macro view of progress.
