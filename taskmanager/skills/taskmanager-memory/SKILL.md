---
description: Manage project memories - constraints, decisions, conventions with conflict detection and resolution
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# TaskManager Memory Skill

You manage the **project-wide memory** for this repository using SQLite.

Your goal is to:

1. Keep the `memories` table in `.taskmanager/taskmanager.db` valid and consistent.
2. Make it easy for other agents/skills/commands to **discover relevant memories** based on the current work.
3. Capture new long-lived knowledge (constraints, decisions, bugfixes, conventions) whenever it appears.
4. Track how often memories are used so the most important ones surface naturally.

Always work relative to the project root.

---

## Database Location

- **Database**: `.taskmanager/taskmanager.db`
- **Primary table**: `memories`
- **Full-text search**: `memories_fts` (FTS5 virtual table)
- **Task memory**: `state.task_memory` (JSON column in `state` table)

Use `sqlite3` via the Bash tool for all database operations.

---

## Memory Schema

The `memories` table has these columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT PRIMARY KEY | Stable ID, e.g. `"M-0001"` |
| `title` | TEXT NOT NULL | Short summary (<= 140 chars) |
| `kind` | TEXT NOT NULL | One of: `constraint`, `decision`, `bugfix`, `workaround`, `convention`, `architecture`, `process`, `integration`, `anti-pattern`, `other` |
| `why_important` | TEXT NOT NULL | Concise explanation of why this memory matters |
| `body` | TEXT NOT NULL | Detailed description / rationale / examples |
| `source_type` | TEXT NOT NULL | One of: `user`, `agent`, `command`, `hook`, `other` |
| `source_name` | TEXT | Human/agent/command identifier |
| `source_via` | TEXT | Free-text, e.g. `"cli"`, `"tests/run-test-suite"` |
| `auto_updatable` | INTEGER | 0 for user-created (never auto-update), 1 for system-created |
| `importance` | INTEGER | 1-5 (how critical), default 3 |
| `confidence` | REAL | 0-1 (how sure we are), default 0.8 |
| `status` | TEXT | One of: `active`, `deprecated`, `superseded`, `draft` |
| `superseded_by` | TEXT | ID of newer memory (if superseded) |
| `scope` | TEXT (JSON) | Object with: `project`, `files`, `tasks`, `commands`, `agents`, `domains`. The `tasks` field links memories to specific task IDs for auto-loading during execution. |
| `tags` | TEXT (JSON) | Array of free-form tags, e.g. `["testing", "laravel"]` |
| `links` | TEXT (JSON) | Array of links to docs/PRs/etc |
| `use_count` | INTEGER | Usage counter, default 0 |
| `last_used_at` | TEXT | ISO timestamp of last use |
| `last_conflict_at` | TEXT | ISO timestamp of last detected conflict |
| `conflict_resolutions` | TEXT (JSON) | Array of conflict resolution history entries |
| `created_at` | TEXT | ISO timestamp |
| `updated_at` | TEXT | ISO timestamp |

---

## Note on Deferrals

Deferrals (tracked in the `deferrals` table) are **separate from memories**. Deferrals track work deferred from one task to another with source-target linkage and lifecycle management. They are managed by the `run` and `update` commands, not by this memory skill. Do not create memories to track deferred work; use the deferrals system instead.

---

## Responsibilities

### 1. Initialize & Validate

When you start working:

1. Check if `.taskmanager/taskmanager.db` exists.
2. If not, the database needs initialization (use the taskmanager init process).
3. Verify the `memories` table exists:
   ```sql
   SELECT name FROM sqlite_master WHERE type='table' AND name='memories';
   ```

### 2. Query for Relevant Memories

Given a natural-language description of the current work (files, task IDs, domains):

1. Parse the description into:
   - Candidate `domains` (e.g. testing, performance, security, architecture).
   - Candidate `files` / directories.
   - Task IDs, if present.

2. Use SQL to find matching memories:

