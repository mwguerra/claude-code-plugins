---
name: knowledge-graph
description: Manage the knowledge graph of entities and relationships across projects
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Knowledge Graph Skill

Manage entities (projects, technologies, people, concepts) and their relationships.

## When to Use

- Adding new entities to the graph
- Finding relationships between entities
- Querying cross-project connections
- Building context from past work
- Discovering related concepts

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## Entity Types

### Projects
```json
{
  "node_type": "project",
  "properties": {
    "repo_url": "https://github.com/...",
    "language": "TypeScript",
    "framework": "React",
    "status": "active"
  }
}
```

### Technologies
```json
{
  "node_type": "technology",
  "properties": {
    "category": "database",
    "version": "7.0",
    "documentation": "https://..."
  }
}
```

### People
```json
{
  "node_type": "person",
  "properties": {
    "role": "developer",
    "team": "backend",
    "email": "..."
  }
}
```

### Concepts
```json
{
  "node_type": "concept",
  "properties": {
    "category": "architecture",
    "related_patterns": ["microservices", "event-driven"]
  }
}
```

### Tools
```json
{
  "node_type": "tool",
  "properties": {
    "category": "development",
    "platform": "cli"
  }
}
```

## Relationship Types

- `uses` - Project uses technology
- `knows` - Person knows technology/concept
- `owns` - Person owns/maintains project
- `depends_on` - Project depends on another
- `related_to` - General relationship
- `implements` - Project implements concept
- `part_of` - Component is part of larger system

## Creating Nodes

```sql
INSERT INTO knowledge_nodes (
    id, name, node_type, description, properties, aliases
) VALUES (
    :id, :name, :type, :description, :properties_json, :aliases_json
) ON CONFLICT(id) DO UPDATE SET
    description = COALESCE(:description, description),
    properties = COALESCE(:properties_json, properties),
    interaction_count = interaction_count + 1,
    last_interaction = datetime('now'),
    updated_at = datetime('now');
```

## Creating Edges

```sql
INSERT INTO knowledge_edges (
    id, source_node_id, target_node_id, relationship, strength, properties
) VALUES (
    :id, :source, :target, :relationship, :strength, :properties_json
) ON CONFLICT(id) DO UPDATE SET
    strength = MIN(strength + 0.1, 1.0),
    updated_at = datetime('now');
```

## Querying the Graph

### Find Node by Name
```sql
SELECT * FROM knowledge_nodes
WHERE name = :name OR :name IN (SELECT value FROM json_each(aliases));
```

### Full-Text Search
```sql
SELECT n.* FROM knowledge_nodes n
WHERE n.id IN (
    SELECT rowid FROM knowledge_nodes_fts
    WHERE knowledge_nodes_fts MATCH :query
);
```

### Find Relationships
```sql
-- Outgoing relationships
SELECT
    e.relationship,
    n.name as target_name,
    n.node_type as target_type,
    e.strength
FROM knowledge_edges e
JOIN knowledge_nodes n ON n.id = e.target_node_id
WHERE e.source_node_id = :node_id
ORDER BY e.strength DESC;

-- Incoming relationships
SELECT
    e.relationship,
    n.name as source_name,
    n.node_type as source_type,
    e.strength
FROM knowledge_edges e
JOIN knowledge_nodes n ON n.id = e.source_node_id
WHERE e.target_node_id = :node_id
ORDER BY e.strength DESC;
```

### Find Path Between Nodes
```sql
-- Simple 2-hop path
WITH path AS (
    SELECT
        e1.source_node_id as start,
        e1.target_node_id as mid,
        e2.target_node_id as end,
        e1.relationship as rel1,
        e2.relationship as rel2
    FROM knowledge_edges e1
    JOIN knowledge_edges e2 ON e1.target_node_id = e2.source_node_id
    WHERE e1.source_node_id = :start_node
      AND e2.target_node_id = :end_node
)
SELECT * FROM path;
```

### Related Projects
```sql
-- Projects using same technologies
SELECT DISTINCT
    p.name as project,
    GROUP_CONCAT(t.name) as shared_technologies
FROM knowledge_nodes p
JOIN knowledge_edges e1 ON e1.source_node_id = p.id
JOIN knowledge_nodes t ON t.id = e1.target_node_id
JOIN knowledge_edges e2 ON e2.target_node_id = t.id
WHERE p.node_type = 'project'
  AND t.node_type = 'technology'
  AND e1.relationship = 'uses'
  AND e2.relationship = 'uses'
  AND e2.source_node_id = :project_id
  AND p.id != :project_id
GROUP BY p.id
ORDER BY COUNT(*) DESC;
```

## Automatic Entity Extraction

When processing sessions/decisions, extract entities:

1. **Technology mentions**
   - Look for framework/library names
   - Programming languages
   - Tools and services

2. **Project references**
   - Repository names
   - Package names
   - Service names

3. **People mentions**
   - Names in context
   - GitHub usernames
   - Team references

## Strength Calculation

Edge strength increases with:
- Direct mentions in decisions
- Repeated associations
- Explicit confirmations

```python
# Strength update formula
new_strength = min(current_strength + 0.1, 1.0)
```

Decay over time (optional):
```sql
-- Decay unused relationships
UPDATE knowledge_edges
SET strength = strength * 0.95
WHERE updated_at < datetime('now', '-30 days');
```

## Output Guidelines

### Entity View
```markdown
## Redis

**Type:** Technology
**Category:** Database (In-memory)

### Used By
- claude-code-plugins (0.9 strength)
- api-service (0.8 strength)

### Related Technologies
- PostgreSQL (related_to)
- Node.js (related_to)

### Recent Decisions
- [D-0015] Use Redis for caching
```

### Graph View
```
claude-code-plugins
├── uses → TypeScript (0.9)
├── uses → SQLite (0.8)
├── uses → Redis (planned)
└── depends_on → api-service (0.7)

api-service
├── uses → TypeScript (0.9)
├── uses → Redis (0.8)
└── uses → PostgreSQL (0.9)
```

### Search Results
```markdown
# Search: "caching"

## Technologies
- Redis - In-memory data store
- Memcached - Distributed memory caching

## Decisions
- [D-0015] Use Redis for caching
- [D-0012] Cache invalidation strategy

## Projects Using Caching
- api-service
- claude-code-plugins (planned)
```

## Maintenance

### Merge Duplicates
```sql
-- Redirect edges to canonical node
UPDATE knowledge_edges
SET target_node_id = :canonical_id
WHERE target_node_id = :duplicate_id;

UPDATE knowledge_edges
SET source_node_id = :canonical_id
WHERE source_node_id = :duplicate_id;

-- Delete duplicate
DELETE FROM knowledge_nodes WHERE id = :duplicate_id;
```

### Clean Orphans
```sql
-- Find nodes with no edges
SELECT n.* FROM knowledge_nodes n
WHERE NOT EXISTS (
    SELECT 1 FROM knowledge_edges e
    WHERE e.source_node_id = n.id OR e.target_node_id = n.id
);
```
