---
description: Manage project memories - constraints, decisions, conventions with conflict detection and resolution
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# TaskManager Memory Skill

You manage the **project-wide memory** for this repository.

Your goal is to:

1. Keep `.taskmanager/memories.json` valid, structured, and consistent with its JSON Schema.
2. Make it easy for other agents/skills/commands to **discover relevant memories** based on the current work.
3. Capture new long-lived knowledge (constraints, decisions, bugfixes, conventions) whenever it appears.
4. Track how often memories are used so the most important ones surface naturally.

Always work relative to the project root.

---

## Files you own

- `.taskmanager/memories.json`

You MAY read the JSON Schema:

- `.taskmanager/schemas/memories.schema.json`

Do not delete or rename any `.taskmanager` files.

---

## Memory model

`.taskmanager/memories.json` is a JSON document with:

- `version` – semantic version of the memory file format.
- `project` – object with `id`, `name`, optional `description`.
- `memories` – array of memory entries.

Each **memory entry** has (see schema for exact types):

- `id` – stable ID, e.g. `"M-0001"`.
- `title` – short summary (<= 140 chars).
- `kind` – one of: `constraint`, `decision`, `bugfix`, `workaround`,
  `convention`, `architecture`, `process`, `integration`, `anti-pattern`, `other`.
- `whyImportant` – concise explanation of why this memory matters.
- `body` – detailed description / rationale / examples.
- `tags` – free-form tags, e.g. `["testing", "laravel", "pest"]`.
- `scope` – object describing where this applies:
  - `project` – project ID or name.
  - `files` – paths/globs, e.g. `["app/", "tests/Feature/"]`.
  - `tasks` – task IDs like `"1"`, `"2.3"`, `"4.1.2"`.
  - `commands` – names/paths of commands this is relevant to.
  - `agents` – names of agents this is relevant to.
  - `domains` – conceptual areas, e.g. `["testing", "architecture"]`.
- `source` – object describing who set this:
  - `type` – `"user" | "agent" | "command" | "hook" | "other"`.
  - `name` – human/agent/command identifier.
  - `via` – free-text, e.g. `"cli"`, `"tests/run-test-suite"`.
- `importance` – integer 1–5 (how critical).
- `confidence` – float 0–1 (how sure we are).
- `status` – `"active" | "deprecated" | "superseded" | "draft"`.
- `supersededBy` – optional ID of newer memory.
- `links` – optional links to docs/PRs/etc.
- `createdAt`, `updatedAt`, `lastUsedAt` – ISO timestamps.
- `useCount` – integer usage counter.
- `autoUpdatable` – boolean indicating if system can update without user approval (derived from `source.type != "user"`).
- `lastConflictAt` – ISO timestamp of the last detected conflict (or null).
- `conflictResolutions` – array of conflict resolution history entries.

You MUST keep the file consistent with the `MWGuerraTaskManagerMemories` JSON Schema.

---

## Responsibilities

### 1. Load & validate

When you start working:

1. Use `Read` to load `.taskmanager/memories.json` if it exists.
2. If it does not exist:
   - Initialize a minimal, valid structure:
     - `version`
     - `project` (with plausible `id`/`name` from context)
     - empty `memories` array.
3. Use the schema at `.taskmanager/schemas/memories.schema.json` as the **contract**:
   - Ensure required fields exist.
   - Do not introduce extra top-level properties.
   - Fix minor inconsistencies when safe (e.g., missing `useCount` → set to 0).

If you cannot make the JSON valid without guessing, prefer to **explain the inconsistency** in comments/logs rather than silently discarding data.

### 2. Query for relevant memories

Given a natural-language description of the current work (files, task IDs, domains):

1. Parse the description into:
   - Candidate `domains` (e.g. testing, performance, security, architecture).
   - Candidate `files` / directories.
   - Task IDs, if present.
2. Filter `memories` to those where:
   - `status = "active"`, and
   - At least one of the following intersects:
     - `scope.domains` with inferred domains
     - `scope.files` with affected files/dirs
     - `scope.tasks` with relevant task IDs
     - `tags` with inferred keywords.
3. Prefer:
   - Higher `importance`.
   - Higher `useCount`.
   - More recent `lastUsedAt`.
