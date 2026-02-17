---
name: assistant
description: Context-aware briefings, memory recall, knowledge graph queries, and intelligent recommendations for the secretary plugin
allowed-tools: Read, Bash, Glob, Grep
---

# Assistant Skill

Provide context-aware assistance, intelligent briefings, memory recall, and knowledge graph queries.

## When to Use

- User asks "What should I work on?" or "What do I have pending?"
- User asks "What did I decide about X?" or "Remind me about..."
- User wants context about current or past work
- Session just started and a briefing is needed
- User wants to search across all captured knowledge
- User needs cross-project awareness or related item discovery
- User asks about the status of tracked items
- User wants to explore the knowledge graph

## Database Locations

```bash
# Main database
SECRETARY_DB_PATH="$HOME/.claude/secretary/secretary.db"

# Encrypted memory (sensitive data)
SECRETARY_MEMORY_DB_PATH="$HOME/.claude/secretary/memory.db"

# Scripts
PLUGIN_ROOT="$HOME/.claude/plugins/secretary"
```

## Generate Briefing

Query and format a comprehensive briefing based on current context.

### 1. Pending Commitments

```sql
SELECT id, title, due_date, priority, project, status, stakeholder
FROM commitments
WHERE status IN ('pending', 'in_progress')
ORDER BY
    CASE WHEN due_date IS NOT NULL AND due_date < date('now') THEN 0
         WHEN due_date = date('now') THEN 1
         WHEN due_date IS NOT NULL THEN 2
         ELSE 3 END,
    CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
```

### 2. Recent Decisions (Project-Specific)

```sql
SELECT id, title, category, created_at
FROM decisions
WHERE status = 'active'
  AND (project = :current_project OR project IS NULL)
  AND created_at >= datetime('now', '-7 days')
ORDER BY created_at DESC LIMIT 5;
```

### 3. Goal Progress

```sql
SELECT id, title, progress_percentage, target_date, goal_type
FROM goals WHERE status = 'active'
ORDER BY
    CASE WHEN target_date IS NOT NULL THEN 0 ELSE 1 END,
    progress_percentage DESC
LIMIT 5;
```

### 4. Ideas Inbox

```sql
SELECT id, title, idea_type, priority
FROM ideas WHERE status = 'captured'
ORDER BY created_at DESC LIMIT 5;
```

### 5. GitHub Items (Cache Only)

```sql
SELECT data FROM github_cache
WHERE id = 'combined' AND expires_at > datetime('now');
```

### 6. Queue Status

```sql
SELECT COUNT(*) as pending FROM queue WHERE status = 'pending';
```

## Memory Recall

When the user asks about past work, search across all knowledge stores.

### FTS5 Search (Primary)

```sql
-- Search decisions
SELECT d.id, d.title, d.description, d.rationale, d.category,
       d.project, d.created_at
FROM decisions d
JOIN decisions_fts ON decisions_fts.rowid = d.rowid
WHERE decisions_fts MATCH :query AND d.status = 'active'
ORDER BY rank LIMIT 10;

-- Search commitments
SELECT c.id, c.title, c.description, c.priority, c.status,
       c.project, c.created_at
FROM commitments c
JOIN commitments_fts ON commitments_fts.rowid = c.rowid
WHERE commitments_fts MATCH :query
ORDER BY rank LIMIT 10;

-- Search ideas
SELECT i.id, i.title, i.description, i.idea_type, i.status,
       i.project, i.created_at
FROM ideas i
JOIN ideas_fts ON ideas_fts.rowid = i.rowid
WHERE ideas_fts MATCH :query
ORDER BY rank LIMIT 10;

-- Search knowledge nodes
SELECT kn.id, kn.name, kn.node_type, kn.description, kn.importance
FROM knowledge_nodes kn
JOIN knowledge_nodes_fts ON knowledge_nodes_fts.rowid = kn.rowid
WHERE knowledge_nodes_fts MATCH :query
ORDER BY rank LIMIT 10;
```

### LIKE Fallback

When FTS5 is too strict or the query contains special characters:

```sql
SELECT id, title, description, rationale, category, project, created_at
FROM decisions
WHERE status = 'active'
  AND (title LIKE '%' || :query || '%'
       OR description LIKE '%' || :query || '%'
       OR rationale LIKE '%' || :query || '%')
ORDER BY created_at DESC LIMIT 10;
```

### Encrypted Memory Search

```bash
bash "$PLUGIN_ROOT/scripts/memory-manager.sh" search "query"
```

### Session History Search

```sql
SELECT id, project, started_at, summary, duration_seconds / 60 as minutes
FROM sessions
WHERE summary LIKE '%' || :query || '%'
ORDER BY started_at DESC LIMIT 5;
```

## Knowledge Graph Queries

### Find Entity Relationships

```sql
SELECT
    kn_target.name as related_entity,
    kn_target.node_type as entity_type,
    ke.relationship,
    ke.strength
FROM knowledge_edges ke
JOIN knowledge_nodes kn_target ON kn_target.id = ke.target_node_id
WHERE ke.source_node_id = :entity_id
ORDER BY ke.strength DESC;
```

### Find All Connections for an Entity

