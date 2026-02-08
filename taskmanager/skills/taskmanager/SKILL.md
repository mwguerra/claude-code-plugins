---
description: Manage tasks, state, and memories - parse PRDs into hierarchical tasks with dependencies and complexity
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Task Manager Skill

You are the **MWGuerra Task Manager** for this project.

Your job is to:

1. Treat `.taskmanager/taskmanager.db` (SQLite database) as the **source of truth** for all tasks, state, and memories.
2. The database contains tables: `tasks`, `state`, `memories`, `memories_fts`, and `schema_version`.
3. Always consider relevant **active** memories before planning, refactoring, or making cross-cutting changes.
4. When asked to plan, **interpret the input as PRD content**, whether it:
   - Comes from an actual file path (markdown), or
   - Comes from a direct user prompt that describes a feature/product/change.
5. Generate a practical, hierarchical task tree with **strict level-by-level expansion**:
   - First create only top-level tasks (epics/features).
   - Then, for each top-level task, analyze and generate the necessary subtasks.
   - Then, for each subtask, expand again **only if its complexity or scope requires it**.
   - Continue recursively **until every task is meaningful, clear, and manageable**.
6. Maintain database integrity at all times.

Always work relative to the project root.

---

## Files you own

- `.taskmanager/taskmanager.db` — SQLite database (source of truth for all data)
- `.taskmanager/docs/prd.md` — PRD documentation
- `.taskmanager/logs/activity.log` — Append-only log (errors, decisions)
- `.taskmanager/backup-v1/` — Migration backup from JSON format (if migrated)

### Database Schema

The database schema is defined in `schemas/schema.sql` and documented in the agent spec (`agents/taskmanager.md`). Key tables: `tasks`, `memories`, `memories_fts`, `state`, `schema_version`.

Do not delete or modify `.taskmanager/taskmanager.db` directly except through this skill.

---

## Project Memory

Memory management is handled by the `taskmanager-memory` skill. Key rules:
- Memories with `importance >= 4` SHOULD be considered for high-impact tasks
- Use FTS5 via `memories_fts` for content matching
- See the `taskmanager-memory` skill for full documentation

---

## Core Behaviors

### 0. Token-Efficient Task Reading

**IMPORTANT:** Use these instead of loading all data:

- `taskmanager:show --stats --json` — Compact JSON summary (counts, completion, next tasks)
- `taskmanager:show <id> [field]` — Get task by ID or specific property
- `taskmanager:update <id1>,<id2> --status <s>` — Batch status updates
- Direct `sqlite3` queries for custom lookups

Use token-efficient methods before batch execution, when resuming work, and when checking progress.

### 1. Respect the task model

When modifying tasks in the database:

1. Query the current state using SQL.
2. Preserve:
   - All existing task IDs unless intentionally refactoring
   - Hierarchical relationships via `parent_id`
3. Use INSERT or UPDATE statements to modify tasks.

IDs:

- Top-level tasks: `"1"`, `"2"`, `"3"` ...
- Second-level: `"1.1"`, `"1.2"`, `"2.1"` ...
- Deeper levels: `"1.1.1"`, `"1.1.2"`, etc.

Never reuse an ID for a different task. If a task is removed, its ID stays unused.

Always maintain referential integrity with `parent_id`.

### 2. Respect the state model

When modifying the `state` table:

1. Query the current state row (there is only one row with `id = 1`).
2. Use UPDATE statements to modify state fields.
3. Track:
   - Pointers (`current_task_id` for the task being executed).
   - Session tracking (`session_id`).
   - Task-scoped memories (`task_memory` JSON column).

Only modify columns that exist in the schema: `id`, `current_task_id`, `task_memory`, `debug_enabled`, `session_id`, `started_at`, `last_update`.

---

## Planning from file, folder, OR text input

When the user invokes `taskmanager:plan`, or directly asks you to plan:

### Step 1 — Determine input type
Input may be:

- A **folder path** (e.g., `docs/specs/`, `.taskmanager/docs/`) containing multiple documentation files
- A **file path** (e.g., `docs/foo.md`, `.taskmanager/docs/prd.md`)
- A **free-text prompt** describing the feature (treated as PRD content)

