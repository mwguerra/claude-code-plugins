---
allowed-tools: Skill(taskmanager)
description: Automatically start or resume executing tasks sequentially from .taskmanager/tasks.json.
argument-hint: "[max-tasks]"
---

# Run Tasks Command

You are implementing `/mwguerra:taskmanager:run-tasks`.

## Behavior

1. Determine an optional limit:
   - If the user provided `$1`, treat it as the maximum number of tasks to attempt in this run.
   - If no argument is provided, default to a small number (e.g., 3–5 tasks).

2. For each iteration up to the limit:
   1. Ask the `taskmanager` skill to:
      - Read `.taskmanager/tasks.json` and `.taskmanager/state.json`.
      - Find the **next available task** according to its selection logic:
        - Not done/canceled/duplicate
        - All dependencies satisfied
        - Leaf task or all subtasks completed
      - If no such task exists:
        - Stop and summarize that there are no more available tasks.
   2. At the **beginning** of the task:
      - Update the task `status` to `"in-progress"` if appropriate.
      - Update `.taskmanager/state.json`:
        - `currentStep = "execution"`
        - `mode = "autonomous"`
        - `currentTaskId = <task id>`
        - `currentSubtaskPath = <task id>`
        - `lastUpdate` / `lastDecision`
   3. Execute the task:
      - Perform the necessary edits, file operations, or code changes as implied by the task description.
   4. At the **end** of the task (for the leaf task you just executed):
      - Update the leaf task `status` based on outcome:
        - `"done"`, `"blocked"`, or `"canceled"` as appropriate.
      - **Immediately after updating the leaf status, recompute the macro status for all of its ancestor tasks using the _Status propagation helper_ rules below.**
      - Write the updated `.taskmanager/tasks.json` back to disk.
      - Update `.taskmanager/state.json`:
        - `currentTaskId = null` if not immediately chaining to another task.
        - `currentSubtaskPath = null`
        - `currentStep = "idle"` or `"done"` if this was the last task.
        - `lastUpdate` / `lastDecision`.

3. After finishing or reaching the limit:
   - Summarize:
     - Which tasks were executed (IDs + titles)
     - Any tasks that were skipped due to dependencies
     - The new high-level state (e.g. number of tasks done vs remaining).

---

## Status propagation helper (macro parent status)

Whenever this command changes the status of any **leaf** task, it MUST also update the status of all its **ancestor** tasks so that parents reflect the aggregate state of their subtasks.

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

- This helper should walk **bottom-up**: start from the leaf whose status changed, then its parent, then that parent’s parent, etc.
- You MUST NOT set a parent’s status independently of its children; it is always derived using the rules above.
- Always write back `.taskmanager/tasks.json` after propagation so other commands see consistent macro statuses.