4. Return a compact summary (bullet list) with:
   - `id`, `title`, `kind`, `whyImportant`.
   - Any key constraints or decisions that MUST be respected.

You should **never** dump the entire memory file into context unless explicitly asked; always select the smallest relevant subset.

### 3. Create a new memory

When a user or another skill makes a decision that should persist for future work:

1. Check whether a similar memory already exists (matching `kind` + overlapping `tags`/`scope`).
2. If it is truly new:
   - Generate the next ID (`M-0001`, `M-0002`, …) without reusing IDs.
   - Create a well-structured entry with:
     - Clear `title`, `kind`, `whyImportant`, `body`.
     - Scoped `tags` and `scope`.
     - Accurate `source` (`type`, `name`, `via` if known).
     - Reasonable `importance` and `confidence` (default importance 3, confidence 0.8+).
     - `status = "active"` (or `"draft"` if still tentative).
     - `createdAt` and `updatedAt` set to current time.
     - `lastUsedAt = null`, `useCount = 0`.
3. Append to the `memories` array and write the file back.

When in doubt whether something deserves a memory, ask: **“Will this decision/convention matter for future tasks?”** If yes, create a memory.

### 4. Update or supersede an existing memory

When an existing memory is refined or corrected:

1. If it’s a small correction:
   - Update the existing entry (`body`, `tags`, `scope`, etc.).
   - Bump `updatedAt`.
2. If it’s a substantial change or reversal:
   - Create a new memory entry with the updated decision.
   - Mark the old one:
     - `status = "superseded"` or `"deprecated"`.
     - `supersededBy = "<new-id>"`.
   - Keep both entries in the file for history.

Never silently rewrite history in a way that hides past decisions.

### 5. Track usage

Whenever a memory directly influences planning or execution:

1. Find the corresponding entry by `id`.
2. Increment `useCount` (e.g., `useCount += 1`).
3. Set `lastUsedAt` to current ISO timestamp.
4. Write the updated file back.

This allows future tools to treat highly-used, high-importance memories as more trustworthy.

---

## How other skills/commands should use this

When planning or executing non-trivial work (new features, refactors, risky changes):

1. Summarize the intent in a short description:
   - Files/directories involved.
   - Task IDs (if any).
   - Domains (e.g. testing, performance, architecture).
2. Use this skill to query for relevant memories.
3. Apply those memories as **constraints and prior decisions** when:
   - Creating task trees.
   - Designing architecture.
   - Writing or refactoring code.
   - Setting up tests, infra, or workflows.
4. If a new decision emerges that future work should follow:
   - Call this skill again to create or update a memory entry.

This way, `.taskmanager/memories.json` becomes the single, durable "project brain" that all agents/commands/skills can rely on.

---

## 6. Task-Scoped Memory Management

Task-scoped memories are temporary memories that live only for the duration of a single task. They are stored in `.taskmanager/state.json` under the `taskMemory` array.

### 6.1 Adding task-scoped memory

When a user provides `--task-memory "description"` or `-tm "description"` to a command:

1. Load `.taskmanager/state.json`.
2. Create a task memory entry:
   ```json
   {
     "content": "<the description>",
     "addedAt": "<current ISO timestamp>",
     "taskId": "<current task ID>",
     "source": "user"
   }
   ```
3. Append to `state.json.taskMemory[]`.
4. Write `state.json` back.

System-generated task memories use `"source": "system"`.

### 6.2 Retrieving task-scoped memory

Before executing a task:

1. Load `state.json.taskMemory[]`.
2. Filter for entries where `taskId` matches the current task or is `"*"` (applies to all tasks).
3. Include these memories alongside global memories when applying constraints.

### 6.3 Promoting task memory to global

At task completion (before marking "done"):

1. Check if any task memories exist for this task.
2. If task memories exist, use `AskUserQuestion` to ask:
   > "The following task memories were used during this task. Should any be promoted to global (persistent) memory?"

   Options for each memory:
   - "Promote to global memory"
   - "Discard (task-specific only)"

3. For promoted memories:
   - Create a new global memory entry in `memories.json` with appropriate `kind`, `tags`, `scope`.
   - Set `source.type = "user"` if originally from user, or `"agent"` if from system.
