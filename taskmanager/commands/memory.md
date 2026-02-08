---
allowed-tools: Bash, AskUserQuestion
description: Manage project memories (constraints, decisions, conventions) - add, list, search, update, deprecate with FTS5 full-text search
argument-hint: "<action> [args]"
---

# Memory Command

You are implementing `taskmanager:memory`.

This command provides direct access to the project memory system using SQLite with FTS5 full-text search, allowing users to manage global memories outside of task execution.

## Database Path

```bash
DB=".taskmanager/taskmanager.db"
```

## Actions

### `add "description"` - Add a new global memory

Usage: `taskmanager:memory add "Always use TypeScript strict mode"`

1. Parse the description from `$2` onwards.
2. Use `AskUserQuestion` to gather additional details:
   - **Kind**: What type of memory is this?
     - Options: constraint, decision, bugfix, workaround, convention, architecture, process, integration, anti-pattern, other
   - **Importance**: How critical is this? (1-5)
     - Options: 1 (low), 2, 3 (medium), 4, 5 (critical)
   - **Domains**: What areas does this apply to?
     - Free text, comma-separated (e.g., "testing, architecture")
3. Generate the next memory ID:
   ```bash
   NEXT_ID=$(sqlite3 "$DB" "SELECT 'M-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) FROM memories;")
   ```
4. Insert the memory:
   ```bash
   sqlite3 "$DB" "
   INSERT INTO memories (
       id, title, kind, why_important, body,
       source_type, source_via, auto_updatable,
       importance, confidence, status, scope, tags
   ) VALUES (
       '$NEXT_ID',
       '$(echo "$TITLE" | sed "s/'/''/g")',
       '$KIND',
       '$(echo "$WHY_IMPORTANT" | sed "s/'/''/g")',
       '$(echo "$BODY" | sed "s/'/''/g")',
       'user',
       'memory command',
       0,
       $IMPORTANCE,
       0.9,
       'active',
       '{\"domains\": [$(echo "$DOMAINS" | sed 's/,/\",\"/g' | sed 's/^/\"/;s/$/\"/')]}',
       '[]'
   );
   "
   ```
5. Confirm creation: "Memory $NEXT_ID created successfully."

### `list [--active|--all|--deprecated]` - List memories

Usage:
- `/memory list` - List active memories (default)
- `/memory list --active` - List active memories
- `/memory list --all` - List all memories including deprecated
- `/memory list --deprecated` - List only deprecated memories

#### --active (default)

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Active Memories ==="
sqlite3 -box "$DB" "
SELECT
    id as ID,
    SUBSTR(title, 1, 35) as Title,
    kind as Kind,
    importance as Imp,
    use_count as Uses
FROM memories
WHERE status = 'active'
ORDER BY importance DESC, created_at DESC;
"
```

#### --all

```bash
DB=".taskmanager/taskmanager.db"

echo "=== All Memories ==="
sqlite3 -box "$DB" "
SELECT
    id as ID,
    SUBSTR(title, 1, 30) as Title,
    kind as Kind,
    status as Status,
    importance as Imp,
    use_count as Uses
FROM memories
ORDER BY
    CASE status WHEN 'active' THEN 0 WHEN 'deprecated' THEN 1 ELSE 2 END,
    importance DESC,
    created_at DESC;
"
```

#### --deprecated

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Deprecated Memories ==="
sqlite3 -box "$DB" "
SELECT
    id as ID,
    SUBSTR(title, 1, 30) as Title,
    kind as Kind,
    status as Status,
    superseded_by as 'Superseded By'
FROM memories
WHERE status IN ('deprecated', 'superseded')
ORDER BY updated_at DESC;
"
```

### `show <id>` - Show memory details

Usage: `/memory show M-0001`

```bash
DB=".taskmanager/taskmanager.db"
MEMORY_ID="$1"

# Check if memory exists
EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM memories WHERE id = '$MEMORY_ID';")
if [[ "$EXISTS" == "0" ]]; then
    echo "Error: Memory '$MEMORY_ID' not found. Use \`taskmanager:memory list\` to see available memories."
    exit 1
fi

# Display full details
sqlite3 -line "$DB" "
SELECT
    id as 'Memory',
    title as 'Title',
    kind as 'Kind',
    status as 'Status',
    importance || '/5' as 'Importance',
    ROUND(confidence, 2) as 'Confidence',
    why_important as 'Why Important',
    body as 'Body',
    scope as 'Scope',
    tags as 'Tags',
    source_type || COALESCE(' (' || source_name || ')', '') as 'Source',
    source_via as 'Via',
    use_count as 'Usage Count',
    last_used_at as 'Last Used',
    created_at as 'Created',
    updated_at as 'Updated',
    superseded_by as 'Superseded By',
    conflict_resolutions as 'Conflict History'
FROM memories
WHERE id = '$MEMORY_ID';
"
```

### `search "query"` - Full-text search using FTS5

