---
name: secretary
description: Capture and manage decisions, commitments, ideas, sessions, and knowledge. The core data management skill for the secretary plugin.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Secretary Skill

Capture commitments, record decisions, track ideas, manage sessions, and maintain the full knowledge base.

## When to Use

- Analyzing conversation for commitments, decisions, or ideas
- Recording a new commitment, decision, or idea manually
- Updating the status of a tracked item (complete, defer, cancel)
- Managing queue items and worker processing
- Updating the knowledge graph
- Managing goals and milestones
- Accessing or managing encrypted memory entries
- Checking worker and queue status

## Database Locations

```bash
# Main database
SECRETARY_DB_PATH="$HOME/.claude/secretary/secretary.db"

# Encrypted memory database
SECRETARY_MEMORY_DB_PATH="$HOME/.claude/secretary/memory.db"

# Configuration
SECRETARY_CONFIG_FILE="$HOME/.claude/secretary.json"

# Scripts
PLUGIN_ROOT="$HOME/.claude/plugins/secretary"  # or wherever installed
```

## Commitment Management

### Recording a Commitment

```sql
-- Get next ID
SELECT 'C-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) as next_id
FROM commitments;

-- Insert
INSERT INTO commitments (
    id, title, description, source_type, source_session_id,
    source_context, project, assignee, stakeholder,
    due_date, due_type, priority, status
) VALUES (
    :id, :title, :description, :source_type, :session_id,
    :context, :project, :assignee, :stakeholder,
    :due_date, :due_type, :priority, 'pending'
);
```

### Updating Commitments

```sql
-- Complete
UPDATE commitments SET
    status = 'completed', completed_at = datetime('now'), updated_at = datetime('now')
WHERE id = :id;

-- Defer
UPDATE commitments SET
    status = 'deferred', deferred_until = :date,
    deferred_count = deferred_count + 1, updated_at = datetime('now')
WHERE id = :id;

-- Cancel
UPDATE commitments SET
    status = 'canceled', updated_at = datetime('now')
WHERE id = :id;

-- Change priority
UPDATE commitments SET
    priority = :new_priority, updated_at = datetime('now')
WHERE id = :id;
```

### Listing Commitments

```sql
-- All pending (sorted by priority)
SELECT id, title, due_date, priority, project, status
FROM commitments
WHERE status IN ('pending', 'in_progress')
ORDER BY
    CASE WHEN due_date < date('now') THEN 0 ELSE 1 END,
    CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    due_date ASC;

-- By project
SELECT id, title, due_date, priority, status
FROM commitments
WHERE project = :project AND status IN ('pending', 'in_progress')
ORDER BY priority DESC;

-- Overdue only
SELECT id, title, due_date, priority, project
FROM commitments
WHERE status IN ('pending', 'in_progress') AND due_date < date('now')
ORDER BY due_date ASC;
```

### Detection Patterns

Look for these phrases in conversation:

**Commitments:**
- "I will...", "I'll...", "Let me..."
- "We should...", "We need to..."
- "TODO:", "FIXME:", "Follow up on..."
- "Don't forget to...", "Make sure to..."
- "Remind me to...", "Get back to..."

## Decision Recording

### Recording a Decision

```sql
-- Get next ID
SELECT 'D-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) as next_id
FROM decisions;

-- Insert
INSERT INTO decisions (
    id, title, description, rationale, alternatives,
    consequences, category, scope, project,
    source_session_id, source_context, status, tags
) VALUES (
    :id, :title, :description, :rationale, :alternatives_json,
    :consequences, :category, :scope, :project,
    :session_id, :context, 'active', :tags_json
);
```

### Updating Decisions

```sql
-- Supersede
UPDATE decisions SET
    status = 'superseded', superseded_by = :new_decision_id,
    updated_at = datetime('now')
WHERE id = :old_id;

-- Reverse
UPDATE decisions SET
    status = 'reversed', updated_at = datetime('now')
WHERE id = :id;
```

### Detection Patterns

**Decisions:**
- "Decided to...", "The decision is..."
- "Let's go with...", "We'll use..."
- "The approach is...", "The plan is..."
- "From now on...", "Going forward..."
- "Instead of...", "Rather than..."

### Extraction Process

1. Identify decision phrase
2. Extract what was decided
3. Look for rationale ("because", "since", "due to")
4. Identify alternatives mentioned ("instead of", "rather than")
5. Categorize: `architecture`, `process`, `technology`, `design`
6. Determine scope: `project-wide`, `feature`, `component`

## Idea Capture

### Recording an Idea

```sql
-- Get next ID
SELECT 'I-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) as next_id
FROM ideas;

-- Insert
INSERT INTO ideas (
    id, title, description, idea_type, category,
    project, source_session_id, source_context,
    priority, effort, potential_impact, status, tags
) VALUES (
    :id, :title, :description, :type, :category,
    :project, :session_id, :context,
    :priority, :effort, :impact, 'captured', :tags_json
);
```

### Updating Ideas

```sql
-- Start exploring
UPDATE ideas SET status = 'exploring', updated_at = datetime('now') WHERE id = :id;

-- Park for later
UPDATE ideas SET status = 'parked', updated_at = datetime('now') WHERE id = :id;

-- Mark done
UPDATE ideas SET status = 'done', updated_at = datetime('now') WHERE id = :id;

-- Discard
UPDATE ideas SET status = 'discarded', updated_at = datetime('now') WHERE id = :id;
```

## Goal Management

### Creating a Goal

```sql
SELECT 'G-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) as next_id
FROM goals;

INSERT INTO goals (
    id, title, description, goal_type, timeframe,
    parent_goal_id, project, target_value, target_unit,
    target_date, status, milestones, related_commitments
) VALUES (
    :id, :title, :description, :type, :timeframe,
    :parent_id, :project, :target_value, :target_unit,
    :target_date, 'active', :milestones_json, :related_json
);
```