**Full-text search (for keyword matching):**
```sql
SELECT m.id, m.title, m.kind, m.why_important, m.importance, m.use_count
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE m.status = 'active'
  AND memories_fts MATCH '<search_terms>'
ORDER BY rank, m.importance DESC, m.use_count DESC
LIMIT 10;
```

**Scope-based search (for file matching):**
```sql
SELECT id, title, kind, why_important, importance, use_count
FROM memories
WHERE status = 'active'
  AND (
    scope = '{}'
    OR json_extract(scope, '$.files') IS NULL
    OR EXISTS (
      SELECT 1 FROM json_each(json_extract(scope, '$.files')) f
      WHERE '<current_file>' LIKE f.value
    )
  )
ORDER BY importance DESC, use_count DESC
LIMIT 10;
```

**Domain-based search:**
```sql
SELECT id, title, kind, why_important, importance, use_count
FROM memories
WHERE status = 'active'
  AND EXISTS (
    SELECT 1 FROM json_each(json_extract(scope, '$.domains')) d
    WHERE d.value IN ('<domain1>', '<domain2>')
  )
ORDER BY importance DESC, use_count DESC;
```

**Task-based search:**
```sql
SELECT id, title, kind, why_important, importance, use_count
FROM memories
WHERE status = 'active'
  AND EXISTS (
    SELECT 1 FROM json_each(json_extract(scope, '$.tasks')) t
    WHERE t.value = '<task_id>'
  )
ORDER BY importance DESC;
```

3. Prefer:
   - Higher `importance`.
   - Higher `use_count`.
   - More recent `last_used_at`.

4. Return a compact summary (bullet list) with:
   - `id`, `title`, `kind`, `why_important`.
   - Any key constraints or decisions that MUST be respected.

You should **never** dump all memories into context unless explicitly asked; always select the smallest relevant subset.

### 3. Create a New Memory

When a user or another skill makes a decision that should persist for future work:

1. Check whether a similar memory already exists:
   ```sql
   SELECT id, title, kind FROM memories
   WHERE status = 'active'
     AND kind = '<kind>'
     AND (
       title LIKE '%<keyword>%'
       OR EXISTS (
         SELECT 1 FROM json_each(tags) t WHERE t.value = '<tag>'
       )
     );
   ```

2. If it is truly new, generate the next ID:
   ```sql
   SELECT 'M-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1)
   FROM memories;
   ```

3. Insert the new memory:
   ```sql
   INSERT INTO memories (
     id, title, kind, why_important, body,
     source_type, source_name, source_via, auto_updatable,
     importance, confidence, status,
     scope, tags, links,
     use_count, created_at, updated_at
   ) VALUES (
     '<id>', '<title>', '<kind>', '<why_important>', '<body>',
     '<source_type>', '<source_name>', '<source_via>', <0_or_1>,
     <importance>, <confidence>, 'active',
     '<scope_json>', '<tags_json>', '<links_json>',
     0, datetime('now'), datetime('now')
   );
   ```

When in doubt whether something deserves a memory, ask: **"Will this decision/convention matter for future tasks?"** If yes, create a memory.

#### Macro Decision Memory Example

When the plan command's macro architectural questions (Phase 3) capture a user decision:

```sql
INSERT INTO memories (
  id, title, kind, why_important, body,
  source_type, source_name, source_via, auto_updatable,
  importance, confidence, status,
  scope, tags
) VALUES (
  'M-0012',
  'Use Redis for queue driver',
  'architecture',
  'Affects all background job processing',
  'User chose Redis as the queue driver during macro analysis. Rationale: existing Redis infrastructure, supports priorities and delayed jobs.',
  'user', 'developer', 'taskmanager:plan:macro-questions', 0,
  4, 1.0, 'active',
  '{"domains": ["infrastructure", "queues"], "tasks": ["1.3", "2.1"]}',
  '["redis", "queue", "architecture"]'
);
```

Note the `scope.tasks` field linking this memory to relevant task IDs. During task execution, the `run` command auto-loads memories where the current task ID appears in `scope.tasks`.

### 4. Update or Supersede an Existing Memory