Usage: `/memory search "testing"`

This uses SQLite FTS5 for efficient full-text search across title, body, and tags.

```bash
DB=".taskmanager/taskmanager.db"
SEARCH_TERM="$1"

echo "=== Searching for: $SEARCH_TERM ==="

# Use FTS5 MATCH for full-text search
sqlite3 -box "$DB" "
SELECT
    m.id as ID,
    SUBSTR(m.title, 1, 35) as Title,
    m.kind as Kind,
    m.importance as Imp,
    m.status as Status
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH '$SEARCH_TERM'
ORDER BY rank, m.importance DESC
LIMIT 20;
"

# Show count
COUNT=$(sqlite3 "$DB" "
SELECT COUNT(*) FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH '$SEARCH_TERM';
")
echo ""
echo "Found $COUNT matching memories."
```

**FTS5 Search Syntax:**
- Simple word: `testing` - matches any memory containing "testing"
- Phrase: `"unit testing"` - matches exact phrase
- AND: `testing AND laravel` - matches both terms
- OR: `testing OR specs` - matches either term
- NOT: `testing NOT unit` - matches testing but not unit
- Prefix: `test*` - matches test, testing, tests, etc.

### `update <id> "new description"` - Update memory content

Usage: `/memory update M-0001 "Always use Pest for tests, including feature and unit tests"`

1. Check if memory exists:
   ```bash
   DB=".taskmanager/taskmanager.db"
   EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM memories WHERE id = '$MEMORY_ID';")
   if [[ "$EXISTS" == "0" ]]; then
       echo "Error: Memory '$MEMORY_ID' not found."
       exit 1
   fi
   ```

2. Check ownership:
   ```bash
   SOURCE_TYPE=$(sqlite3 "$DB" "SELECT source_type FROM memories WHERE id = '$MEMORY_ID';")
   ```
   - If `source_type != 'user'`: Ask for confirmation since this is a system memory.

3. Use `AskUserQuestion` to confirm the update and ask if any other fields should change (kind, importance, etc.).

4. Update the memory:
   ```bash
   sqlite3 "$DB" "
   UPDATE memories SET
       body = '$(echo "$NEW_BODY" | sed "s/'/''/g")',
       updated_at = datetime('now')
   WHERE id = '$MEMORY_ID';
   "
   ```

5. Confirm the update: "Memory $MEMORY_ID updated successfully."

### `deprecate <id> [reason]` - Mark memory as deprecated

Usage:
- `/memory deprecate M-0001`
- `/memory deprecate M-0001 "No longer using Pest, switched to PHPUnit"`

1. Check if memory exists:
   ```bash
   DB=".taskmanager/taskmanager.db"
   EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM memories WHERE id = '$MEMORY_ID';")
   if [[ "$EXISTS" == "0" ]]; then
       echo "Error: Memory '$MEMORY_ID' not found."
       exit 1
   fi
   ```

2. If reason not provided, ask for reason using `AskUserQuestion`.

3. Update the memory:
   ```bash
   # Get current conflict_resolutions
   CURRENT_RESOLUTIONS=$(sqlite3 "$DB" "SELECT conflict_resolutions FROM memories WHERE id = '$MEMORY_ID';")

   # Build new resolution entry
   NEW_RESOLUTION="{\"timestamp\": \"$(date -Iseconds)\", \"resolution\": \"deprecated\", \"reason\": \"$REASON\"}"

   # Update memory
   sqlite3 "$DB" "
   UPDATE memories SET
       status = 'deprecated',
       conflict_resolutions = json_insert(
           conflict_resolutions,
           '\$[#]',
           json('$NEW_RESOLUTION')
       ),
       updated_at = datetime('now')
   WHERE id = '$MEMORY_ID';
   "
   ```

4. Confirm deprecation: "Memory $MEMORY_ID has been deprecated."

### `supersede <old-id> "new description"` - Supersede with new memory

Usage: `/memory supersede M-0001 "Use PHPUnit for all tests instead of Pest"`

1. Check if old memory exists:
   ```bash
   DB=".taskmanager/taskmanager.db"
   EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM memories WHERE id = '$OLD_ID';")
   if [[ "$EXISTS" == "0" ]]; then
       echo "Error: Memory '$OLD_ID' not found."
       exit 1
   fi
   ```

2. Get the old memory's fields to inherit:
   ```bash
   sqlite3 -json "$DB" "SELECT kind, importance, scope, tags FROM memories WHERE id = '$OLD_ID';" | ...
   ```

3. Generate next ID:
   ```bash
   NEW_ID=$(sqlite3 "$DB" "SELECT 'M-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) FROM memories;")
   ```