### Updating Goal Progress

```sql
UPDATE goals SET
    current_value = :value,
    progress_percentage = ROUND(100.0 * :value / NULLIF(target_value, 0), 1),
    updated_at = datetime('now')
WHERE id = :id;
```

## Activity Timeline

### Event Types

| Type | Description |
|------|-------------|
| `session_start` | New session began |
| `session_end` | Session completed |
| `commitment` | Commitment extracted |
| `commitment_completed` | Commitment marked done |
| `decision` | Decision recorded |
| `goal_progress` | Goal updated |
| `goal_completed` | Goal finished |
| `commit` | Git commit made |
| `external_change` | Change detected from outside |

### Recording Activity

```sql
INSERT INTO activity_timeline (
    activity_type, entity_type, entity_id,
    project, title, details, session_id
) VALUES (:type, :entity_type, :entity_id, :project, :title, :details_json, :session_id);
```

## Knowledge Graph

### Node Types

| Type | Description |
|------|-------------|
| `project` | Software projects |
| `technology` | Languages, frameworks, tools |
| `person` | Team members, stakeholders |
| `concept` | Architectural patterns, methodologies |
| `tool` | Development tools, services |

### Creating/Updating Nodes

```sql
SELECT 'N-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) as next_id
FROM knowledge_nodes;

INSERT INTO knowledge_nodes (id, name, node_type, description, properties, aliases)
VALUES (:id, :name, :type, :description, :properties_json, :aliases_json)
ON CONFLICT(id) DO UPDATE SET
    description = COALESCE(:description, description),
    interaction_count = interaction_count + 1,
    last_interaction = datetime('now'),
    updated_at = datetime('now');
```

### Creating/Updating Edges

```sql
SELECT 'E-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) as next_id
FROM knowledge_edges;

INSERT INTO knowledge_edges (id, source_node_id, target_node_id, relationship, strength, properties)
VALUES (:id, :source, :target, :relationship, :strength, :properties_json)
ON CONFLICT(id) DO UPDATE SET
    strength = MIN(strength + 0.1, 1.0),
    updated_at = datetime('now');
```

### Relationship Types

- `uses` - Project uses technology
- `knows` - Person knows technology
- `owns` - Person owns project
- `depends_on` - Project depends on another
- `related_to` - General relationship

## Encrypted Memory

Manage sensitive data via the memory manager script:

```bash
SCRIPT="$PLUGIN_ROOT/scripts/memory-manager.sh"

# Add a memory entry
bash "$SCRIPT" add "AWS API Key" "AKIA..." api_key "my-project" "aws,production"

# Search memory
bash "$SCRIPT" search "API key"

# List by category
bash "$SCRIPT" list credential
bash "$SCRIPT" list api_key my-project

# View a specific entry
bash "$SCRIPT" show 1

# Delete an entry
bash "$SCRIPT" delete 1

# Check encryption status
bash "$SCRIPT" status
```

Categories: `credential`, `api_key`, `ip_address`, `phone`, `secret`, `note`, `general`

## Queue Operations

### Check Queue Status

```sql
SELECT status, COUNT(*) as count
FROM queue
GROUP BY status;
```

### Force Process Queue

```bash
bash "$PLUGIN_ROOT/scripts/process-queue.sh" --limit 10
```

### Check Worker State

```sql
SELECT last_run_at, last_success_at, last_error,
    items_processed, total_runs,
    last_vault_sync_at, last_github_refresh_at
FROM worker_state WHERE id = 1;
```

## Daily Notes

```sql
-- Create or update daily note
INSERT INTO daily_notes (id, date)
VALUES (date('now'), date('now'))
ON CONFLICT(id) DO NOTHING;

-- Update with session data
UPDATE daily_notes SET
    sessions_count = sessions_count + 1,
    last_activity_at = datetime('now'),
    updated_at = datetime('now')
WHERE date = date('now');
```

## ID Generation

```bash
# Pattern for all entity IDs
# C-0001 for commitments
# D-0001 for decisions
# I-0001 for ideas
# G-0001 for goals
# P-0001 for patterns
# N-0001 for knowledge nodes
# E-0001 for knowledge edges

# SQL pattern to get next ID:
SELECT '<PREFIX>-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, LENGTH('<PREFIX>') + 2) AS INTEGER)), 0) + 1)
FROM <table>;
```

## Output Guidelines

When reporting captured items:

```markdown
## Captured

### Commitment
- **ID:** C-0025
- **Title:** Implement caching layer
- **Priority:** High
- **Due:** This week
- **Source:** Conversation

### Decision
- **ID:** D-0018
- **Title:** Use Redis for caching
- **Category:** Architecture
- **Rationale:** Better performance for distributed systems

### Idea
- **ID:** I-0015
- **Title:** GraphQL migration
- **Type:** Exploration
- **Impact:** High
```

## Silence Mode

When operating via hooks (capture.sh), work silently:
- Do not output unless explicitly requested
- Log to activity_timeline for later review
- Items are reviewed via `/secretary:status` or `/secretary:briefing`

## Error Handling

- Skip malformed or ambiguous items during extraction
- Log extraction failures to debug log
- Continue processing on individual item failures
- Retry failed queue items up to 3 times
- Expire unprocessed queue items after 24 hours

## Related Commands

- `/secretary:track` - Manage commitments (add, complete, defer, list)
- `/secretary:decide` - Record decisions with rationale
- `/secretary:idea` - Capture ideas
- `/secretary:status` - Show full dashboard
- `/secretary:briefing` - Generate context briefing
- `/secretary:memory` - Manage encrypted memory
- `/secretary:worker` - Check/trigger worker processing
