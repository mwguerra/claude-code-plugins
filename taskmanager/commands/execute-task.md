---
allowed-tools: Skill(taskmanager), Skill(taskmanager-memory)
description: Execute a single task or subtask by ID, handling dependencies interactively if needed.
argument-hint: "<task-id> [--memory \"global memory\"] [--task-memory \"temp memory\"]"
---

# Execute Task Command

You are implementing `/mwguerra:taskmanager:execute-task`.

## Arguments

- `$1` (required): Task ID to execute (e.g., `1.2.3`)
- `--memory "description"` or `-gm "description"`: Add a global memory (persists to memories.json)
- `--task-memory "description"` or `-tm "description"`: Add a task-scoped memory (temporary, reviewed at task end)

## Behavior

1. **Parse arguments**:
   - `$1` must be provided (e.g., `1.2.3`).
   - If not provided, ask the user to specify an ID or suggest running `/mwguerra:taskmanager:next-task`.
   - Extract `--memory` / `-gm` value if provided.
   - Extract `--task-memory` / `-tm` value if provided.

2. **Process memory arguments**:
   - If `--memory` is provided:
     - Use the `taskmanager-memory` skill to create a new global memory in `.taskmanager/memories.json`.
     - Set `source.type = "user"`, `source.via = "execute-task"`.
     - Set reasonable defaults: `importance = 3`, `confidence = 0.9`, `status = "active"`.
   - If `--task-memory` is provided:
     - Add to `.taskmanager/state.json` → `taskMemory[]`:
       ```json
       {
         "content": "<the description>",
         "addedAt": "<current ISO timestamp>",
         "taskId": "$1",
         "source": "user"
       }
       ```

3. **Load task**:
   - Ask the `taskmanager` skill to load `.taskmanager/tasks.json` and find the task with `id == $1`.
   - If not found, inform the user and stop.

4. **Check dependencies**:
   - If the task has `dependencies` that are not `"done"`, `"canceled"`, or `"duplicate"`:
     - Use the AskUserQuestion tool to ask how to proceed, with options such as:
       - "Execute a dependency task first"
       - "Mark dependencies as done and continue"
       - "Abort execution of this task"
     - Act according to the user's answer.

5. **Load and apply memories** (PRE-EXECUTION):
   - Use the `taskmanager-memory` skill to query relevant memories for this task.
   - Load global memories from `.taskmanager/memories.json`:
     - Filter for `status = "active"`.
     - Match by `scope.tasks`, `scope.domains`, `scope.files`, `importance >= 3`.
   - Load task-scoped memories from `state.json.taskMemory[]`:
     - Filter for `taskId == $1` or `taskId == "*"`.
   - **Run conflict detection** on all loaded memories:
     - Check for file/pattern obsolescence.
     - Check for implementation divergence.
     - If conflicts detected, resolve using the conflict resolution workflow.
   - Display summary of applicable memories.
   - Store applied memory IDs in `state.json.appliedMemories[]`.
   - Increment `useCount` and update `lastUsedAt` for each applied memory.

6. **Start execution**:
   - Update the task `status` to `"in-progress"` if appropriate.
   - Update `.taskmanager/state.json`:
     - `currentStep = "execution"`
     - `mode = "interactive"`
     - `currentTaskId = $1`
     - `currentSubtaskPath = $1`
     - `lastUpdate` and `lastDecision`.

7. **Execute the task**:
   - Perform the code changes, file edits, or other work implied by the task.
   - Apply loaded memories as constraints during implementation.

8. **Post-execution memory review** (before marking done):
   - **Run conflict detection again** on all applied memories.
   - If conflicts detected, resolve using the conflict resolution workflow.
   - **Review task-scoped memories**:
     - If any task memories exist for this task (`taskId == $1`):
       - Ask the user: "Should any task memories be promoted to global memory?"
       - For each: "Promote to global memory" or "Discard".
       - Create global memories for promoted items.
       - Clear task memories for this task from `taskMemory[]`.
   - Clear `state.json.appliedMemories[]`.

9. **Complete execution**:
   - Update the leaf task `status` based on outcome:
     - `"done"`, `"blocked"`, `"paused"`, or `"needs-review"`.
   - **Recompute the macro status for all ancestor tasks** using the _Status propagation helper_ rules below.
   - Write the updated `.taskmanager/tasks.json` back to disk.
   - Update `.taskmanager/state.json`:
     - `currentTaskId = null`
     - `currentSubtaskPath = null`
     - `currentStep = "idle"` (or `"done"` if requested by the user)
     - `lastUpdate` / `lastDecision`.

10. **Summarize for the user**:
    - Final status of the task.
    - Memories that were applied and any conflicts resolved.
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
