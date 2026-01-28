---
name: workflow-assistant
description: Context-aware briefings, memory recall, and intelligent recommendations for workflow management
allowed-tools: Read, Bash, Glob, Grep
---

# Workflow Assistant Skill

Provide context-aware assistance, intelligent briefings, and memory recall for workflow management.

## When to Use

- User asks "What should I work on?"
- User asks "What do I have pending?"
- User asks "What did I decide about X?"
- User asks "Remind me about..."
- User wants context about current or past work
- Session just started and briefing is needed

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## Core Functions

### Generate Briefing

Query and format a comprehensive briefing:

1. **Pending Commitments**
```sql
SELECT id, title, due_date, priority, status
FROM commitments
WHERE status IN ('pending', 'in_progress')
ORDER BY
    CASE WHEN due_date < date('now') THEN 1
         WHEN due_date = date('now') THEN 2
         ELSE 3 END,
    CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END;
```

2. **Recent Decisions**
```sql
SELECT id, title, category, created_at
FROM decisions
WHERE status = 'active'
  AND (project = :project OR project IS NULL)
  AND created_at >= datetime('now', '-7 days')
ORDER BY created_at DESC LIMIT 5;
```

3. **Goal Progress**
```sql
SELECT id, title, progress_percentage, target_date
FROM goals
WHERE status = 'active'
ORDER BY progress_percentage DESC LIMIT 5;
```

4. **GitHub Items** (if enabled)
   - Check cache first
   - Refresh if expired
   - Include issues, PRs, reviews

### Memory Recall

When user asks about past work:

1. **Search decisions**
```sql
SELECT id, title, description, rationale, category, project, created_at
FROM decisions
WHERE status = 'active'
  AND (title LIKE '%' || :query || '%'
       OR description LIKE '%' || :query || '%'
       OR rationale LIKE '%' || :query || '%')
ORDER BY created_at DESC;
```

2. **Search knowledge graph**
```sql
SELECT * FROM knowledge_nodes_fts
WHERE knowledge_nodes_fts MATCH :query;
```

3. **Find related sessions**
```sql
SELECT id, project, started_at, summary
FROM sessions
WHERE summary LIKE '%' || :query || '%'
ORDER BY started_at DESC LIMIT 5;
```

### Context Awareness

Determine what's relevant to current work:

1. Get current project from working directory
2. Load project-specific decisions and commitments
3. Find related entities in knowledge graph
4. Surface cross-project connections

## Output Guidelines

### Briefing Format
```markdown
# Workflow Briefing

**Project:** {project}
**Time:** {datetime}

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

---
*Use `/workflow:track` to manage commitments*
```

### Memory Recall Format
```markdown
# Recall: "{query}"

## Decisions (3 found)
- [D-0015] Use Redis for caching (Jan 25)
- [D-0012] Cache invalidation strategy (Jan 20)

## Related Sessions
- Jan 25: Caching discussion (45 min)

## Knowledge Graph
- Redis → used by → api-service, claude-code-plugins
```

## Error Handling

- If database doesn't exist: "Run `/workflow:init` first"
- If no results: "No matching records found"
- If GitHub unavailable: Skip section gracefully

## Related Commands

- `/workflow:briefing` - Generate full briefing
- `/workflow:status` - Show dashboard
- `/workflow:track` - Manage commitments