When an existing memory is refined or corrected:

1. If it's a small correction:
   ```sql
   UPDATE memories SET
     body = '<new_body>',
     tags = '<new_tags_json>',
     scope = '<new_scope_json>',
     updated_at = datetime('now')
   WHERE id = '<memory_id>';
   ```

2. If it's a substantial change or reversal:
   - Create a new memory entry with the updated decision.
   - Mark the old one as superseded:
   ```sql
   UPDATE memories SET
     status = 'superseded',
     superseded_by = '<new_id>',
     updated_at = datetime('now')
   WHERE id = '<old_id>';
   ```

Never silently rewrite history in a way that hides past decisions.

### 5. Track Usage

Whenever a memory directly influences planning or execution:

```sql
UPDATE memories SET
  use_count = use_count + 1,
  last_used_at = datetime('now'),
  updated_at = datetime('now')
WHERE id = '<memory_id>';
```

This allows future tools to treat highly-used, high-importance memories as more trustworthy.

---

## How Other Skills/Commands Should Use This

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

This way, the `memories` table becomes the single, durable "project brain" that all agents/commands/skills can rely on.

---

## 6. Task-Scoped Memory Management

Task-scoped memories are temporary memories that live only for the duration of a single task. They are stored in the `state` table under the `task_memory` JSON column.

### 6.1 Adding Task-Scoped Memory

When a user provides `--task-memory "description"` or `-tm "description"` to a command:

```sql
UPDATE state SET
  task_memory = json_insert(
    task_memory,
    '$[#]',
    json_object(
      'content', '<the description>',
      'addedAt', datetime('now'),
      'taskId', '<current task ID>',
      'source', 'user'
    )
  )
WHERE id = 1;
```

System-generated task memories use `'source', 'system'`.

### 6.2 Retrieving Task-Scoped Memory

Before executing a task:

```sql
SELECT value FROM state, json_each(state.task_memory)
WHERE state.id = 1
  AND (
    json_extract(value, '$.taskId') = '<current_task_id>'
    OR json_extract(value, '$.taskId') = '*'
  );
```

Include these memories alongside global memories when applying constraints.

### 6.3 Promoting Task Memory to Global

At task completion (before marking "done"):

1. Check if any task memories exist for this task.
2. If task memories exist, use `AskUserQuestion` to ask:
   > "The following task memories were used during this task. Should any be promoted to global (persistent) memory?"

   Options for each memory:
   - "Promote to global memory"
   - "Discard (task-specific only)"

3. For promoted memories:
   - Create a new global memory entry in the `memories` table.
   - Set `source_type = 'user'` if originally from user, or `'agent'` if from system.

4. Clear the task memories for this task:
   ```sql
   UPDATE state SET
     task_memory = (
       SELECT json_group_array(value)
       FROM json_each(task_memory)
       WHERE json_extract(value, '$.taskId') != '<task_id>'
     )
   WHERE id = 1;
   ```

---

## 7. Conflict Detection (Opt-In)

Conflict detection is available via `taskmanager:memory conflicts`. It is NOT run automatically during task execution.

When invoked, it checks active memories for:

- **File obsolescence**: Referenced files in `scope.files` that no longer exist
- **Stale memories**: Active memories with `use_count = 0` and `created_at` older than 30 days

### Resolution

For each conflict found, offer resolution options via AskUserQuestion:
- "Keep as-is"
- "Update memory"
- "Deprecate memory"

Record all resolutions in the `conflict_resolutions` JSON column:

```sql
UPDATE memories SET
  conflict_resolutions = json_insert(
    conflict_resolutions,
    '$[#]',
    json_object(
      'timestamp', datetime('now'),
      'resolution', '<kept|modified|deprecated>',
      'reason', '<brief explanation>',
      'taskId', '<task ID>'
    )
  ),
  last_conflict_at = datetime('now'),
  updated_at = datetime('now')
WHERE id = '<memory_id>';
```

---

## 8. Conflict Resolution by Ownership

When resolving conflicts (whether via opt-in detection or during manual review):