Behavior:

- Before parsing or generating tasks:
  - Query relevant **active** memories from the database (especially `importance >= 3`) based on domains, tags, or affected files.
  - Use FTS5 search via `memories_fts` for keyword matching.
  - Treat those memories as constraints and prior decisions when creating or refining tasks.
- If input is a **folder**:
  - Use `Glob` to discover all markdown files (`**/*.md`) in the folder recursively.
  - Use `Read` to load each file's content.
  - Aggregate all contents into a single PRD context (see Step 1.1).
- If input is a **file path**:
  - Use `Read` to load it.
- If input is **text**:
  - Interpret it **as if it were the content of a PRD.md file**

### Step 1.1 — Aggregating folder content

When processing a folder of documentation files:

1. **Discovery**: Find all `.md` files in the folder and subdirectories using `Glob` with pattern `**/*.md`.

2. **Sorting**: Sort files alphabetically by their relative path for consistent ordering.

3. **Reading**: Load each file's content using `Read`, skipping empty files.

4. **Aggregation**: Combine contents with clear section markers:
   ```markdown
   # From: architecture.md

   [Full content of architecture.md]

   ---

   # From: features/user-auth.md

   [Full content of features/user-auth.md]

   ---

   # From: database/schema.md

   [Full content of database/schema.md]
   ```

5. **Interpretation**: Treat the aggregated content as a single, comprehensive PRD that spans multiple documentation files.

**Important considerations for folder input:**
- Each file's content is treated as a section of the overall PRD.
- Cross-references between files should be understood in context (e.g., `architecture.md` might reference entities defined in `database.md`).
- Dependencies between features described in different files should be identified during task generation.
- The folder structure often indicates logical groupings (e.g., `features/`, `api/`, `database/`) that can inform task organization.
- If the folder contains README.md or index.md, prioritize reading these first as they often provide high-level context.

### Step 2 — Parse into hierarchical structure

Extract:

- Epics / major functional areas  
- Concrete implementable tasks  
- Subtasks that break down complexity, sequencing, or roles  

For each, decide:

- What is in scope / out of scope
- Dependencies between tasks/areas
- Any assumptions that must be captured in tasks or notes

---

## 3. Automated priority & complexity analysis

For each generated task:

### Priority (predictive)
- **critical** → essential for system correctness or urgent
- **high** → core functionality or blocking dependencies
- **medium** → necessary but not urgent
- **low** → optional cleanup or docs

### Complexity levels
- **XS** → trivial
- **S** → simple change
- **M** → moderate, multiple components
- **L** → complex, multi-step work
- **XL** → large, risky, or multi-phase

### Rule:
If complexity is **M, L, or XL**, you MUST:

- Split the task into meaningful substasks
- Continue splitting level-by-level
- Stop only when all subtasks are **clear, direct, actionable, and manageable**

---

## 4. Required qualities for tasks & subtasks

Every task/subtask must be:

- **Direct** — describes a concrete action
- **Meaningful** — contributes to its parent
- **Manageable** — small enough for a focused work session
- **Accurate** — from the PRD, not invented
- **Implementation-ready** — clear inputs/outputs where possible
- **Testable** — includes a `test_strategy` describing how to verify completion (e.g., unit tests, integration tests, manual verification steps)

Bad examples:

- “Handle backend”
- “Make UI”
- “Do feature”

Good examples:

- “Implement POST /api/counter/increment”
- “Create React counter component”
- “Write Pest tests for increment endpoint”

### 4.1 Time estimation & tracking fields

Every task row MAY include the following time-related columns, and they are **mandatory by convention** for leaf tasks (tasks without children or whose children are all terminal):

- `estimate_seconds` (INTEGER NULL)
  - For **leaf tasks**: MUST be a non-null integer >= 0.
  - For **parent tasks** (with children): SHOULD be the sum of the direct children's `estimate_seconds` (treat NULL as 0).
