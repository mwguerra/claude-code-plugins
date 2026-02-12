---
allowed-tools: Skill(taskmanager), Bash, AskUserQuestion
argument-hint: "[file-path-or-folder-or-prompt] [--expand <id>] [--expand-all] [--no-expand] [--research] [--skip-analysis] [--milestones]"
description: Parse a PRD into tasks, or expand existing tasks into subtasks
---

# Plan Command

You are implementing the `taskmanager:plan` command.

## Arguments

- `$1` (optional): path to a PRD file, a folder containing documentation files, or a prompt describing what to plan. If omitted, use `.taskmanager/docs/prd.md`.
- `--research`: Research key topics from the PRD before generating tasks (uses `taskmanager:research` internally)
- `--expand <id>`: Expand a single task into subtasks (post-planning)
- `--expand-all [--threshold <XS|S|M|L|XL>]`: Expand all eligible tasks above threshold (default: M)
- `--force`: Re-expand tasks that already have subtasks
- `--estimate`: Generate time estimates (not default during expansion)
- `--skip-analysis`: Bypass Phases 2-4 (PRD analysis, macro questions, milestones) for quick re-planning
- `--no-expand`: Skip the automatic post-plan expansion loop (Phase 7). By default, all eligible tasks are auto-expanded after initial planning.
- `--milestones` (default: on): Control milestone generation. Use `--no-milestones` to disable.

## Database

This command uses SQLite database at `.taskmanager/taskmanager.db`.

**Schema reference for tasks table:**
```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    details TEXT,
    test_strategy TEXT,
    status TEXT NOT NULL DEFAULT 'planned',
    type TEXT NOT NULL DEFAULT 'feature',
    priority TEXT NOT NULL DEFAULT 'medium',
    complexity_scale TEXT,
    complexity_reasoning TEXT,
    complexity_expansion_prompt TEXT,
    estimate_seconds INTEGER,
    tags TEXT DEFAULT '[]',
    dependencies TEXT DEFAULT '[]',
    dependency_analysis TEXT,
    meta TEXT DEFAULT '{}',
    milestone_id TEXT REFERENCES milestones(id),
    acceptance_criteria TEXT DEFAULT '[]',
    moscow TEXT CHECK (moscow IN ('must', 'should', 'could', 'wont')),
    business_value INTEGER CHECK (business_value BETWEEN 1 AND 5),
    dependency_types TEXT DEFAULT '{}',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);
```

**Schema reference for milestones table:**
```sql
CREATE TABLE milestones (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    acceptance_criteria TEXT DEFAULT '[]',
    target_date TEXT,
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned', 'active', 'completed', 'canceled')),
    phase_order INTEGER NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);
```

**Schema reference for plan_analyses table:**
```sql
CREATE TABLE plan_analyses (
    id TEXT PRIMARY KEY,
    prd_source TEXT NOT NULL,
    prd_hash TEXT,
    tech_stack TEXT DEFAULT '[]',
    assumptions TEXT DEFAULT '[]',
    risks TEXT DEFAULT '[]',
    ambiguities TEXT DEFAULT '[]',
    nfrs TEXT DEFAULT '[]',
    scope_in TEXT,
    scope_out TEXT,
    cross_cutting TEXT DEFAULT '[]',
    decisions TEXT DEFAULT '[]',
    milestone_ids TEXT DEFAULT '[]',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);
```

## Routing

- `plan` → parse PRD from `.taskmanager/docs/prd.md`
- `plan <file-or-folder-or-prompt>` → parse input into tasks
- `plan --expand <id>` → expand single task into subtasks
- `plan --expand-all` → bulk expand all eligible tasks
- `plan --expand-all --threshold L` → expand only L and XL tasks

## Behavior

### 0. Initialize session

1. Generate session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Verify database exists.
3. Update state table with session_id.
4. Log to `activity.log`.

### PRD Planning Mode (no --expand flags)

### 1. Determine input type
   - If the user provided an argument, determine if `$1` is:
     1. **A folder path** - Contains multiple documentation files
     2. **A file path** - A single PRD/documentation file
     3. **A prompt** - Free-text describing what should be done
   - If nothing is provided, default to `.taskmanager/docs/prd.md`.

### 1.1 Handling folder input

When `$1` is a folder (directory):