4. Clear the task memories for this task from `state.json.taskMemory[]`.

---

## 7. Conflict Detection

Conflict detection runs automatically at the **start** and **end** of every task execution.

### 7.1 When to run conflict detection

- **Pre-execution**: After loading relevant memories, before starting work.
- **Post-execution**: After task work is complete, before marking status as "done".

### 7.2 Conflict detection algorithm

For each **active** memory that was loaded for this task:

1. **File/Pattern Obsolescence Check**:
   - If `scope.files` is defined:
     - Use `Glob` to check if referenced files/directories still exist.
     - If any file path no longer exists → flag as obsolete conflict.

2. **Implementation Divergence Check**:
   - Analyze `memory.body` for specific implementation requirements.
   - Check if current codebase contradicts the memory:
     - Example: Memory says "use TypeScript strict mode" but `tsconfig.json` has `strict: false`.
     - Example: Memory says "always use Pest for tests" but new tests use PHPUnit.
   - If contradiction detected → flag as divergence conflict.

3. **Test Failure Check**:
   - If `scope.domains` includes testing-related domains:
     - Check if recent test runs show failures in related areas.
     - If tests are failing in memory-scoped areas → flag as test failure conflict.

### 7.3 Conflict severity

Classify conflicts by severity:

- **Critical**: Memory with `importance >= 4` has a divergence conflict.
- **Warning**: Memory with `importance < 4` has any conflict.
- **Info**: File obsolescence where the file is not critical.

---

## 8. Conflict Resolution Workflow

When a conflict is detected, the resolution process depends on the memory's ownership.

### 8.1 User-created memories (`source.type == "user"`)

NEVER auto-update. ALWAYS ask the user.

Use `AskUserQuestion` with options:

1. **"Keep memory as-is"**
   - Acknowledge the conflict but take no action.
   - Log in `conflictResolutions[]` with `resolution: "kept"`.

2. **"Update memory to reflect current state"**
   - Update the memory's `body`, `tags`, or `scope` to match current implementation.
   - Bump `updatedAt`.
   - Log in `conflictResolutions[]` with `resolution: "modified"`.

3. **"Deprecate this memory"**
   - Set `status = "deprecated"`.
   - Bump `updatedAt`.
   - Log in `conflictResolutions[]` with `resolution: "deprecated"`.

4. **"Supersede with new memory"**
   - Create a new memory with updated decision.
   - Set old memory `status = "superseded"` and `supersededBy = "<new-id>"`.
   - Log in `conflictResolutions[]` with `resolution: "superseded"`.

### 8.2 System-created memories (`source.type != "user"`)

For system-created memories (`source.type` is `"agent"`, `"command"`, `"hook"`, or `"other"`):