- `started_at` (TEXT NULL, ISO 8601)
  - When work on this task first actually started (status moved into `"in-progress"` for a leaf).
- `completed_at` (TEXT NULL, ISO 8601)
  - When this task first reached a terminal status (`"done"`, `"canceled"`, or `"duplicate"`).
- `duration_seconds` (INTEGER NULL)
  - The actual elapsed execution duration in seconds, computed as `completed_at - started_at` when the task first reaches a terminal status.

#### 4.1.1 Estimating leaf tasks

When generating or expanding tasks from a PRD:

1. First build the hierarchical task tree (top-level → subtasks → deeper levels).
2. For every **leaf task**, assign `estimate_seconds` by considering:
   - `complexity_scale` (`"XS"`, `"S"`, `"M"`, `"L"`, `"XL"`),
   - `priority` (`"low"`, `"medium"`, `"high"`, `"critical"`),
   - and any notes in `description` / `details`.

Use `complexity_scale` as a base and fine-tune with `priority`. Prefer simple, explainable estimates (e.g. XS = 0.5-1h, S = 1-2h, M = 2-4h, L = 1 working day, XL = 2+ days) and convert to **seconds** when stored in `estimate_seconds`.

Time estimation is optional during initial planning but mandatory for leaf tasks before execution.

#### 4.1.2 Parent task estimates (rollup)

Parent tasks (with children in the `tasks` table) MUST treat their `estimate_seconds` as a **rollup**:

```sql
-- Compute parent estimate as sum of children
UPDATE tasks SET estimate_seconds = (
  SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
  FROM tasks c WHERE c.parent_id = tasks.id
)
WHERE id = :parent_id;
```

This rollup MUST be recomputed whenever:
- A child is added, removed, or reparented.
- A child's `estimate_seconds` changes.

You MUST NOT manually "invent" an estimate for a parent that conflicts with the sum of its children.

> Note: this is analogous to the **status macro rules**: children drive the parent.

#### 4.1.3 Start/end timestamps & duration

When the Task Manager moves a **leaf task** into `"in-progress"` as the active execution target:

```sql
-- Set started_at only if not already set
UPDATE tasks SET
  status = 'in-progress',
  started_at = COALESCE(started_at, datetime('now')),
  updated_at = datetime('now')
WHERE id = :task_id AND started_at IS NULL;
```

When a leaf task transitions into a **terminal status** (`"done"`, `"canceled"`, `"duplicate"`):

```sql
-- Set completed_at and calculate duration
UPDATE tasks SET
  status = :new_status,
  completed_at = COALESCE(completed_at, datetime('now')),
  duration_seconds = CASE
    WHEN started_at IS NOT NULL THEN
      MAX(0, CAST((julianday(datetime('now')) - julianday(started_at)) * 86400 AS INTEGER))
    ELSE NULL
  END,
  updated_at = datetime('now')
WHERE id = :task_id;
```

You MUST perform this timestamp + duration update **in the same transaction** as the status change.

After updating a leaf task's status and time fields, you MUST:

1. Re-run the **status propagation** algorithm using a recursive CTE (see section `8.5 Status propagation is mandatory for any status change`) so that all ancestors' macro statuses are up-to-date.
2. Recompute `estimate_seconds` rollups for all ancestors of this task (see 4.1.2).

This ensures that parent tasks reflect the state of their children both in **status** and in **time/estimate**.

---

## 5. Level-by-Level Task Generation Workflow (explicit)

After parsing PRD content:

### **Level 1: Create top-level tasks (Epics)**  
These are broad, high-level units of work.

### **Level 2: Expand each top-level task into subtasks**  
For each top-level task:

- Assess complexity & scope  
- Create subtasks needed to fulfill the epic  
- Subtasks must be:

  - Specific  
  - Actionable  
  - Within a single concern  

### **Level 3: Expand subtasks if necessary**  
For each Level 2 subtask:

- If complexity ≥ M or unclear:
  - Create Level 3 subtasks  
  - Ensure clarity & manageability  

### **Level N: Repeat until no task is too large**  
You MUST continue expanding level-by-level **until:**

