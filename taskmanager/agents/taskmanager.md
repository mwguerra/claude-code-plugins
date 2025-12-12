---
name: taskmanager
description: >
  Data and invariants spec for the MWGuerra Task Manager. Defines the structure
  and rules for .taskmanager/tasks.json, .taskmanager/state.json, and logs.
  All planning and execution behavior is defined in the taskmanager skill
  and related commands under .claude/.
version: 1.0.0
---

# MWGuerra Task Manager – Agent Spec (Slim)

This document defines the **data contracts and invariants** for the
`.taskmanager` runtime.

It does **not** define behavior (planning, execution, PRD ingestion, auto-run,
dashboard, or commands). All behavior lives in:

- `.claude/skills/mwguerra/taskmanager/SKILL.md`
- `.claude/skills/mwguerra/taskmanager/PRD-INGEST-EXAMPLES.md`
- `.claude/commands/*.md`

This document defines what the system **must** maintain, not how it performs any workflow.

---

## 1. Folder Layout

At the project root:

```text
.taskmanager/
  AGENT-SPEC.md                 # This file – data contract & invariants
  tasks.json                    # Active tasks + nested subtasks
  state.json                    # Current agent state
  schemas/
    tasks.schema.json           # JSON Schema for tasks.json
    state.schema.json           # JSON Schema for state.json
  logs/
    errors.log                  # Append-only error log
    debug.log                   # Verbose debug tracing
    decisions.log               # High-level planning/decision log
```

Agents MUST:

* Keep `tasks.json` and `state.json` **valid JSON**.
* Keep them **schema-compliant** at all times.
* Write decisions and errors to the appropriate log files.

Initialization of `.taskmanager/` SHOULD be done using an explicit command (e.g. `/mwguerra:taskmanager:init`)
which copies initial structure from:

```
.claude/skills/mwguerra/taskmanager/template/.taskmanager/
```

---

## 2. Tasks Contract (`tasks.json`)

`tasks.json` must conform to the schema in:

```
.taskmanager/schemas/tasks.schema.json
```

### 2.1 Top-level structure

```jsonc
{
  "version": "1.0.0",
  "project": {
    "id": "project-id",
    "name": "Project Name",
    "description": "Optional description."
  },
  "tasks": [
    /* top-level tasks */
  ]
}
```

### 2.2 Task shape (required core fields)

Every task object MUST contain:

* `id` — string, matches: `^[0-9]+(\.[0-9]+)*$`
* `title` — string
* `status` — one of:

  * `draft`, `planned`, `in-progress`, `blocked`, `paused`,
    `done`, `canceled`, `duplicate`, `needs-review`
* `type` — one of:

  * `feature`, `bug`, `chore`, `analysis`, `spike`
* `priority` — `low`, `medium`, `high`, `critical`
* `complexity`:

  * `score` — number (0–5)
  * `scale` — `XS`, `S`, `M`, `L`, `XL`
  * May include `reasoning`, `recommendedSubtasks`, `expansionPrompt`
* `subtasks` — array of tasks (same schema)

### 2.3 Hierarchy rules

* IDs are **unique** across all tasks.
* Dotted paths define hierarchy:

  * `"1"` → top level
  * `"1.2"` → second child of task 1
  * `"1.2.3"` → third child of task 1.2
* `parentId` MUST:

  * Be `null` for top-level tasks
  * Match the actual parent’s ID for subtasks

The tree MUST match the ID structure exactly.

### 2.4 Task Domains

  - `domain` can be:
    - `"software"` (default when omitted)
    - `"writing"` (for books, articles, documentation, fiction, etc.)

  - When `domain = "writing"`:
    - `writingType` identifies the work format (book, article, documentation, short-story, etc.).
    - `contentUnit` identifies the granularity (chapter, section, scene, etc.).
    - `targetWordCount` / `currentWordCount` are optional but useful for progress tracking.
    - `writingStage` indicates the current stage in the writing pipeline (idea, outline, draft, rewrite, edit, copyedit, proofread, ready-to-publish, published).

  - All other invariants (status propagation, time estimation, dependencies, critical path) are domain-agnostic and apply equally to software and writing tasks.


