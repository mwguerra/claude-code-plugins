---
description: >
  Data and invariants spec for the MWGuerra Task Manager. Defines the structure
  and rules for .taskmanager/tasks.json, .taskmanager/state.json, and logs.
  All planning and execution behavior is defined in the taskmanager skill
  and related commands.
version: 1.0.0
---

# MWGuerra Task Manager – Agent Spec

This document defines the **data contracts and invariants** for the
`.taskmanager` runtime.

It does **not** define behavior (planning, execution, PRD ingestion, auto-run,
dashboard, or commands). All behavior lives in the plugin's skills and commands.

---

## Plugin Resources

This agent has access to the following resources within the `taskmanager` plugin:

### Commands (11 total)

| Command | Description |
|---------|-------------|
| `taskmanager:init` | Initialize a `.taskmanager` directory in the project if it does not exist |
| `taskmanager:plan` | Parse PRD content and generate a hierarchical task tree with dependencies and complexity |
| `taskmanager:dashboard` | Display a text-based progress dashboard with status counts, completion metrics, and critical path |
| `taskmanager:next-task` | Find and display the next available task based on dependencies and priority |
| `taskmanager:execute-task` | Execute a single task by ID or find the next available task with memory support |
| `taskmanager:run-tasks` | Autonomously execute tasks in batch with progress tracking and memory support |
| `taskmanager:stats` | Get token-efficient statistics using the task-stats.sh script |
| `taskmanager:get-task` | Get a specific task by ID without loading the full file (uses jq) |
| `taskmanager:update-status` | Batch update task status for one or more tasks efficiently |
| `taskmanager:memory` | Manage project memories - add, list, show, update, deprecate with conflict detection |
| `taskmanager:migrate-archive` | Archive completed tasks to reduce tasks.json size |

### Skills (2 total)

| Skill | Description |
|-------|-------------|
| `taskmanager` | Core task management - parse PRDs, generate hierarchical tasks, manage status propagation, time estimation |
| `taskmanager-memory` | Memory management - constraints, decisions, conventions with conflict detection and resolution |

### Scripts

| Script | Description |
|--------|-------------|
| `scripts/task-stats.sh` | Efficient bash/jq script for task statistics, queries, and status updates |

### Template

The initialization template is located at:
```
skills/taskmanager/template/.taskmanager/
```

This template contains the initial structure for new projects including schemas and starter files.

---

## 1. Folder Layout

At the project root after initialization:

```text
.taskmanager/
  tasks.json                    # Active tasks + stubs for archived tasks
  tasks-archive.json            # Full details of archived (completed) tasks
  state.json                    # Current agent state
  memories.json                 # Project-wide memory store
  schemas/
    tasks.schema.json           # JSON Schema for tasks.json
    tasks-archive.schema.json   # JSON Schema for tasks-archive.json
    state.schema.json           # JSON Schema for state.json
    memories.schema.json        # JSON Schema for memories.json
  logs/
    errors.log                  # Append-only error log
    debug.log                   # Verbose debug tracing
    decisions.log               # High-level planning/decision log
```

### 1.1 Token-Efficient Task Operations

For large `tasks.json` files that exceed token limits, utility commands and scripts are available:

#### Using Commands

```bash
# Get statistics in JSON format
taskmanager:stats --json

# Get a specific task by ID
taskmanager:get-task 1.2.3
taskmanager:get-task 1.2.3 status
taskmanager:get-task 1.2.3 complexity.scale

# Update status for tasks
taskmanager:update-status done 1.2.3
taskmanager:update-status done 1.2.3 1.2.4 1.2.5
```

#### Using the Script Directly

```bash
./scripts/task-stats.sh .taskmanager/tasks.json [mode]
```

**Available modes:**
- `--summary` - Full text summary (default)
- `--json` - Full JSON output for programmatic use
- `--next` - Next recommended task
- `--next5` - Next 5 recommended tasks
- `--status` - Task counts by status
- `--priority` - Task counts by priority
- `--levels` - Task counts by level depth
- `--remaining` - Count of remaining tasks
- `--time` - Estimated time remaining
- `--completion` - Completion statistics
- `--get <id> [key]` - Get task by ID, optionally extract specific key
- `--set-status <status> <id1> [id2...]` - Update status for one or more tasks

#### When to use token-efficient operations:
- When `tasks.json` exceeds ~25k tokens
- Before batch execution to get quick overview
- To find next task without loading full file
- To update status for multiple tasks efficiently

Agents MUST:

* Keep `tasks.json` and `state.json` **valid JSON**.
* Keep them **schema-compliant** at all times.
* Write decisions and errors to the appropriate log files.

