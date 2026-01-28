---
name: workflow-secretary
description: Extract and record commitments, decisions, and activity from conversations
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Workflow Secretary Skill

Capture commitments, record decisions, and maintain activity logs.

## When to Use

- Analyzing conversation for commitments/decisions
- Recording a new commitment manually
- Logging a decision with rationale
- Updating activity timeline
- Managing knowledge graph entities

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## Commitment Extraction

### Detection Patterns

Look for these phrases in conversation:
- "I will...", "I'll...", "Let me..."
- "We should...", "We need to..."
- "TODO:", "FIXME:", "Follow up on..."
- "Don't forget to...", "Make sure to..."
- "Remind me to...", "Get back to..."

### Extraction Process

1. Identify commitment phrase
2. Extract the action/promise
3. Detect priority keywords (urgent, critical, asap)
4. Detect due date references (today, tomorrow, this week)
5. Identify stakeholder if mentioned
6. Generate commitment ID

### Recording

```sql
INSERT INTO commitments (
    id, title, description, source_type, source_session_id,
    source_context, project, priority, due_type, status
) VALUES (
    :id, :title, :description, 'conversation', :session_id,
    :context, :project, :priority, :due_type, 'pending'
);
```

## Decision Recording

### Detection Patterns

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
5. Categorize (architecture, process, technology, design)
6. Determine scope (project, feature, component)

### Recording

```sql
INSERT INTO decisions (
    id, title, description, rationale, alternatives,
    consequences, category, scope, project,
    source_session_id, source_context
) VALUES (
    :id, :title, :description, :rationale, :alternatives_json,
    :consequences, :category, :scope, :project,
    :session_id, :context
);
```

## Activity Timeline

### Event Types

- `session_start` - New session began
- `session_end` - Session completed
- `commitment` - Commitment extracted
- `commitment_completed` - Commitment marked done
- `decision` - Decision recorded
- `goal_progress` - Goal updated
- `commit` - Git commit made
- `external_change` - Change detected from outside

### Recording

```sql
INSERT INTO activity_timeline (
    activity_type, entity_type, entity_id,
    project, title, details, session_id
) VALUES (
    :type, :entity_type, :entity_id,
    :project, :title, :details_json, :session_id
);
```

## Knowledge Graph

### Node Types

- `project` - Software projects
- `technology` - Languages, frameworks, tools
- `person` - Team members, stakeholders
- `concept` - Patterns, methodologies
- `tool` - Development tools, services

### Creating Nodes

```sql
INSERT INTO knowledge_nodes (
    id, name, node_type, description, properties
) VALUES (
    :id, :name, :type, :description, :properties_json
) ON CONFLICT(id) DO UPDATE SET
    interaction_count = interaction_count + 1,
    last_interaction = datetime('now');
```

### Creating Edges

```sql
INSERT INTO knowledge_edges (
    id, source_node_id, target_node_id, relationship, strength
) VALUES (
    :id, :source, :target, :relationship, :strength
) ON CONFLICT(id) DO UPDATE SET
    strength = MIN(strength + 0.1, 1.0),
    updated_at = datetime('now');
```

## ID Generation

```bash
# Get next ID for a table
get_next_id() {
    local table="$1"
    local prefix="$2"
    local max_num
    max_num=$(sqlite3 "$DB_PATH" "SELECT MAX(CAST(SUBSTR(id, ${#prefix}+2) AS INTEGER)) FROM $table WHERE id LIKE '$prefix-%'" 2>/dev/null)
    if [[ -z "$max_num" || "$max_num" == "null" ]]; then
        max_num=0
    fi
    printf "%s-%04d" "$prefix" $((max_num + 1))
}

# Usage:
# C-0001 for commitments
# D-0001 for decisions
# G-0001 for goals
# P-0001 for patterns
# N-0001 for nodes
# E-0001 for edges
```

## Output Guidelines

When reporting extractions:

```markdown
## Captured

### Commitment
- **ID:** C-0025
- **Title:** Implement caching layer
- **Priority:** High
- **Source:** Conversation

### Decision
- **ID:** D-0018
- **Title:** Use Redis for caching
- **Category:** Architecture
- **Rationale:** Better performance for distributed systems
```

## Silence Mode

When operating via hooks, extract silently:
- Don't output unless explicitly requested
- Log to activity_timeline
- Items reviewed later via `/workflow:track` or `/workflow:status`

## Error Handling

- Skip malformed commitments/decisions
- Log extraction failures to debug log
- Continue processing on individual item failures