### 2.5 Minimal valid example

```jsonc
{
  "version": "1.0.0",
  "project": {
    "id": "unknown",
    "name": "Unknown project",
    "description": "Initialized by taskmanager."
  },
  "tasks": [
    {
      "id": "1",
      "title": "Initial setup",
      "status": "planned",
      "type": "chore",
      "priority": "medium",
      "complexity": {
        "score": 1,
        "scale": "S",
        "reasoning": "Simple one-step task.",
        "recommendedSubtasks": 0
      },
      "parentId": null,
      "subtasks": []
    }
  ]
}
```

### 2.6 Time & estimation invariants

  - `estimateSeconds`
    - Leaf tasks: MUST be non-null (≥ 0) once planning is complete.
    - Parent tasks: SHOULD equal the sum of `estimateSeconds` of their direct children.
  - `startedAt` / `completedAt`
    - Set only by the runtime when a leaf task enters `"in-progress"` or a terminal state.
    - Stored as ISO 8601 UTC timestamps.
  - `durationSeconds`
    - Computed as `completedAt - startedAt` in seconds, when a leaf becomes terminal.
    - Never negative; missing if `startedAt` was not set.

#### Status and Estimates for parent tasks
  - Status: macro view derived from children (see 8.5 in the skill).
  - Estimates: macro sum of child `estimateSeconds`, not hand-authored.

---

## 3. Project Memory (.taskmanager/memories.json)

The Task Manager runtime also owns a project-wide memory store:

- `.taskmanager/memories.json`
- Schema: `.taskmanager/schemas/memories.schema.json`

**Purpose**

Capture long-lived project knowledge that should survive across sessions, tasks, and agents:

- Architectural and product decisions
- Invariants and constraints
- Common pitfalls, bugfixes, and workarounds
- Conventions, naming rules, testing rules
- Repeated errors and their resolutions

**Invariants**

- MUST conform to `MWGuerraTaskManagerMemories` schema.
- IDs are stable (`M-0001`, `M-0002`, …).
- `status = "deprecated"` or `"superseded"` memories MUST NOT be deleted; they stay for history.
- `importance >= 4` memories SHOULD be considered whenever planning or executing high-impact tasks.
- `autoUpdatable` MUST be `false` for user-created memories (`source.type = "user"`).
- `conflictResolutions[]` MUST record every conflict resolution with timestamp and reason.

**Memory Types**

There are two scopes of memory:

1. **Global Memory** (persisted in `memories.json`):
   - Added via `--memory` / `-gm` command argument or `/memory add` command.
   - Persists across all tasks and sessions.
   - User-created memories require user approval for any changes.

2. **Task-Scoped Memory** (stored in `state.json.taskMemory[]`):
   - Added via `--task-memory` / `-tm` command argument.
   - Temporary, lives only for duration of task or batch.
   - Reviewed for promotion to global at task completion.
   - `taskId = "*"` indicates batch-level memory (applies to all tasks in a run).

**Lifecycle**

- **Creation**: When a user, agent, or command makes a decision that should apply to future work.
- **Update**: When a memory is refined, corrected, or superseded.
- **Conflict Detection**: Runs automatically at task start and end, checking for:
  - File/pattern obsolescence (referenced files no longer exist)
  - Implementation divergence (code contradicts memory)
  - Test failures in memory-scoped areas
- **Conflict Resolution**: Depends on ownership:
  - User-created (`source.type = "user"`): ALWAYS requires user approval.
  - System-created: Can auto-update for refinements, requires approval for reversals.
- **Usage Tracking**: When applied to a task, `useCount++` and `lastUsedAt` updated.

---

## 4. State Contract (`state.json`)

`state.json` must conform to:

```
.taskmanager/schemas/state.schema.json
```

It is a **checkpoint** describing what the system is doing now.