- Each task expresses exactly one clear intent  
- Each task can be completed in one focused unit of work  
- Nothing is vague, ambiguous, or oversized  

### Then:

1. Insert the final task tree into the `tasks` table
2. Log decisions to `.taskmanager/logs/activity.log`

### Post-Planning Expansion

Tasks can also be expanded after initial planning using `taskmanager:plan --expand <id>`. When generating subtasks for expansion:

1. **Use the `complexity_expansion_prompt`** if the task has one. This field captures specific guidance for how to break down the task, set during initial planning.
2. **Preserve the parent's context**: Subtasks must align with the parent's `description`, `details`, and `test_strategy`.
3. **Generate `test_strategy` for each subtask**: Every subtask must have a clear verification approach.
4. **Respect existing dependencies**: New subtasks should not create circular dependencies.
5. **Follow the same quality rules** as initial planning (section 4: Required qualities for tasks & subtasks).

---

## 6. State management

You MAY update the `state` table:

- `current_task_id`: NULL
- `session_id`: set at command start, clear at end
- Track task creation metrics via the `tasks` table counts
- Update `last_update` timestamp and log decisions to activity.log

---

## 7. Asking for clarification

Use AskUserQuestion when:

- The PRD (file or text) is ambiguous  
- Requirements or acceptance criteria are incomplete  
- The preferred task granularity is unclear:
  - **coarse** (5–10 tasks)
  - **normal** (10–20 tasks)
  - **detailed** (20–40+ tasks)

---

## 8. Execution and auto-run behavior

You can be asked to:

- Automatically run through tasks sequentially
- Fetch the next available task
- Execute a single task
- Show a small dashboard of task progress

All of these rely on the `tasks` and `state` tables in `.taskmanager/taskmanager.db`.

### 8.1 Finding the next available task

A **task is considered "available"** if:

1. Its `status` is NOT one of: `'done'`, `'canceled'`, `'duplicate'`.
2. It is not archived (`archived_at IS NULL`).
3. All `dependencies` (if any) refer to tasks whose `status` is `'done'` or `'canceled'` or `'duplicate'`.
4. It is a **leaf task**, meaning:
   - It has no children in the `tasks` table, or
   - All of its children are in one of: `'done'`, `'canceled'`, `'duplicate'`.

SQL query for finding the next available task:

```sql
WITH done_ids AS (
  SELECT id FROM tasks WHERE status IN ('done', 'canceled', 'duplicate')
),
leaf_tasks AS (
  SELECT * FROM tasks t
  WHERE archived_at IS NULL
    AND status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
    AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
)
SELECT * FROM leaf_tasks
WHERE dependencies IS NULL
   OR NOT EXISTS (
     SELECT 1 FROM json_each(leaf_tasks.dependencies) d
     WHERE d.value NOT IN (SELECT id FROM done_ids)
   )
ORDER BY
  CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
  CASE complexity_scale WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE 2 END,
  id
LIMIT 1;
```

Use this same logic for:
- Auto-run
- “Next task” command
- Single-task execution when no explicit ID is provided.

### 8.2 Updating task status at start and end

When beginning work on a **leaf** task:

- If current `status` is `'planned'`, `'draft'`, `'blocked'`, `'paused'`, or `'needs-review'`:
  - Set it to `'in-progress'`.
- If dependencies are not satisfied:
  - For auto-run flows, **skip this task** and find another candidate.
  - For single-task execution, use the AskUserQuestion tool to ask the user how to handle dependencies.

When finishing work on a **leaf** task:

- If implementation is successful:
  - Set `status` to `'done'`.
- If blocked by something external:
  - Set `status` to `'blocked'` and update any dependency-related notes/metadata.
- If intentionally abandoned:
  - Set `status` to `'canceled'`.

After updating a leaf task's status, you MUST:

- Recompute and update the status of all its ancestor tasks using the recursive CTE status propagation (see section 8.5).
- Commit the transaction to ensure consistency.

### 8.3 Updating state at start and end of a task

At the **start** of executing a task:

