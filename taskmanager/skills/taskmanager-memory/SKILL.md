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
| `scope` | TEXT (JSON) | Object with: `project`, `files`, `tasks`, `commands`, `agents`, `domains` |
| `tags` | TEXT (JSON) | Array of free-form tags, e.g. `["testing", "laravel"]` |
| `links` | TEXT (JSON) | Array of links to docs/PRs/etc |
| `use_count` | INTEGER | Usage counter, default 0 |
| `last_used_at` | TEXT | ISO timestamp of last use |
| `last_conflict_at` | TEXT | ISO timestamp of last detected conflict |
| `conflict_resolutions` | TEXT (JSON) | Array of conflict resolution history entries |
| `created_at` | TEXT | ISO timestamp |
| `updated_at` | TEXT | ISO timestamp |

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

## 7. Conflict Detection

Conflict detection runs automatically at the **start** and **end** of every task execution.

### 7.1 When to Run Conflict Detection

- **Pre-execution**: After loading relevant memories, before starting work.
- **Post-execution**: After task work is complete, before marking status as "done".

### 7.2 Conflict Detection Algorithm

For each **active** memory that was loaded for this task:

1. **File/Pattern Obsolescence Check**:
   - Query memories with file scopes:
     ```sql
     SELECT id, title, scope FROM memories
     WHERE status = 'active'
       AND json_extract(scope, '$.files') IS NOT NULL;
     ```
   - Use `Glob` to check if referenced files/directories still exist.
   - If any file path no longer exists, flag as obsolete conflict.

2. **Implementation Divergence Check**:
   - Analyze `body` for specific implementation requirements.
   - Check if current codebase contradicts the memory:
     - Example: Memory says "use TypeScript strict mode" but `tsconfig.json` has `strict: false`.
     - Example: Memory says "always use Pest for tests" but new tests use PHPUnit.
   - If contradiction detected, flag as divergence conflict.

3. **Test Failure Check**:
   - Query memories with testing-related domains:
     ```sql
     SELECT id, title FROM memories
     WHERE status = 'active'
       AND EXISTS (
         SELECT 1 FROM json_each(json_extract(scope, '$.domains')) d
         WHERE d.value LIKE '%test%'
       );
     ```
   - Check if recent test runs show failures in related areas.
   - If tests are failing in memory-scoped areas, flag as test failure conflict.

### 7.3 Conflict Severity

Classify conflicts by severity:

- **Critical**: Memory with `importance >= 4` has a divergence conflict.
- **Warning**: Memory with `importance < 4` has any conflict.
- **Info**: File obsolescence where the file is not critical.

---

## 8. Conflict Resolution Workflow

When a conflict is detected, the resolution process depends on the memory's ownership.

### 8.1 User-Created Memories (`source_type = 'user'`)

NEVER auto-update. ALWAYS ask the user.

Use `AskUserQuestion` with options:

1. **"Keep memory as-is"**
   - Acknowledge the conflict but take no action.
   - Record resolution:
     ```sql
     UPDATE memories SET
       conflict_resolutions = json_insert(
         conflict_resolutions,
         '$[#]',
         json_object(
           'timestamp', datetime('now'),
           'resolution', 'kept',
           'reason', '<brief explanation>',
           'taskId', '<task ID>'
         )
       ),
       last_conflict_at = datetime('now'),
       updated_at = datetime('now')
     WHERE id = '<memory_id>';
     ```

2. **"Update memory to reflect current state"**
   - Update the memory's `body`, `tags`, or `scope` to match current implementation.
   - Record with `'resolution', 'modified'`.

3. **"Deprecate this memory"**
   - Set `status = 'deprecated'`.
   - Record with `'resolution', 'deprecated'`.

4. **"Supersede with new memory"**
   - Create a new memory with updated decision.
   - Set old memory `status = 'superseded'` and `superseded_by = '<new_id>'`.
   - Record with `'resolution', 'superseded'`.

### 8.2 System-Created Memories (`source_type != 'user'`)

For system-created memories (`source_type` is `agent`, `command`, `hook`, or `other`):

- **Refinements** (small updates that don't reverse the decision):
  - Auto-update allowed. Update `body`, bump `updated_at`.
  - Record with `'resolution', 'modified'`.

- **Reversals** (substantial change or contradiction):
  - Ask the user using `AskUserQuestion` with same options as 8.1.

### 8.3 Recording Conflict Resolutions

Every conflict resolution MUST be recorded using:

```sql
UPDATE memories SET
  conflict_resolutions = json_insert(
    conflict_resolutions,
    '$[#]',
    json_object(
      'timestamp', datetime('now'),
      'resolution', '<kept|modified|deprecated|superseded>',
      'reason', '<brief explanation>',
      'taskId', '<task ID where conflict was detected>'
    )
  ),
  last_conflict_at = datetime('now'),
  updated_at = datetime('now')
WHERE id = '<memory_id>';
```

### 8.4 Conflict Resolution in Batch/Auto-Run Mode

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

## 10. Logging Behavior

This skill MUST write to the log files under `.taskmanager/logs/` for all memory operations.

### 10.1 What to Log

**errors.log** - ALWAYS append when:
- Database connection failures
- SQL query errors
- Conflict detection finds issues
- Invalid memory IDs referenced

Example:
```text
2025-12-11T10:00:00Z [ERROR] [sess-abc123] SQLite error: no such table: memories
2025-12-11T10:00:01Z [ERROR] [sess-abc123] Conflict: M-0001 references deleted file app/OldAuth.php
2025-12-11T10:00:02Z [ERROR] [sess-abc123] Memory M-9999 not found when attempting update
```

**decisions.log** - ALWAYS append when:
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

**debug.log** - ONLY append when debug mode is enabled in state:
- SQL queries executed
- Memory matching algorithm steps
- Conflict detection intermediate results
- Full memory state dumps
- File existence checks during conflict detection

Example:
```text
2025-12-11T10:00:00Z [DEBUG] [sess-abc123] SQL: SELECT * FROM memories WHERE status = 'active'
2025-12-11T10:00:01Z [DEBUG] [sess-abc123] Found 8 active memories
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

Check the state table for debug mode:

```sql
SELECT json_extract(logging, '$.debugEnabled') FROM state WHERE id = 1;
```

- If result is `1`: Write verbose DEBUG entries to debug.log
- If result is `0` or NULL: Skip DEBUG entries, only write ERROR and DECISION

The calling command is responsible for setting debug mode based on `--debug` flag.

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
