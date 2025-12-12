---
allowed-tools: Skill(taskmanager), Skill(taskmanager-memory)
description: Automatically start or resume executing tasks sequentially from .taskmanager/tasks.json.
argument-hint: "[max-tasks] [--memory \"global memory\"] [--task-memory \"temp memory\"] [--debug]"
---

# Run Tasks Command

You are implementing `/mwguerra:taskmanager:run-tasks`.

## Arguments

- `$1` (optional): Maximum number of tasks to execute in this run (default: 3-5)
- `--memory "description"` or `-gm "description"`: Add a global memory (persists to memories.json, applies to all tasks)
- `--task-memory "description"` or `-tm "description"`: Add a batch task memory (applies to all tasks in this run, reviewed at batch end)
- `--debug` or `-d`: Enable verbose debug logging to `.taskmanager/logs/debug.log`

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID (e.g., `sess-<8-random-chars>`).
2. Check for `--debug` / `-d` flag.
3. Update `.taskmanager/state.json`:
   - Set `logging.sessionId` to the generated ID.
   - Set `logging.debugEnabled = true` if `--debug` flag present, else `false`.
4. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started run-tasks batch (max: $1 tasks)
   ```

### 1. Parse arguments and initialize

1. **Parse arguments**:
   - Extract max tasks from `$1` (default: 3-5 if not provided).
   - Extract `--memory` / `-gm` value if provided.
   - Extract `--task-memory` / `-tm` value if provided.
   - Extract `--debug` / `-d` flag if provided.

2. **Process memory arguments at batch start**:
   - If `--memory` is provided:
     - Use the `taskmanager-memory` skill to create a new global memory in `.taskmanager/memories.json`.
     - Set `source.type = "user"`, `source.via = "run-tasks"`.
     - Set reasonable defaults: `importance = 3`, `confidence = 0.9`, `status = "active"`.
   - If `--task-memory` is provided:
     - Add to `.taskmanager/state.json` → `taskMemory[]` with `taskId = "*"` (applies to all tasks in batch):
       ```json
       {
         "content": "<the description>",
         "addedAt": "<current ISO timestamp>",
         "taskId": "*",
         "source": "user"
       }
       ```

3. **Initialize deferred data**:
   - `deferredConflicts = []` (conflicts to present at batch end).
   - `executedTasks = []` (track what was executed).

### 2. Task iteration loop

For each iteration up to the limit:

#### 2.1 Find next task
- Ask the `taskmanager` skill to read `.taskmanager/tasks.json` and `.taskmanager/state.json`.
- Find the **next available task** according to its selection logic:
  - Not done/canceled/duplicate
  - All dependencies satisfied
  - Leaf task or all subtasks completed
- If no such task exists:
  - Stop and proceed to batch summary.

#### 2.2 Load and apply memories (PRE-EXECUTION)
- Use the `taskmanager-memory` skill to query relevant memories for this task.
- Load global memories from `.taskmanager/memories.json`:
  - Filter for `status = "active"`.
  - Match by `scope.tasks`, `scope.domains`, `scope.files`, `importance >= 3`.
- Load task-scoped memories from `state.json.taskMemory[]`:
  - Filter for `taskId == <current task id>` or `taskId == "*"`.
- **Run conflict detection** on all loaded memories:
  - **Critical conflicts** (importance >= 4):
    - Pause execution.
    - Present conflict to user.
    - Wait for resolution before continuing.
  - **Warning/Info conflicts** (importance < 4):
    - Add to `deferredConflicts[]`.
    - Continue execution.
- Display summary of applicable memories.
- Store applied memory IDs in `state.json.appliedMemories[]`.
- Increment `useCount` and update `lastUsedAt` for each applied memory.

#### 2.3 Start execution
- Update the task `status` to `"in-progress"` if appropriate.
- Update `.taskmanager/state.json`:
  - `currentStep = "execution"`
  - `mode = "autonomous"`
  - `currentTaskId = <task id>`
  - `currentSubtaskPath = <task id>`
  - `lastUpdate` / `lastDecision`

#### 2.4 Execute the task
- Perform the necessary edits, file operations, or code changes as implied by the task description.
- Apply loaded memories as constraints during implementation.

#### 2.5 Post-execution memory review
- **Run conflict detection again** on all applied memories.
- **Critical conflicts**: Pause and resolve.
- **Warning/Info conflicts**: Add to `deferredConflicts[]`.
- **Review task-specific memories** (NOT `"*"` memories):
  - If any task memories exist for this specific task (`taskId == <task id>`):
    - Ask the user: "Should any task memories be promoted to global memory?"
    - Create global memories for promoted items.
    - Clear those specific task memories from `taskMemory[]`.
- Clear `state.json.appliedMemories[]`.

#### 2.6 Complete task
- Update the leaf task `status` based on outcome:
  - `"done"`, `"blocked"`, or `"canceled"` as appropriate.
- **Recompute the macro status for all ancestor tasks** using the _Status propagation helper_ rules below.
- Write the updated `.taskmanager/tasks.json` back to disk.
- Update `.taskmanager/state.json`:
  - `currentTaskId = null` if not immediately chaining to another task.
  - `currentSubtaskPath = null`
  - `currentStep = "idle"` or continue to next iteration.
  - `lastUpdate` / `lastDecision`.
- Add task to `executedTasks[]`.

### 3. Batch completion

After finishing or reaching the limit:

1. **Review batch task memories** (where `taskId == "*"`):
   - If any `"*"` task memories exist:
     - Ask the user: "These memories were applied to all tasks in this batch. Should any be promoted to global memory?"
     - For each: "Promote to global memory" or "Discard".
     - Create global memories for promoted items.
   - Clear all `"*"` task memories from `taskMemory[]`.

2. **Present deferred conflicts** (if any):
   - Show summary of all warning/info conflicts encountered during the batch.
   - For each conflict, ask user how to resolve.

3. **Summarize**:
   - Which tasks were executed (IDs + titles).
   - Memories that were applied.
   - Any tasks that were skipped due to dependencies.
   - Any conflicts that were resolved or deferred.
   - The new high-level state (e.g. number of tasks done vs remaining).

4. **Cleanup logging session**:
   - Log to `decisions.log`:
     ```
     <timestamp> [DECISION] [<session-id>] Completed run-tasks batch: N tasks executed, M remaining
     ```
   - Reset `.taskmanager/state.json`:
     - Set `logging.debugEnabled = false`
     - Set `logging.sessionId = null`

---

## Logging Requirements

Throughout batch execution, this command MUST log:

**To errors.log** (ALWAYS):
- Any errors encountered during task execution
- Conflict detection results when conflicts are found
- Dependency resolution failures

**To decisions.log** (ALWAYS):
- Batch start and completion
- Each task start and completion
- Memory application per task
- Conflict resolutions
- Memory promotions

**To debug.log** (ONLY when `--debug` enabled):
- Task selection algorithm details
- Memory matching per task
- Conflict detection steps
- Full batch state at start/end

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