Initialization of `.taskmanager/` SHOULD be done using:

```
taskmanager:init
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
  * Match the actual parent's ID for subtasks

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
  - Status: macro view derived from children (see status propagation rules in the skill).
  - Estimates: macro sum of child `estimateSeconds`, not hand-authored.

### 2.7 Archived Tasks and Stubs

When tasks reach terminal status (`done`, `canceled`, `duplicate`), they are **archived** to prevent `tasks.json` from growing too large.

#### Stub structure

Archived tasks remain in `tasks.json` as **stubs** with `archivedRef: true`:

```jsonc
{
  "id": "1.2.3",
  "title": "Implement user auth",
  "status": "done",
  "parentId": "1.2",
  "priority": "high",
  "complexity": { "score": 3, "scale": "M" },
  "estimateSeconds": 3600,
  "durationSeconds": 4200,
  "completedAt": "2025-12-29T10:00:00Z",
  "archivedRef": true,
  "subtasks": []
}
```

**Stub invariants:**
- MUST contain: `id`, `title`, `status`, `parentId`, `priority`, `complexity`, `archivedRef`, `subtasks`
- SHOULD contain for metrics: `estimateSeconds`, `durationSeconds`, `completedAt`
- `subtasks` MUST be `[]` (children are archived separately)
- `archivedRef` MUST be `true`

#### Full task details in archive

Full task objects are stored in `tasks-archive.json` with an `archivedAt` timestamp.

**Archive invariants:**
- Tasks in archive MUST have terminal status
- Tasks in archive MUST have `archivedAt` timestamp
- If un-archived, `unarchivedAt` is added (entry not deleted, for audit trail)
- Corresponding stub in `tasks.json` MUST have `archivedRef: true`

---

## 3. Archive Contract (`tasks-archive.json`)

`tasks-archive.json` must conform to the schema in:

```
.taskmanager/schemas/tasks-archive.schema.json
```

### 3.1 Top-level structure

```jsonc
{
  "version": "1.0.0",
  "project": {
    "id": "project-id",
    "name": "Project Name"
  },
  "lastUpdated": "2025-12-29T15:30:00Z",
  "tasks": [
    /* archived task objects with archivedAt field */
  ]
}
```

### 3.2 Archived task shape

Each archived task has the same shape as a regular task, plus:

- `archivedAt` — ISO 8601 timestamp when archived (required)
- `unarchivedAt` — ISO 8601 timestamp if restored (optional, for audit trail)

### 3.3 Invariants

- Archive is **append-only** for archival (new tasks are added when they complete).
- Un-archiving adds `unarchivedAt` timestamp; entry is NOT deleted.
- `lastUpdated` MUST be updated whenever a task is archived or un-archived.
- All tasks in archive MUST have terminal status.

---

## 4. Project Memory (`.taskmanager/memories.json`)

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
   - Added via `--memory` / `-gm` command argument or `taskmanager:memory add` command.
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

## 5. State Contract (`state.json`)

`state.json` must conform to:

```
.taskmanager/schemas/state.schema.json
```

It is a **checkpoint** describing what the system is doing now.

### 5.1 Required fields

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
* `taskMemory` — array of task-scoped memories
* `appliedMemories` — array of global memory IDs currently being applied

### 5.2 Task Memory fields

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

### 5.3 Minimal valid example

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

## 6. Logs Contract

Logs live under:

```
.taskmanager/logs/
```

### 6.1 Log Files

| File | Purpose | When to Write |
|------|---------|---------------|
| `errors.log` | Runtime errors, validation failures, conflicts | ALWAYS when errors occur |
| `decisions.log` | High-level planning decisions, task status changes, memory operations | ALWAYS during execution |
| `debug.log` | Verbose tracing, intermediate states, detailed conflict analysis | ONLY when `--debug` flag is enabled |

### 6.2 Logging Rules

* Logs are **append-only**. Never truncate or overwrite.
* All log entries MUST include an ISO 8601 timestamp.
* All log entries SHOULD include a session ID for correlation (from `state.json.logging.sessionId`).

### 6.3 Log Entry Format

```text
<timestamp> [<level>] [<session-id>] <message>
```

**Levels:**
- `ERROR` — Failures, exceptions, validation errors
- `DECISION` — Planning choices, task transitions, memory changes
- `DEBUG` — Verbose tracing (only when debug enabled)

**Examples:**

```text
2025-12-11T10:00:00Z [DECISION] [sess-abc123] Started task 1.2.3: "Implement user auth"
2025-12-11T10:00:01Z [DECISION] [sess-abc123] Applied memories: M-0001, M-0003
2025-12-11T10:00:02Z [ERROR] [sess-abc123] Conflict detected: M-0001 references deleted file app/OldAuth.php
2025-12-11T10:00:03Z [DEBUG] [sess-abc123] Loading task tree, found 15 tasks, 8 pending
2025-12-11T10:05:00Z [DECISION] [sess-abc123] Completed task 1.2.3 with status "done"
```

### 6.4 What to Log

**errors.log** — ALWAYS write:
- JSON parse/validation failures
- Schema validation errors
- File I/O errors
- Memory conflict detection results
- Dependency resolution failures
- Any exception or unexpected state

**decisions.log** — ALWAYS write:
- Task creation (from planning)
- Task status transitions (planned → in-progress → done)
- Memory creation, update, deprecation, supersession
- Memory application (which memories applied to which task)
- Conflict resolution outcomes
- Batch start/end summaries

**debug.log** — ONLY write when `state.json.logging.debugEnabled == true`:
- Full task tree state before/after operations
- Memory matching algorithm details (why a memory was/wasn't selected)
- Conflict detection intermediate steps
- File existence checks
- Schema validation details
- Performance timing information

### 6.5 Debug Mode

Debug logging is **disabled by default** to avoid excessive log growth.

To enable debug logging for a command:
- Pass `--debug` or `-d` flag to any command
- This sets `state.json.logging.debugEnabled = true` for the session
- Debug mode persists until the command completes

Commands MUST:
1. Check for `--debug` / `-d` flag at startup
2. Set `state.json.logging.debugEnabled = true` if present
3. Generate a unique `sessionId` for log correlation
4. Reset `debugEnabled = false` at command completion

### 6.6 Logging Configuration in state.json

```jsonc
{
  "logging": {
    "debugEnabled": false,      // Set to true by --debug flag
    "sessionId": "sess-20251212103045"  // Unique ID for log correlation (timestamp-based)
  }
}
```

**Invariants:**
- `debugEnabled` defaults to `false`
- `sessionId` is generated at command start using timestamp: `sess-$(date +%Y%m%d%H%M%S)` (e.g., `sess-20251212103045`)
- Both are reset at command completion

---

## 7. Interop Rules (Very Important)

All planning, execution, dashboard, next-task, and other features must:

1. Treat this document as the **contract** for:

   * `tasks.json`
   * `tasks-archive.json`
   * `state.json`
   * `memories.json`
   * Logging rules
2. Conform strictly to the schemas in `.taskmanager/schemas/`
3. Delegate all behavior to the plugin's skills and commands:

   * `taskmanager` skill — task management behavior
   * `taskmanager-memory` skill — memory management behavior
   * Plugin commands — command implementations

4. For memory operations:

   * Use the `taskmanager-memory` skill for all memory management
   * Run conflict detection at task start AND end
   * Always ask user for approval when modifying user-created memories
   * Track `appliedMemories` during execution and clear after task completion
   * Review task-scoped memories for promotion before marking task as done

This file is intentionally **behavior-light**.
Its purpose is to define *what the data must look like*, not how tasks are planned or executed.

---

## 8. Command Reference

### Initialization

```bash
taskmanager:init
```

Creates `.taskmanager/` directory with all required files and schemas.

### Planning

```bash
taskmanager:plan [source]
```

Parse PRD content from file, folder, or text input to generate tasks.

Examples:
- `taskmanager:plan docs/prd.md` - Plan from file
- `taskmanager:plan docs/specs/` - Plan from folder (aggregates all .md files)
- `taskmanager:plan "Build a counter app"` - Plan from text

### Dashboard & Status

```bash
taskmanager:dashboard
taskmanager:stats [--json]
```

View progress, completion metrics, and task overview.

### Task Execution

```bash
taskmanager:next-task
taskmanager:execute-task [task-id] [--memory "..."] [--task-memory "..."]
taskmanager:run-tasks [count] [--memory "..."] [--task-memory "..."]
```

Find and execute tasks with optional memory context.

### Efficient Operations

```bash
taskmanager:get-task <id> [key]
taskmanager:update-status <status> <id1> [id2...]
```

Token-efficient task queries and updates without loading full file.

### Memory Management

```bash
taskmanager:memory add "description"
taskmanager:memory list [--status active]
taskmanager:memory show <id>
taskmanager:memory update <id>
taskmanager:memory deprecate <id>
```

Manage project memories with conflict detection.

### Archival

```bash
taskmanager:migrate-archive
```

Archive completed tasks to reduce `tasks.json` size.