1. **Discover documentation files** - Use Glob to find all markdown files (`**/*.md`) in the folder and its subdirectories.
2. **Read all files** - Use Read to load the content of each discovered file.
3. **Aggregate content** - Combine all file contents into a single PRD context, preserving the source file names as section headers.
4. **Pass aggregated content to the skill**.

### 1.5 PRD Analysis Phase (Phase 2 — unless --skip-analysis)

Before generating tasks, perform structured analysis:

1. **Compute PRD content hash** (SHA-256 of the aggregated PRD text):
   ```bash
   echo -n "<prd-content>" | sha256sum | cut -d' ' -f1
   ```

2. **Check for existing analysis** with same hash:
   ```sql
   SELECT * FROM plan_analyses WHERE prd_hash = '<hash>' ORDER BY created_at DESC LIMIT 1;
   ```
   If found, reuse the existing analysis (skip to Step 1.7).

3. **Detect tech stack** — Scan PRD content and codebase:
   - Check for `composer.json` (Laravel/PHP), `package.json` (Node/React/Vue), `requirements.txt` (Python), etc.
   - Look for framework-specific patterns in PRD text
   - Store as JSON array: `["laravel", "filament", "react", "redis", "postgresql"]`

4. **Identify assumptions** — What's implied but not stated:
   - Store as JSON: `[{"description": "...", "confidence": "high|medium|low", "impact": "high|medium|low"}]`

5. **Identify risks** — Technical, integration, and scope risks:
   - Store as JSON: `[{"description": "...", "severity": "high|medium|low", "likelihood": "high|medium|low", "mitigation": "..."}]`

6. **Detect ambiguities** — Unclear requirements that need clarification:
   - Store as JSON: `[{"requirement": "...", "question": "...", "resolution": null}]`
   - These feed into Phase 3 (macro questions)

7. **Identify NFRs** — Non-functional requirements:
   - Store as JSON: `[{"category": "performance|security|accessibility|monitoring", "requirement": "...", "priority": "high|medium|low"}]`

8. **Define scope boundaries** — Explicit in/out of scope:
   - `scope_in`: What IS in scope
   - `scope_out`: What is explicitly OUT of scope

9. **Detect cross-cutting concerns** — Concerns spanning multiple features:
   - Store as JSON: `[{"concern": "error-handling", "affected_epics": ["1", "2", "3"], "strategy": "Global exception handler + per-feature error boundaries"}]`

10. **Generate next analysis ID and insert**:
    ```sql
    SELECT 'PA-' || printf('%03d', COALESCE(MAX(CAST(SUBSTR(id, 4) AS INTEGER)), 0) + 1)
    FROM plan_analyses;

    INSERT INTO plan_analyses (id, prd_source, prd_hash, tech_stack, assumptions, risks, ambiguities, nfrs, scope_in, scope_out, cross_cutting)
    VALUES ('<id>', '<source>', '<hash>', '<tech_json>', '<assumptions_json>', '<risks_json>', '<ambiguities_json>', '<nfrs_json>', '<scope_in>', '<scope_out>', '<cross_cutting_json>');
    ```

11. **Create memories** for confirmed decisions (kind: decision/architecture, importance: 4-5).

### 1.6 Macro Architectural Questions (Phase 3 — unless --skip-analysis)

1. Based on detected tech stack, consult the Macro Question Bank (see `skills/taskmanager/references/MACRO-QUESTIONS.md`).
2. Filter out questions already answered by:
   - The PRD content itself
   - Existing active memories (kind: architecture/decision, importance >= 4)
3. Present remaining relevant questions via **AskUserQuestion** (batched, 1-4 per call).
4. For each answer:
   a. Generate next memory ID and insert memory:
      ```sql
      INSERT INTO memories (id, title, kind, why_important, body, source_type, source_name, source_via, auto_updatable, importance, confidence, status, scope, tags)
      VALUES ('<id>', '<title>', '<kind>', '<why>', '<body>', 'user', 'developer', 'taskmanager:plan:macro-questions', 0, <importance>, 1.0, 'active', '<scope_json>', '<tags_json>');
      ```
   b. Update plan_analyses.decisions:
      ```sql
      UPDATE plan_analyses SET
          decisions = json_insert(decisions, '$[#]', json_object('question', '<q>', 'answer', '<a>', 'rationale', 'User decision', 'memory_id', '<mem-id>')),
          updated_at = datetime('now')
      WHERE id = '<analysis-id>';
      ```

### 1.7 Milestone Definition (Phase 4 — unless --skip-analysis or --no-milestones)