- **Refinements** (small updates that don't reverse the decision):
  - Auto-update allowed. Update `body`, bump `updatedAt`.
  - Log in `conflictResolutions[]` with `resolution: "modified"`.

- **Reversals** (substantial change or contradiction):
  - Ask the user using `AskUserQuestion` with same options as 8.1.

### 8.3 Recording conflict resolutions

Every conflict resolution MUST be recorded in the memory's `conflictResolutions[]` array:

```json
{
  "timestamp": "<ISO timestamp>",
  "resolution": "kept" | "modified" | "deprecated" | "superseded",
  "reason": "<brief explanation>",
  "taskId": "<task ID where conflict was detected>"
}
```

Also update `lastConflictAt` to the current timestamp.

### 8.4 Conflict resolution in batch/auto-run mode

During autonomous task execution (`/run-tasks`):

- If a **critical** conflict is detected:
  - Pause execution.
  - Present conflict to user.
  - Wait for resolution before continuing.

- If a **warning** or **info** conflict is detected:
  - Log the conflict.
  - Continue execution.
  - Present summary of conflicts at the end of the batch.

---

## 9. Memory Ownership Rules

### 9.1 Determining `autoUpdatable`

When creating a memory, set `autoUpdatable` based on `source.type`:

```
autoUpdatable = (source.type != "user")
```

- `source.type == "user"` → `autoUpdatable = false`
- `source.type == "agent" | "command" | "hook" | "other"` → `autoUpdatable = true`

### 9.2 Update rules by ownership

| Source Type | Small Update | Substantial Change |
|-------------|--------------|-------------------|
| `user`      | Ask user     | Ask user          |
| `agent`     | Auto-update  | Ask user          |
| `command`   | Auto-update  | Ask user          |
| `hook`      | Auto-update  | Ask user          |
| `other`     | Auto-update  | Ask user          |

### 9.3 Never delete memories

Memories are **never deleted**. They are either:
- Kept as `"active"`
- Marked as `"deprecated"` (no longer relevant)
- Marked as `"superseded"` with a pointer to the new memory

This preserves decision history and audit trail.

---

## 10. Logging Behavior

This skill MUST write to the log files under `.taskmanager/logs/` for all memory operations.

### 10.1 What to Log

**errors.log** — ALWAYS append when:
- Memory file parse failures
- Schema validation errors
- Conflict detection finds issues
- Invalid memory IDs referenced

Example:
```text
2025-12-11T10:00:00Z [ERROR] [sess-abc123] Failed to parse memories.json: invalid JSON
2025-12-11T10:00:01Z [ERROR] [sess-abc123] Conflict: M-0001 references deleted file app/OldAuth.php
2025-12-11T10:00:02Z [ERROR] [sess-abc123] Memory M-9999 not found when attempting update
```

**decisions.log** — ALWAYS append when:
- Memory created
- Memory updated
- Memory deprecated or superseded
- Memory applied to task
- Conflict resolution completed
- Task memory promoted to global

Example:
```text
2025-12-11T10:00:00Z [DECISION] [sess-abc123] Created memory M-0005: "Always validate API inputs"
2025-12-11T10:00:01Z [DECISION] [sess-abc123] Applied memories to task 1.2: M-0001, M-0003, M-0005
2025-12-11T10:00:02Z [DECISION] [sess-abc123] Conflict resolved for M-0001: kept (user decision)
2025-12-11T10:05:00Z [DECISION] [sess-abc123] Deprecated M-0002: "No longer using old auth pattern"
2025-12-11T10:05:01Z [DECISION] [sess-abc123] Promoted task memory to global: M-0006
```

**debug.log** — ONLY append when `state.json.logging.debugEnabled == true`:
- Memory matching algorithm steps
- Conflict detection intermediate results
- Full memory state dumps
- File existence checks during conflict detection

Example:
```text
2025-12-11T10:00:00Z [DEBUG] [sess-abc123] Querying memories for task 1.2.3 (domain: auth)
2025-12-11T10:00:01Z [DEBUG] [sess-abc123] Checking 8 active memories for relevance
2025-12-11T10:00:02Z [DEBUG] [sess-abc123] M-0001: matched by scope.domains (contains "auth")
2025-12-11T10:00:03Z [DEBUG] [sess-abc123] M-0002: skipped (importance 2 < threshold 3)
2025-12-11T10:00:04Z [DEBUG] [sess-abc123] Conflict detection: checking file existence for M-0003.scope.files
2025-12-11T10:00:05Z [DEBUG] [sess-abc123] File check: app/Services/Auth.php EXISTS
```

### 10.2 Logging During Conflict Detection

When running conflict detection, log:

1. **Start of detection** (DEBUG):
   ```text
   [DEBUG] Starting conflict detection for N active memories
   ```

2. **Per-memory checks** (DEBUG):
   ```text
   [DEBUG] Checking M-XXXX for conflicts...
   [DEBUG] - File check: <path> EXISTS/MISSING
   [DEBUG] - Implementation check: <result>
   ```

3. **Conflicts found** (ERROR):
   ```text
   [ERROR] Conflict: M-XXXX - <conflict description>
   ```

4. **Resolution outcome** (DECISION):
   ```text
   [DECISION] Conflict resolved for M-XXXX: <resolution> (<reason>)
   ```

### 10.3 Debug Mode Integration

This skill reads `state.json.logging.debugEnabled` to determine whether to write debug logs.

- If `debugEnabled == true`: Write verbose DEBUG entries to debug.log
- If `debugEnabled == false`: Skip DEBUG entries, only write ERROR and DECISION

The calling command is responsible for setting `debugEnabled` based on `--debug` flag.
