---
allowed-tools: Skill(taskmanager), Skill(taskmanager-memory), Bash, WebSearch, WebFetch, Read, Glob, Grep
description: Research a topic using web search and codebase analysis, storing findings as memories
argument-hint: "\"topic\" [--depth <light|medium|deep>] [--task <id>]"
---

# Research Command

You are implementing `taskmanager:research`.

## Purpose

Research a topic before task generation or expansion. Gathers context from web search and codebase analysis, then stores findings as memories that can be applied during task planning and execution.

## Arguments

- `$1` (required): Research topic or question (quoted string)
- `--depth <light|medium|deep>`: Research depth (default: `medium`)
  - `light`: Quick web search + basic codebase scan
  - `medium`: Multiple web searches + codebase analysis + pattern identification
  - `deep`: Comprehensive research with multiple sources, codebase deep-dive, and best practices analysis
- `--task <id>`: Associate research with a specific task (scoped memory)

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### 0. Initialize session

1. Generate a unique session ID: `sess-$(date +%Y%m%d%H%M%S)`.
2. Update state table:
   ```sql
   UPDATE state SET
       session_id = '<session-id>',
       last_update = datetime('now')
   WHERE id = 1;
   ```
3. Log to `activity.log`:
   ```
   <timestamp> [DECISION] [research] Started research: "<topic>"
   ```

### 1. Check for existing research

Before starting, check if similar research already exists:

```sql
SELECT m.id, m.title, m.body, m.importance, m.updated_at
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE m.status = 'active'
  AND m.kind IN ('architecture', 'decision', 'convention', 'process')
  AND memories_fts MATCH '<topic keywords>'
ORDER BY m.importance DESC, m.updated_at DESC
LIMIT 5;
```

If relevant existing research is found:
- Present it to the user.
- Ask: "Existing research found. Continue with new research or use existing?"
- Options: "Continue with new research", "Use existing", "Update existing"

### 2. Codebase analysis

Analyze the current codebase for context relevant to the topic:

1. **Find related files**: Use `Glob` and `Grep` to find files related to the research topic.
2. **Analyze patterns**: Look for existing implementations, conventions, or patterns.
3. **Identify dependencies**: Check package.json, composer.json, etc. for relevant libraries.
4. **Check existing tests**: Look for test patterns related to the topic.

### 3. Web research (based on depth)

#### Light depth:
- 1-2 web searches on the topic.
- Read top 2-3 results.
- Extract key findings.

#### Medium depth:
- 3-5 web searches with different angles.
- Read top 3-5 results per search.
- Cross-reference findings.
- Identify best practices and common patterns.

#### Deep depth:
- 5-10 web searches covering:
  - Core topic
  - Best practices
  - Common pitfalls
  - Performance considerations
  - Security implications
  - Alternative approaches
- Read and analyze 5-10 results.
- Compare multiple approaches.
- Identify trade-offs.
- Check for recent changes or deprecations.

### 4. Synthesize findings

Combine codebase analysis and web research into a structured report:

```markdown
## Research: <topic>

### Key Findings
1. Finding one...
2. Finding two...

### Recommended Approach
Description of the recommended approach based on research.

### Best Practices
- Practice one
- Practice two

### Codebase Context
- Existing patterns found: ...
- Dependencies available: ...
- Conventions to follow: ...

### Trade-offs
| Approach | Pros | Cons |
|----------|------|------|
| A | ... | ... |
| B | ... | ... |

### Sources
- [Source 1](url)
- [Source 2](url)
```

### 5. Store as memories

Create one or more memories from the research findings:

1. **Main research memory**:
   ```sql
   INSERT INTO memories (
       id, title, kind, why_important, body,
       source_type, source_name, source_via, auto_updatable,
       importance, confidence, status,
       scope, tags, links,
       created_at, updated_at
   ) VALUES (
       '<next-id>',
       'Research: <topic summary>',
       'architecture',  -- or 'decision', 'convention', 'process' as appropriate
       '<why this research matters>',
       '<full research report>',
       'agent', 'research-command', 'taskmanager:research', 1,
       <importance>, <confidence>, 'active',
       '<scope-json>',
       '<tags-json>',
       '<links-json>',
       datetime('now'), datetime('now')
   );
   ```

2. **If task-scoped** (`--task <id>`): Also add to task memory:
   ```sql
   UPDATE state SET
       task_memory = json_insert(
           task_memory,
           '$[#]',
           json_object(
               'content', '<research summary>',
               'addedAt', datetime('now'),
               'taskId', '<task-id>',
               'source', 'research'
           )
       ),
       last_update = datetime('now')
   WHERE id = 1;
   ```

3. **If specific decisions or constraints were identified**: Create separate memories for each:
   - Architectural decisions -> `kind = 'architecture'`
   - Coding conventions -> `kind = 'convention'`
   - Known pitfalls -> `kind = 'anti-pattern'`

### 6. Present to the user

Show:
- Summary of findings.
- Memories created (IDs and titles).
- Recommended next steps:
  - "Run `taskmanager:plan` to generate tasks based on this research"
  - "Run `taskmanager:plan --expand <id>` to expand a task using these findings"
  - "Run `taskmanager:update <id> --scope up` to adjust scope based on research"

### 7. Cleanup session

1. Log to `activity.log`:
   ```
   <timestamp> [DECISION] [research] Completed research: "<topic>". Created N memories.
   ```
2. Reset state table:
   ```sql
   UPDATE state SET
       session_id = NULL,
       last_update = datetime('now')
   WHERE id = 1;
   ```

---

## Logging

All logging goes to `.taskmanager/logs/activity.log`:

```
<timestamp> [ERROR] [research] <error message>
<timestamp> [DECISION] [research] <decision message>
```

Log these events:
- Research start and completion
- Memories created
- Key findings summary
- Errors (web search failures, database errors)

---

## Usage Examples

```bash
# Research a topic
taskmanager:research "Best practices for implementing JWT authentication in Laravel"

# Light research
taskmanager:research "Redis caching strategies" --depth light

# Deep research for a specific task
taskmanager:research "GraphQL vs REST API design" --depth deep --task 1.2
```

---

## Integration with Plan Command

The `taskmanager:plan` command supports a `--research` flag that runs research before task generation:

```bash
taskmanager:plan docs/prd.md --research
```

This is equivalent to:
1. Running `taskmanager:research` on key topics identified from the PRD.
2. Then running `taskmanager:plan` with research memories available.

---

## Related Commands

- `taskmanager:plan` - Generate tasks (can use `--research` flag)
- `taskmanager:plan --expand <id>` - Expand tasks using research context
- `taskmanager:memory` - Manage memories directly
- `taskmanager:update <id> --scope up|down` - Adjust scope based on research