4. Create new memory inheriting from old:
   ```bash
   sqlite3 "$DB" "
   INSERT INTO memories (
       id, title, kind, why_important, body,
       source_type, source_via, auto_updatable,
       importance, confidence, status, scope, tags
   )
   SELECT
       '$NEW_ID',
       '$(echo "$NEW_TITLE" | sed "s/'/''/g")',
       kind,
       'Supersedes $OLD_ID',
       '$(echo "$NEW_BODY" | sed "s/'/''/g")',
       'user',
       'memory command (supersede)',
       0,
       importance,
       0.9,
       'active',
       scope,
       tags
   FROM memories WHERE id = '$OLD_ID';
   "
   ```

5. Update old memory:
   ```bash
   NEW_RESOLUTION="{\"timestamp\": \"$(date -Iseconds)\", \"resolution\": \"superseded\", \"reason\": \"Superseded by $NEW_ID\"}"

   sqlite3 "$DB" "
   UPDATE memories SET
       status = 'superseded',
       superseded_by = '$NEW_ID',
       conflict_resolutions = json_insert(
           conflict_resolutions,
           '\$[#]',
           json('$NEW_RESOLUTION')
       ),
       updated_at = datetime('now')
   WHERE id = '$OLD_ID';
   "
   ```

6. Confirm: "Memory $OLD_ID superseded by $NEW_ID."

### `conflicts` - Check all memories for conflicts

Usage: `/memory conflicts`

1. Get all active memories:
   ```bash
   DB=".taskmanager/taskmanager.db"

   echo "=== Checking Active Memories for Conflicts ==="

   # Get count of active memories
   COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM memories WHERE status = 'active';")
   echo "Checking $COUNT active memories..."
   echo ""
   ```

2. For each active memory, check for issues:
   ```bash
   # Get memories with file scope to check
   sqlite3 -json "$DB" "
   SELECT id, title, scope
   FROM memories
   WHERE status = 'active'
     AND json_extract(scope, '\$.files') IS NOT NULL;
   "
   ```

3. For each memory with file references, check if files still exist.

4. Display results:
   ```
   Conflicts found:

   [WARNING] M-0003: API validation rules
   - File not found: app/Services/OldValidator.php
   - Suggested action: Update scope or deprecate

   No conflicts: M-0001, M-0002, M-0004
   ```

5. For each conflict found, offer resolution options using `AskUserQuestion`.

### `get <id>` - Get specific memory (alias for show)

Same as `show` command.

```bash
DB=".taskmanager/taskmanager.db"
MEMORY_ID="$1"

sqlite3 -json "$DB" "SELECT * FROM memories WHERE id = '$MEMORY_ID';"
```

## Helper Queries

### Get memory statistics

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Memory Statistics ==="
sqlite3 -line "$DB" "
SELECT
    COUNT(*) as 'Total Memories',
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as 'Active',
    SUM(CASE WHEN status = 'deprecated' THEN 1 ELSE 0 END) as 'Deprecated',
    SUM(CASE WHEN status = 'superseded' THEN 1 ELSE 0 END) as 'Superseded',
    SUM(use_count) as 'Total Uses',
    ROUND(AVG(importance), 1) as 'Avg Importance'
FROM memories;
"
```

### Get memories by kind

```bash
DB=".taskmanager/taskmanager.db"

sqlite3 -box "$DB" "
SELECT kind, COUNT(*) as count
FROM memories
WHERE status = 'active'
GROUP BY kind
ORDER BY count DESC;
"
```

### Get most used memories

```bash
DB=".taskmanager/taskmanager.db"

sqlite3 -box "$DB" "
SELECT id, SUBSTR(title, 1, 30) as Title, use_count as Uses
FROM memories
WHERE status = 'active'
ORDER BY use_count DESC
LIMIT 10;
"
```

## Error Handling

- If memory ID not found: "Memory '<id>' not found. Use `taskmanager:memory list` to see available memories."
- If action not recognized: "Unknown action '<action>'. Available actions: add, list, show, search, update, deprecate, supersede, conflicts, get"
- If database doesn't exist: "Error: Taskmanager not initialized. Run `taskmanager:init` first."

Check database exists at start:
```bash
DB=".taskmanager/taskmanager.db"
if [[ ! -f "$DB" ]]; then
    echo "Error: Taskmanager not initialized. Run taskmanager:init first."
    exit 1
fi
```

## Logging

All logging goes to `.taskmanager/logs/activity.log`:

```
<timestamp> [ERROR] [memory] <error message>
<timestamp> [DECISION] [memory] <decision message>
```

Log these events:
- Memory creation (add)
- Memory updates
- Memory deprecation/supersession
- Conflict resolutions
- Errors (not found, parse/validation, FTS search errors)

## Notes

- All queries use SQLite FTS5 for efficient full-text search
- The `memories_fts` virtual table is automatically synced via triggers
- JSON fields (scope, tags, links, conflict_resolutions) use SQLite JSON functions
- Memory IDs follow the pattern M-NNNN (e.g., M-0001, M-0002)
- The `use_count` and `last_used_at` fields are updated by the memory skill during task execution