1. Based on analysis, assign MoSCoW classification to each identified epic/feature.
2. Create milestones:
   ```sql
   INSERT INTO milestones (id, title, description, phase_order, status)
   VALUES
       ('MS-001', 'MVP / Core', 'Must-have features for initial release', 1, 'planned'),
       ('MS-002', 'Enhancement', 'Should-have features for post-MVP', 2, 'planned'),
       ('MS-003', 'Nice-to-have', 'Could-have features if time permits', 3, 'planned');
   ```
   Only create milestones that have tasks assigned to them.

3. Update plan_analyses.milestone_ids:
   ```sql
   UPDATE plan_analyses SET
       milestone_ids = '["MS-001", "MS-002", "MS-003"]',
       updated_at = datetime('now')
   WHERE id = '<analysis-id>';
   ```

### 2. Generate and insert tasks (Phase 5 — Enhanced)

1. Call the `taskmanager` skill with instructions to generate a hierarchical plan.
2. Every task MUST include:
   - `acceptance_criteria` — JSON array of "done" criteria
   - `moscow` — must/should/could/wont
   - `business_value` — 1-5
   - `milestone_id` — from Phase 4 mapping
   - `dependency_types` — JSON object for typed dependencies
3. If cross-cutting concerns were identified, generate a cross-cutting epic.
4. **Insert tasks via SQL transaction** for atomicity.

**Important SQL notes:**
- Use single quotes for string values, escape internal quotes by doubling them.
- JSON fields must be valid JSON strings.
- `parent_id` must reference an existing task ID or be NULL for top-level tasks.
- `milestone_id` must reference an existing milestone ID or be NULL.
- Insert milestones before tasks. Insert parent tasks before their children.
- Always wrap multiple inserts in a transaction.

### 3. Enhanced Summary (Phase 6)

Query and display:

1. **Milestone breakdown**:
   ```sql
   SELECT m.id, m.title, m.phase_order,
       COUNT(t.id) as total_tasks,
       SUM(CASE WHEN t.moscow = 'must' THEN 1 ELSE 0 END) as must_count,
       SUM(CASE WHEN t.moscow = 'should' THEN 1 ELSE 0 END) as should_count
   FROM milestones m
   LEFT JOIN tasks t ON t.milestone_id = m.id AND t.archived_at IS NULL
   GROUP BY m.id
   ORDER BY m.phase_order;
   ```

2. **MoSCoW distribution**:
   ```sql
   SELECT moscow, COUNT(*) as count FROM tasks
   WHERE archived_at IS NULL GROUP BY moscow;
   ```

3. **Analysis summary**: Key risks, assumptions, decisions made.
4. **Task counts** per status.

### 4. Auto-Expansion Loop (Phase 7 — unless --no-expand)

After the summary, automatically expand all eligible tasks. This eliminates the need for a separate `--expand-all` invocation after planning.

**Skip conditions** — skip this phase entirely if:
- `--no-expand` flag is set, OR
- `auto_expand_after_plan` is `false` in config (`default-config.json` → `planning`), OR
- `--expand` or `--expand-all` flags are present (standalone expansion mode)

**Procedure:**

1. Read the complexity threshold from config (`defaults.complexity_threshold_for_expansion`, default: `"M"`).
2. Read the max subtask depth from config (`defaults.max_subtask_depth`, default: `3`).
3. **Loop** until no more eligible tasks remain:
   a. Query eligible tasks (same query as `--expand-all`):
      ```sql
      SELECT id, title, description, details, test_strategy, complexity_scale,
             complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies,
             milestone_id, acceptance_criteria, moscow, business_value
      FROM tasks
      WHERE archived_at IS NULL
        AND status NOT IN ('done', 'canceled', 'duplicate')
        AND CASE complexity_scale
            WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE -1
        END >= <threshold_value>
        AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id)
        AND LENGTH(REPLACE(REPLACE(id, '.', ''), id, '')) < <max_subtask_depth>
      ORDER BY
          CASE complexity_scale WHEN 'XL' THEN 0 WHEN 'L' THEN 1 WHEN 'M' THEN 2 WHEN 'S' THEN 3 ELSE 4 END,
          CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
          id;
      ```
      The depth check (`LENGTH(REPLACE(...))`) counts dots in the ID to determine current depth, ensuring tasks beyond `max_subtask_depth` are not expanded further.
   b. If no eligible tasks found, exit the loop.
   c. For each eligible task, expand it using the same logic as `--expand <id>` (see Expansion Mode below).
   d. After expanding a batch, re-query to check if newly created subtasks are themselves eligible for further expansion.