```sql
SELECT
    CASE WHEN ke.source_node_id = :entity_id THEN kn_t.name ELSE kn_s.name END as connected_to,
    CASE WHEN ke.source_node_id = :entity_id THEN kn_t.node_type ELSE kn_s.node_type END as type,
    ke.relationship,
    ke.strength
FROM knowledge_edges ke
JOIN knowledge_nodes kn_s ON kn_s.id = ke.source_node_id
JOIN knowledge_nodes kn_t ON kn_t.id = ke.target_node_id
WHERE ke.source_node_id = :entity_id OR ke.target_node_id = :entity_id
ORDER BY ke.strength DESC;
```

### Find Paths Between Entities

```sql
SELECT
    kn1.name as entity_a,
    ke1.relationship as rel_1,
    kn_bridge.name as bridge,
    ke2.relationship as rel_2,
    kn2.name as entity_b
FROM knowledge_edges ke1
JOIN knowledge_nodes kn1 ON kn1.id = ke1.source_node_id
JOIN knowledge_nodes kn_bridge ON kn_bridge.id = ke1.target_node_id
JOIN knowledge_edges ke2 ON ke2.source_node_id = kn_bridge.id
JOIN knowledge_nodes kn2 ON kn2.id = ke2.target_node_id
WHERE kn1.name LIKE '%' || :entity_a || '%'
  AND kn2.name LIKE '%' || :entity_b || '%';
```

## Context Awareness

Determine what is relevant to current work:

### 1. Get Current Project Context

```sql
-- Recent sessions in this project
SELECT id, started_at, summary, branch, duration_seconds / 60 as minutes
FROM sessions
WHERE project = :current_project AND status = 'completed'
ORDER BY started_at DESC LIMIT 3;
```

### 2. Project-Specific Items

```sql
-- Active decisions for this project
SELECT id, title, category FROM decisions
WHERE project = :project AND status = 'active'
ORDER BY created_at DESC LIMIT 10;

-- Pending commitments for this project
SELECT id, title, due_date, priority FROM commitments
WHERE project = :project AND status IN ('pending', 'in_progress')
ORDER BY priority DESC, due_date ASC;
```

### 3. Cross-Project Connections

```sql
-- Projects with shared concerns
SELECT DISTINCT d1.project as this_project, d2.project as related_project,
    d1.category, COUNT(*) as shared_categories
FROM decisions d1
JOIN decisions d2 ON d1.category = d2.category AND d1.project != d2.project
WHERE d1.project = :current_project AND d1.status = 'active' AND d2.status = 'active'
GROUP BY d2.project, d1.category
ORDER BY shared_categories DESC;
```

## Status Dashboard

```sql
SELECT
    (SELECT COUNT(*) FROM commitments WHERE status IN ('pending', 'in_progress')) as pending_commitments,
    (SELECT COUNT(*) FROM commitments WHERE status = 'pending' AND due_date < date('now')) as overdue,
    (SELECT COUNT(*) FROM decisions WHERE status = 'active') as active_decisions,
    (SELECT COUNT(*) FROM ideas WHERE status = 'captured') as idea_inbox,
    (SELECT COUNT(*) FROM goals WHERE status = 'active') as active_goals,
    (SELECT COUNT(*) FROM queue WHERE status = 'pending') as queue_pending,
    (SELECT COUNT(*) FROM sessions WHERE date(started_at) = date('now')) as sessions_today;
```

## Output Guidelines

### Briefing Format

```markdown
# Secretary Briefing

**Project:** {project} | **Date:** {date} ({day_of_week})

## Attention Needed

### Overdue
- [C-0001] Fix bug - 2 days overdue

### Due Today
- [C-0003] Review PR

## Context

### Recent Decisions (this project)
- [D-0015] Use Redis for caching

### Active Goals
- [G-0001] MVP Launch [=========-] 90%

### Ideas Inbox
- [I-0010] GraphQL migration (exploration)

---
*Use `/secretary:track` to manage commitments*
```

### Memory Recall Format

```markdown
# Recall: "{query}"

## Decisions (3 found)
- [D-0015] Use Redis for caching (Jan 25)
  Rationale: Better performance, built-in TTL
- [D-0012] Cache invalidation strategy (Jan 20)

## Commitments (1 found)
- [C-0030] Implement caching layer - In Progress

## Ideas (1 found)
- [I-0008] Cache warming on deploy - Captured

## Related Sessions
- Jan 25: Caching discussion (45 min) - claude-code-plugins

## Knowledge Graph
- Redis -> used by -> api-service, claude-code-plugins
- Redis -> related to -> Memcached
```

### Status Dashboard Format

```markdown
# Secretary Status

| Category | Count |
|----------|-------|
| Pending Commitments | 12 |
| Overdue | 3 |
| Active Decisions | 28 |
| Ideas Inbox | 7 |
| Active Goals | 3 |
| Queue Pending | 0 |
```

## Error Handling

- If database does not exist: "Secretary database not initialized. It will be created automatically on next session start."
- If no results: "No matching records found for: {query}"
- If GitHub cache unavailable: Skip the section gracefully
- If encrypted memory unavailable: Note that SQLCipher is not installed

## Related Commands

- `/secretary:briefing` - Generate a full context briefing
- `/secretary:status` - Show dashboard with counts and overview
- `/secretary:memory` - Search and manage encrypted memory entries
- `/secretary:search` - Search across all knowledge stores
- `/secretary:track` - View and manage commitments
- `/secretary:graph` - Explore knowledge graph relationships