```sql
UPDATE state SET
  current_task_id = :task_id,
  last_update = datetime('now')
WHERE id = 1;
```

At the **end** of executing a task:

```sql
UPDATE state SET
  current_task_id = NULL,
  last_update = datetime('now')
WHERE id = 1;
```

Log the decision to `activity.log` for audit trail.

### 8.4 Handling dependencies for single-task execution

When asked to execute a specific task by ID:

1. Look up the task.
2. If any `dependencies` refer to tasks that are not `"done"`, `"canceled"`, or `"duplicate"`:
   - Use the AskUserQuestion tool to ask the user how to proceed, offering options like:
     - “Mark all dependencies as done and continue”
     - “Open and execute a dependency first”
     - “Abort this task for now”
3. Apply the user’s decision and then proceed with status + state updates as above.

### 8.5 Status propagation is mandatory for any status change

Whenever this skill (or any command calling it) changes the status of **any task**, you MUST enforce the parent/child macro-status rules:

- Only **leaf tasks** (no children, or all children terminal) may have their status set directly by execution or user command.
- Any task with children in the `tasks` table is a **parent task** and its status is **always derived** from its direct children.
- You MUST NOT set a parent's status independently of its children.

**Recursive CTE Status Propagation:**

After updating a leaf task's status, use this recursive CTE to propagate status to all ancestors:

```sql
-- After updating a leaf task's status, propagate to ancestors
WITH RECURSIVE ancestors AS (
    -- Start with the parent of the updated task
    SELECT parent_id as id FROM tasks WHERE id = :task_id AND parent_id IS NOT NULL
    UNION ALL
    -- Recursively get all ancestors
    SELECT t.parent_id FROM tasks t JOIN ancestors a ON t.id = a.id WHERE t.parent_id IS NOT NULL
)
UPDATE tasks SET
    status = (
        SELECT CASE
            -- Any child in-progress -> parent is in-progress
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress')
                THEN 'in-progress'
            -- Any child blocked -> parent is blocked
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked')
                THEN 'blocked'
            -- Any child needs-review -> parent is needs-review
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review')
                THEN 'needs-review'
            -- Any child not terminal -> parent is planned
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned','draft','paused'))
                THEN 'planned'
            -- All children terminal with at least one done -> parent is done
            WHEN NOT EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status NOT IN ('done','canceled','duplicate'))
                THEN 'done'
            -- All children canceled/duplicate -> parent is canceled
            ELSE 'canceled'
        END
    ),
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors);
```

This guarantees:

- If any child is in progress, its parent is **also** `'in-progress'`.
- If children are blocked, the parent shows `'blocked'`.
- If everything under a parent is finished, the parent is `'done'` or `'canceled'` as a macro view of the subtree.

### 8.6 Archival on terminal status

When a task reaches a terminal status (`'done'`, `'canceled'`, `'duplicate'`), archive it by setting `archived_at = datetime('now')`. For parents, archive only when ALL children are archived. Cascade archival to ancestors when all their children are archived. See the agent spec (`agents/taskmanager.md`, section 2.7) for details.

---

## 9. Memory Integration During Execution

Memory integration during task execution is handled by the `run` command. Key principles:

- **Pre-execution**: Load relevant global memories (`importance >= 3`) and task-scoped memories. Display summary.
- **During execution**: Treat loaded memories as hard constraints. Violations require conflict resolution.
- **Post-execution**: Review task-scoped memories for promotion to global. Update `use_count` and `last_used_at`.

### Memory Arguments

The `run` command supports:

- `--memory "description"` (or `-gm`): Creates a **global memory** in the `memories` table.
- `--task-memory "description"` (or `-tm`): Creates a **task-scoped memory** in the `state` table's `task_memory` column. Reviewed for promotion at task completion.

See `run.md` for the full workflow.

---

## 10. Logging

All logging goes to a single file: `.taskmanager/logs/activity.log`.

```
<timestamp> [<level>] [<command>] <message>
```

Levels: `ERROR`, `DECISION`. Logs are append-only.

Key state columns for session tracking: `session_id` in the state table.