### 3.1 Required fields

* `version`
* `currentTaskId` — string or null
* `currentSubtaskPath` — string or null
* `currentStep` — one of:

  * `starting`, `planning-top-level`, `expanding-subtasks`,
    `dependency-analysis`, `execution`, `verification`,
    `idle`, `done`
* `mode` — `autonomous`, `interactive`, `paused`
* `startedAt`
* `lastUpdate`
* `evidence`:

  * `filesCreated`: string[]
  * `filesModified`: string[]
  * `commitSha`: string or null
  * `testsPassingBefore`: integer
  * `testsPassingAfter`: integer
* `verificationsPassed`:

  * `filesCreated`, `filesNonEmpty`, `gitChangesExist`,
    `testsPass`, `committed` — all boolean

Other optional fields:

* `loop`
* `contextSnapshot`
* `lastDecision`
* `taskMemory` — array of task-scoped memories (see 4.2)
* `appliedMemories` — array of global memory IDs currently being applied

### 4.2 Task Memory fields

`taskMemory` stores temporary, task-scoped memories:

```jsonc
{
  "taskMemory": [
    {
      "content": "Focus on error handling in this task",
      "addedAt": "2025-12-11T10:00:00Z",
      "taskId": "1.2.3",       // Or "*" for batch-level
      "source": "user"         // Or "system"
    }
  ],
  "appliedMemories": ["M-0001", "M-0003"]  // Global memories currently in use
}
```

**Invariants**:
- `taskId` MUST be a valid task ID pattern OR `"*"` for batch-level memories.
- `taskMemory[]` is cleared for each task at task completion (after promotion review).
- `"*"` task memories are cleared at batch completion.
- `appliedMemories[]` is cleared after each task's post-execution memory review.

### 4.3 Minimal valid example

```jsonc
{
  "version": "1.0.0",
  "currentTaskId": null,
  "currentSubtaskPath": null,
  "currentStep": "starting",
  "mode": "interactive",
  "startedAt": "2025-01-01T00:00:00.000Z",
  "lastUpdate": "2025-01-01T00:00:00.000Z",
  "evidence": {
    "filesCreated": [],
    "filesModified": [],
    "commitSha": null,
    "testsPassingBefore": 0,
    "testsPassingAfter": 0
  },
  "verificationsPassed": {
    "filesCreated": false,
    "filesNonEmpty": false,
    "gitChangesExist": false,
    "testsPass": false,
    "committed": false
  }
}
```

---

## 5. Logs Contract

Logs live under:

```
.taskmanager/logs/
```

### 4.1 Files

* `errors.log`
* `debug.log`
* `decisions.log`

### 4.2 Rules

* Logs are **append-only**.
* Agents SHOULD use timestamped lines.
* Recommended format:

```text
2025-11-11T01:00:00Z [DECISION] created tasks 1, 1.1, 1.2
2025-11-11T01:02:00Z [ERROR] failed to parse tasks.json, auto-fixed trailing comma
```

---

## 6. Interop Rules (Very Important)

All planning, execution, dashboard, next-task, and other features must:

1. Treat this document as the **contract** for:

   * `tasks.json`
   * `state.json`
   * `memories.json`
   * Logging rules
2. Conform strictly to the schemas in `.taskmanager/schemas/`
3. Delegate all behavior to:

   * `.claude/skills/mwguerra/taskmanager/SKILL.md` — task management behavior
   * `.claude/skills/mwguerra/taskmanager-memory/SKILL.md` — memory management behavior
   * `.claude/commands/mwguerra/taskmanager/*.md` — command implementations

4. For memory operations:

   * Use the `taskmanager-memory` skill for all memory management
   * Run conflict detection at task start AND end
   * Always ask user for approval when modifying user-created memories
   * Track `appliedMemories` during execution and clear after task completion
   * Review task-scoped memories for promotion before marking task as done

This file is intentionally **behavior-light**.
Its purpose is to define *what the data must look like*, not how tasks are planned or executed.

```