4. Display a summary of expansions performed:
   ```
   Auto-expansion complete:
   - X tasks expanded
   - Y subtasks created
   - Deepest level reached: Z
   ```

### Expansion Mode (--expand)

### expand <id> — Single task expansion

1. Load the task:
   ```sql
   SELECT id, title, description, details, test_strategy, complexity_scale,
          complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies,
          milestone_id, acceptance_criteria, moscow, business_value
   FROM tasks WHERE id = '<task-id>' AND archived_at IS NULL;
   ```

2. Validate:
   - If task doesn't exist, inform user and stop.
   - If task already has subtasks and `--force` not set: inform user and stop.
   - If `--force` set: warn user, delete existing subtasks.

3. Load pending deferrals targeting this task:
   ```sql
   SELECT d.id, d.title, d.body, d.reason
   FROM deferrals d
   WHERE d.target_task_id = '<task-id>' AND d.status = 'pending'
   ORDER BY d.created_at;
   ```
   Include these as additional scope/requirements when generating subtasks.

4. Generate subtasks using the `taskmanager` skill:
   - Use `complexity_expansion_prompt` if available.
   - Each subtask gets: id, title, description, details, test_strategy, status, type, priority, complexity_scale, estimate_seconds, tags, dependencies, milestone_id (inherited), acceptance_criteria, moscow (inherited), business_value, dependency_types.
   - Subtask IDs follow parent pattern (e.g., parent `1.2` gets `1.2.1`, `1.2.2`).

5. Insert subtasks and update parent estimate via SQL transaction.

6. Check if any new subtasks need further expansion (recursive check).

### expand --all — Bulk expansion

Map threshold to complexity_scale order:
```
XS < S < M < L < XL
```

```sql
SELECT id, title, description, details, test_strategy, complexity_scale,
       complexity_reasoning, complexity_expansion_prompt, priority, type, tags, dependencies,
       milestone_id, acceptance_criteria, moscow, business_value
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND CASE complexity_scale
      WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE -1
  END >= <threshold_value>
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id)
ORDER BY
    CASE complexity_scale WHEN 'XL' THEN 0 WHEN 'L' THEN 1 WHEN 'M' THEN 2 WHEN 'S' THEN 3 ELSE 4 END,
    CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    id;
```

Expand each eligible task, then recursively check new subtasks.

### 4. Cleanup

Log to `activity.log`. Reset state session.

## Logging

All logging goes to `.taskmanager/logs/activity.log`:
- Command start and completion
- PRD analysis results summary
- Macro questions asked and answers received
- Milestones created
- Task creation summaries
- Expansion details
- Errors

## Error Handling

- If database does not exist, instruct user to run `taskmanager:init`.
- If INSERT fails due to duplicate ID, report conflict and suggest resolution.
- If foreign key constraint fails, check task insertion order (milestones before tasks, parents before children).
- Always ROLLBACK transaction on error.

## Usage Examples

```bash
# Plan from default PRD
taskmanager:plan

# Plan from file
taskmanager:plan docs/new-feature-prd.md

# Plan from folder
taskmanager:plan docs/project-specs/

# Plan from prompt
taskmanager:plan "Create a react counter app"

# Plan with research
taskmanager:plan docs/prd.md --research

# Plan without analysis (quick mode)
taskmanager:plan docs/prd.md --skip-analysis

# Plan without milestones
taskmanager:plan docs/prd.md --no-milestones

# Plan without auto-expansion (tasks stay as top-level only)
taskmanager:plan docs/prd.md --no-expand

# Expand a single task
taskmanager:plan --expand 1.2

# Re-expand a task
taskmanager:plan --expand 1.2 --force

# Expand all tasks with complexity M or above
taskmanager:plan --expand-all

# Expand only L and XL tasks
taskmanager:plan --expand-all --threshold L
```

## Related Commands

- `taskmanager:show` - View tasks, dashboard, stats
- `taskmanager:show --milestones` - View milestone progress
- `taskmanager:show --analysis` - View plan analyses
- `taskmanager:run` - Execute tasks
- `taskmanager:research` - Research before planning
- `taskmanager:update` - Update task fields