### User-Created Memories (`source_type = 'user'`)

NEVER auto-update. ALWAYS ask the user via `AskUserQuestion`.

### System-Created Memories (`source_type != 'user'`)

- **Refinements** (small updates): Auto-update allowed.
- **Reversals** (substantial changes): Ask the user.

---

## 9. Memory Ownership Rules

### 9.1 Determining `auto_updatable`

When creating a memory, set `auto_updatable` based on `source_type`:

```
auto_updatable = (source_type != 'user') ? 1 : 0
```

- `source_type = 'user'` -> `auto_updatable = 0`
- `source_type = 'agent' | 'command' | 'hook' | 'other'` -> `auto_updatable = 1`

### 9.2 Update Rules by Ownership

| Source Type | Small Update | Substantial Change |
|-------------|--------------|-------------------|
| `user`      | Ask user     | Ask user          |
| `agent`     | Auto-update  | Ask user          |
| `command`   | Auto-update  | Ask user          |
| `hook`      | Auto-update  | Ask user          |
| `other`     | Auto-update  | Ask user          |

### 9.3 Never Delete Memories

Memories are **never deleted**. They are either:
- Kept as `active`
- Marked as `deprecated` (no longer relevant)
- Marked as `superseded` with a pointer to the new memory

This preserves decision history and audit trail.

---

## 10. Logging

All logging goes to a single file: `.taskmanager/logs/activity.log`.

```
<timestamp> [<level>] [memory] <message>
```

Levels: `ERROR`, `DECISION`. Logs are append-only.

Log these events:
- Memory created, updated, deprecated, superseded
- Memory applied to task
- Conflict detection and resolution
- Errors (database failures, invalid IDs, query errors)

Examples:
```text
2025-12-11T10:00:00Z [DECISION] [memory] Created memory M-0005: "Always validate API inputs"
2025-12-11T10:00:01Z [DECISION] [memory] Applied memories to task 1.2: M-0001, M-0003, M-0005
2025-12-11T10:00:02Z [ERROR] [memory] Conflict: M-0001 references deleted file app/OldAuth.php
2025-12-11T10:05:00Z [DECISION] [memory] Deprecated M-0002: "No longer using old auth pattern"
```

---

## SQL Quick Reference

### Common Queries

**Get all active memories:**
```sql
SELECT * FROM memories WHERE status = 'active' ORDER BY importance DESC, use_count DESC;
```

**Full-text search:**
```sql
SELECT m.* FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH '<search_term>'
  AND m.status = 'active'
ORDER BY rank, m.importance DESC;
```

**Get memories for a specific file:**
```sql
SELECT * FROM memories
WHERE status = 'active'
  AND (
    scope = '{}'
    OR json_extract(scope, '$.files') IS NULL
    OR EXISTS (
      SELECT 1 FROM json_each(json_extract(scope, '$.files')) f
      WHERE '<current_file>' LIKE f.value
    )
  )
ORDER BY importance DESC;
```

**Record memory usage:**
```sql
UPDATE memories
SET use_count = use_count + 1,
    last_used_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = '<memory_id>';
```

**Record conflict resolution:**
```sql
UPDATE memories SET
  conflict_resolutions = json_insert(
    conflict_resolutions,
    '$[#]',
    json_object(
      'timestamp', datetime('now'),
      'resolution', '<resolution>',
      'reason', '<reason>',
      'taskId', '<taskId>'
    )
  ),
  last_conflict_at = datetime('now'),
  updated_at = datetime('now')
WHERE id = '<memory_id>';
```

**Get next memory ID:**
```sql
SELECT 'M-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1)
FROM memories;
```

**Deprecate a memory:**
```sql
UPDATE memories SET
  status = 'deprecated',
  updated_at = datetime('now')
WHERE id = '<memory_id>';
```

**Supersede a memory:**
```sql
UPDATE memories SET
  status = 'superseded',
  superseded_by = '<new_memory_id>',
  updated_at = datetime('now')
WHERE id = '<old_memory_id>';
```
