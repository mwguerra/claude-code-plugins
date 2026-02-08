#!/usr/bin/env bash
# Taskmanager SQL Query Tests
#
# Tests SQL queries from command .md files against the schema.
# Currently a reference script — not self-bootstrapping.
# To run: create a .taskmanager/taskmanager.db from schema.sql,
# insert sample data, then execute from the project root.
#
# Future: rebuild as self-contained (creates temp DB, runs, cleans up).

set -euo pipefail

DB=".taskmanager/taskmanager.db"
PASS=0
FAIL=0
ERRORS=""

# Change to test project directory
cd "$(dirname "$0")"

pass() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}\n  FAIL: $1"
    echo "  FAIL: $1"
}

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$msg"
    else
        fail "$msg (expected='$expected', got='$actual')"
    fi
}

assert_contains() {
    local actual="$1"
    local needle="$2"
    local msg="$3"
    if echo "$actual" | grep -qF "$needle"; then
        pass "$msg"
    else
        fail "$msg (output does not contain '$needle')"
    fi
}

assert_not_empty() {
    local actual="$1"
    local msg="$2"
    if [[ -n "$actual" ]]; then
        pass "$msg"
    else
        fail "$msg (output is empty)"
    fi
}

assert_gt() {
    local actual="$1"
    local threshold="$2"
    local msg="$3"
    if [[ "$actual" -gt "$threshold" ]]; then
        pass "$msg"
    else
        fail "$msg (expected > $threshold, got '$actual')"
    fi
}

echo "=============================================="
echo "  TASKMANAGER PLUGIN - COMPREHENSIVE TESTS"
echo "=============================================="
echo ""

# ====================================================================
# TEST 1: Schema / Init
# ====================================================================
echo "--- Test 1: Schema / Init ---"

# Check 6 tables exist
TABLE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('tasks','memories','memories_fts','state','sync_log','schema_version');")
assert_eq "$TABLE_COUNT" "6" "All 6 tables exist"

# Check schema version
VERSION=$(sqlite3 "$DB" "SELECT version FROM schema_version LIMIT 1;")
assert_eq "$VERSION" "2.0.0" "Schema version is 2.0.0"

# Check state row exists
STATE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM state WHERE id = 1;")
assert_eq "$STATE_COUNT" "1" "State singleton row exists"

# Check config.json exists
if [[ -f ".taskmanager/config.json" ]]; then
    pass "config.json exists"
else
    fail "config.json does not exist"
fi

# Check log files exist
for LOG in errors.log decisions.log debug.log; do
    if [[ -f ".taskmanager/logs/$LOG" ]]; then
        pass "$LOG exists"
    else
        fail "$LOG does not exist"
    fi
done

echo ""

# ====================================================================
# TEST 2: test_strategy column (P1 - new feature)
# ====================================================================
echo "--- Test 2: test_strategy column ---"

# Column exists
COL_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('tasks') WHERE name = 'test_strategy';")
assert_eq "$COL_EXISTS" "1" "test_strategy column exists in tasks table"

# Stores and retrieves correctly
STRATEGY=$(sqlite3 "$DB" "SELECT test_strategy FROM tasks WHERE id = '1.1';")
assert_contains "$STRATEGY" "valid/invalid credentials" "test_strategy stores content correctly"

# Can be updated
sqlite3 "$DB" "UPDATE tasks SET test_strategy = 'Updated test strategy' WHERE id = '1.1';"
UPDATED=$(sqlite3 "$DB" "SELECT test_strategy FROM tasks WHERE id = '1.1';")
assert_eq "$UPDATED" "Updated test strategy" "test_strategy can be updated"

# Restore original
sqlite3 "$DB" "UPDATE tasks SET test_strategy = 'Test valid/invalid credentials, token expiry' WHERE id = '1.1';"

echo ""

# ====================================================================
# TEST 3: Tags (P2 - new command)
# ====================================================================
echo "--- Test 3: Tags command queries ---"

# tags list query
TAG_LIST=$(sqlite3 "$DB" "
SELECT tag.value as Tag, COUNT(DISTINCT t.id) as TaskCount
FROM tasks t, json_each(t.tags) tag
WHERE t.archived_at IS NULL
GROUP BY tag.value
ORDER BY COUNT(DISTINCT t.id) DESC;
")
assert_not_empty "$TAG_LIST" "tags list returns results"
assert_contains "$TAG_LIST" "security" "tags list includes 'security'"
assert_contains "$TAG_LIST" "auth" "tags list includes 'auth'"

# tags add - add 'sprint-3' to task 2.1
EXISTS_BEFORE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks t, json_each(t.tags) tag WHERE t.id = '2.1' AND tag.value = 'sprint-3';")
assert_eq "$EXISTS_BEFORE" "0" "sprint-3 not on task 2.1 before add"

sqlite3 "$DB" "UPDATE tasks SET tags = json_insert(tags, '\$[#]', 'sprint-3'), updated_at = datetime('now') WHERE id = '2.1';"
EXISTS_AFTER=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks t, json_each(t.tags) tag WHERE t.id = '2.1' AND tag.value = 'sprint-3';")
assert_eq "$EXISTS_AFTER" "1" "sprint-3 added to task 2.1"

# tags remove - remove 'sprint-3' from task 2.1
sqlite3 "$DB" "
UPDATE tasks SET
    tags = (
        SELECT COALESCE(json_group_array(tag.value), '[]')
        FROM json_each(tags) tag
        WHERE tag.value != 'sprint-3'
    ),
    updated_at = datetime('now')
WHERE id = '2.1';
"
EXISTS_REMOVED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks t, json_each(t.tags) tag WHERE t.id = '2.1' AND tag.value = 'sprint-3';")
assert_eq "$EXISTS_REMOVED" "0" "sprint-3 removed from task 2.1"

# tags filter query
FILTERED=$(sqlite3 "$DB" "
SELECT t.id as ID, SUBSTR(t.title, 1, 40) as Title, t.status as Status
FROM tasks t, json_each(t.tags) tag
WHERE tag.value = 'security' AND t.archived_at IS NULL
ORDER BY t.id;
")
assert_not_empty "$FILTERED" "tags filter returns results for 'security'"

SECURITY_COUNT=$(sqlite3 "$DB" "
SELECT COUNT(DISTINCT t.id)
FROM tasks t, json_each(t.tags) tag
WHERE tag.value = 'security' AND t.archived_at IS NULL;
")
assert_gt "$SECURITY_COUNT" "3" "At least 4 tasks tagged 'security'"

# tags rename query - rename 'sprint-1' to 'sprint-1-done'
BEFORE_RENAME=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT t.id) FROM tasks t, json_each(t.tags) tag WHERE tag.value = 'sprint-1';")
sqlite3 "$DB" "
UPDATE tasks SET
    tags = (
        SELECT json_group_array(
            CASE WHEN tag.value = 'sprint-1' THEN 'sprint-1-done' ELSE tag.value END
        )
        FROM json_each(tags) tag
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.tags) tag
    WHERE tag.value = 'sprint-1'
);
"
AFTER_RENAME_OLD=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT t.id) FROM tasks t, json_each(t.tags) tag WHERE tag.value = 'sprint-1';")
AFTER_RENAME_NEW=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT t.id) FROM tasks t, json_each(t.tags) tag WHERE tag.value = 'sprint-1-done';")
assert_eq "$AFTER_RENAME_OLD" "0" "No tasks with old tag 'sprint-1' after rename"
assert_eq "$AFTER_RENAME_NEW" "$BEFORE_RENAME" "All tasks moved to 'sprint-1-done'"

# Restore: rename back
sqlite3 "$DB" "
UPDATE tasks SET
    tags = (
        SELECT json_group_array(
            CASE WHEN tag.value = 'sprint-1-done' THEN 'sprint-1' ELSE tag.value END
        )
        FROM json_each(tags) tag
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.tags) tag
    WHERE tag.value = 'sprint-1-done'
);
"

echo ""

# ====================================================================
# TEST 4: Dashboard tags query
# ====================================================================
echo "--- Test 4: Dashboard tag distribution ---"

DASH_TAGS=$(sqlite3 "$DB" "
SELECT
    tag.value as Tag,
    COUNT(DISTINCT t.id) as Tasks,
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) as Done,
    SUM(CASE WHEN t.status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining
FROM tasks t, json_each(t.tags) tag
WHERE t.archived_at IS NULL
GROUP BY tag.value
ORDER BY COUNT(DISTINCT t.id) DESC
LIMIT 10;
")
assert_not_empty "$DASH_TAGS" "Dashboard tag distribution returns data"
assert_contains "$DASH_TAGS" "security" "Dashboard tags include 'security'"

echo ""

# ====================================================================
# TEST 5: Stats --tags query
# ====================================================================
echo "--- Test 5: Stats --tags ---"

STATS_TAGS=$(sqlite3 "$DB" "
SELECT
    tag.value as Tag,
    COUNT(DISTINCT t.id) as Total,
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) as Done,
    SUM(CASE WHEN t.status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) / NULLIF(COUNT(DISTINCT t.id), 0), 1) || '%' as Complete
FROM tasks t, json_each(t.tags) tag
WHERE t.archived_at IS NULL
GROUP BY tag.value
ORDER BY COUNT(DISTINCT t.id) DESC;
")
assert_not_empty "$STATS_TAGS" "Stats --tags returns data"
assert_contains "$STATS_TAGS" "%" "Stats --tags includes completion percentages"

UNIQUE_TAGS=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT tag.value) FROM tasks t, json_each(t.tags) tag WHERE t.archived_at IS NULL;")
assert_gt "$UNIQUE_TAGS" "3" "More than 3 unique tags exist"

echo ""

# ====================================================================
# TEST 6: Scope (P3 - new command)
# ====================================================================
echo "--- Test 6: Scope command queries ---"

# Load task query
SCOPE_TASK=$(sqlite3 "$DB" "
SELECT id, title, description, details, test_strategy, priority, type,
       complexity_score, complexity_scale
FROM tasks
WHERE id = '1.2' AND archived_at IS NULL;
")
assert_not_empty "$SCOPE_TASK" "Scope: can load task 1.2"

# Update task fields (simulate scope up)
sqlite3 "$DB" "
UPDATE tasks SET
    description = 'Implement password reset via email with rate limiting',
    complexity_score = 3,
    complexity_scale = 'M',
    estimate_seconds = 7200,
    updated_at = datetime('now')
WHERE id = '1.2';
"
UPDATED_SCORE=$(sqlite3 "$DB" "SELECT complexity_score FROM tasks WHERE id = '1.2';")
assert_eq "$UPDATED_SCORE" "3" "Scope up: complexity increased to 3"

# Find dependent tasks (cascade query)
DEPENDENTS=$(sqlite3 "$DB" "
SELECT id, title, description
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND EXISTS (
      SELECT 1 FROM json_each(dependencies) d
      WHERE d.value = '1.1'
  );
")
assert_not_empty "$DEPENDENTS" "Scope: found tasks depending on 1.1"
assert_contains "$DEPENDENTS" "1.2" "Task 1.2 depends on 1.1"

# Recompute parent estimate
sqlite3 "$DB" "
UPDATE tasks SET
    estimate_seconds = (
        SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
        FROM tasks c WHERE c.parent_id = tasks.id
          AND c.status NOT IN ('canceled', 'duplicate')
    ),
    updated_at = datetime('now')
WHERE id = '1';
"
PARENT_EST=$(sqlite3 "$DB" "SELECT estimate_seconds FROM tasks WHERE id = '1';")
assert_gt "$PARENT_EST" "10000" "Parent estimate recomputed from children"

# Restore original values
sqlite3 "$DB" "UPDATE tasks SET description = 'Implement password reset via email', complexity_score = 2, complexity_scale = 'S', estimate_seconds = 3600 WHERE id = '1.2';"

echo ""

# ====================================================================
# TEST 7: Expand (P4 - new command)
# ====================================================================
echo "--- Test 7: Expand command queries ---"

# Find expandable tasks (bulk mode query)
EXPANDABLE=$(sqlite3 "$DB" "
SELECT id, title, complexity_score, complexity_scale
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND complexity_score >= 2
  AND NOT EXISTS (
      SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id
  )
ORDER BY complexity_score DESC, id;
")
assert_not_empty "$EXPANDABLE" "Expand: found expandable tasks"

# Insert a subtask (simulate expansion)
sqlite3 "$DB" "
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority,
                   complexity_score, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
VALUES ('2.1.1', '2.1', 'Line Chart Component', 'Build D3 line chart', 'SVG-based responsive line chart', 'Snapshot test', 'planned', 'feature', 'medium', 1, 'XS', 'Simple D3 component', 1800, '[\"dashboard\"]', '[]');
"
CHILD_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE parent_id = '2.1';")
assert_eq "$CHILD_COUNT" "1" "Expand: subtask inserted under 2.1"

# Update parent estimate (rollup)
sqlite3 "$DB" "
UPDATE tasks SET
    estimate_seconds = (
        SELECT COALESCE(SUM(COALESCE(estimate_seconds, 0)), 0)
        FROM tasks c WHERE c.parent_id = '2.1'
    ),
    updated_at = datetime('now')
WHERE id = '2.1';
"
PARENT_EST_21=$(sqlite3 "$DB" "SELECT estimate_seconds FROM tasks WHERE id = '2.1';")
assert_eq "$PARENT_EST_21" "1800" "Expand: parent estimate rolled up from children"

# Check recursive expansion candidates
RECURSIVE_CHECK=$(sqlite3 "$DB" "
SELECT id, title, complexity_score, complexity_scale
FROM tasks
WHERE parent_id = '2.1'
  AND complexity_score >= 2
  AND NOT EXISTS (
      SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id
  );
")
# Should be empty since we inserted XS task
if [[ -z "$RECURSIVE_CHECK" ]]; then
    pass "Expand: no recursive expansion needed (subtasks below threshold)"
else
    fail "Expand: unexpected recursive expansion candidates"
fi

# Clean up: remove the test subtask
sqlite3 "$DB" "DELETE FROM tasks WHERE id = '2.1.1';"
sqlite3 "$DB" "UPDATE tasks SET estimate_seconds = 3600 WHERE id = '2.1';"

echo ""

# ====================================================================
# TEST 8: Dependencies (P5 - new command)
# ====================================================================
echo "--- Test 8: Dependencies command queries ---"

# Missing references detection
# First, add a bad dependency
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"1.1\", \"99.99\"]' WHERE id = '1.2';"
MISSING=$(sqlite3 "$DB" "
SELECT t.id as task_id, d.value as missing_dep
FROM tasks t, json_each(t.dependencies) d
WHERE t.archived_at IS NULL
  AND d.value NOT IN (SELECT id FROM tasks);
")
assert_contains "$MISSING" "99.99" "Dependencies: detected missing reference 99.99"

# Self-reference detection
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"2.2\"]' WHERE id = '2.2';"
SELF_REF=$(sqlite3 "$DB" "
SELECT t.id as task_id
FROM tasks t, json_each(t.dependencies) d
WHERE d.value = t.id;
")
assert_contains "$SELF_REF" "2.2" "Dependencies: detected self-reference on 2.2"

# Circular dependency detection (simple case)
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"1.3\"]' WHERE id = '1.2';"
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"1.2\"]' WHERE id = '1.3';"
CIRCULAR=$(sqlite3 "$DB" "
WITH RECURSIVE dep_chain AS (
    SELECT
        t.id as start_id,
        d.value as current_id,
        t.id || ' -> ' || d.value as path,
        1 as depth
    FROM tasks t, json_each(t.dependencies) d
    WHERE t.archived_at IS NULL
    UNION ALL
    SELECT
        dc.start_id,
        d.value as current_id,
        dc.path || ' -> ' || d.value,
        dc.depth + 1
    FROM dep_chain dc
    JOIN tasks t ON t.id = dc.current_id
    JOIN json_each(t.dependencies) d
    WHERE dc.depth < 20
      AND d.value != dc.current_id
)
SELECT DISTINCT start_id, path || ' -> ' || start_id as cycle
FROM dep_chain
WHERE current_id = start_id
LIMIT 5;
")
assert_not_empty "$CIRCULAR" "Dependencies: detected circular dependency"

# Auto-fix: remove missing references
sqlite3 "$DB" "
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(dependencies) d
        WHERE d.value IN (SELECT id FROM tasks)
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.dependencies) d
    WHERE d.value NOT IN (SELECT id FROM tasks)
);
"
MISSING_AFTER=$(sqlite3 "$DB" "
SELECT COUNT(*)
FROM tasks t, json_each(t.dependencies) d
WHERE t.archived_at IS NULL AND d.value NOT IN (SELECT id FROM tasks);
")
assert_eq "$MISSING_AFTER" "0" "Dependencies fix: missing references removed"

# Auto-fix: remove self-references
# Note: must qualify 'tasks.id' to avoid ambiguity with json_each's 'id' column
sqlite3 "$DB" "
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(dependencies) d
        WHERE d.value != tasks.id
    ),
    updated_at = datetime('now')
WHERE id IN (
    SELECT t.id FROM tasks t, json_each(t.dependencies) d
    WHERE d.value = t.id
);
"
SELF_AFTER=$(sqlite3 "$DB" "
SELECT COUNT(*)
FROM tasks t, json_each(t.dependencies) d
WHERE d.value = t.id;
")
assert_eq "$SELF_AFTER" "0" "Dependencies fix: self-references removed"

# Add dependency query
sqlite3 "$DB" "
UPDATE tasks SET
    dependencies = json_insert(dependencies, '\$[#]', '1.1'),
    updated_at = datetime('now')
WHERE id = '1.2';
"
DEP_ADDED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks t, json_each(t.dependencies) d WHERE t.id = '1.2' AND d.value = '1.1';")
assert_eq "$DEP_ADDED" "1" "Dependencies: add dependency works"

# Remove dependency query
sqlite3 "$DB" "
UPDATE tasks SET
    dependencies = (
        SELECT COALESCE(json_group_array(d.value), '[]')
        FROM json_each(dependencies) d
        WHERE d.value != '1.3'
    ),
    updated_at = datetime('now')
WHERE id = '1.2';
"

# Restore original dependencies
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"1.1\"]' WHERE id = '1.2';"
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"1.1\"]' WHERE id = '1.3';"
sqlite3 "$DB" "UPDATE tasks SET dependencies = '[\"2.1\"]' WHERE id = '2.2';"

echo ""

# ====================================================================
# TEST 9: Move (P6 - new command)
# ====================================================================
echo "--- Test 9: Move command queries ---"

# Load task and siblings
TASK_INFO=$(sqlite3 "$DB" "SELECT id, parent_id, title, status FROM tasks WHERE id = '2.3' AND archived_at IS NULL;")
assert_not_empty "$TASK_INFO" "Move: can load task 2.3"

SIBLINGS=$(sqlite3 "$DB" "
SELECT id, title FROM tasks
WHERE parent_id = (SELECT parent_id FROM tasks WHERE id = '2.3')
  AND archived_at IS NULL
ORDER BY id;
")
assert_not_empty "$SIBLINGS" "Move: found siblings of 2.3"

# No-cycle check (moving under descendant)
CYCLE_CHECK=$(sqlite3 "$DB" "
WITH RECURSIVE descendants AS (
    SELECT id FROM tasks WHERE id = '1'
    UNION ALL
    SELECT t.id FROM tasks t JOIN descendants d ON t.parent_id = d.id
)
SELECT COUNT(*) FROM descendants WHERE id = '1.2';
")
assert_eq "$CYCLE_CHECK" "1" "Move: cycle check detects descendant correctly"

# Next available child number
NEXT_NUM=$(sqlite3 "$DB" "
SELECT COALESCE(
    MAX(CAST(SUBSTR(id, LENGTH('3') + 2) AS INTEGER)),
    0
) + 1 as next_num
FROM tasks
WHERE parent_id = '3';
")
assert_eq "$NEXT_NUM" "4" "Move: next child number under epic 3 is 4"

# Simulate reparent: move 2.3 under 3 as 3.4
sqlite3 "$DB" "
BEGIN TRANSACTION;
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority,
                   complexity_score, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
SELECT '3.4', '3', title, description, details, test_strategy, status, type, priority,
       complexity_score, complexity_scale, complexity_reasoning, estimate_seconds, tags,
       REPLACE(dependencies, '\"2.1\"', '\"2.1\"')
FROM tasks WHERE id = '2.3';
DELETE FROM tasks WHERE id = '2.3';
COMMIT;
"
MOVED_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE id = '3.4';")
OLD_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE id = '2.3';")
assert_eq "$MOVED_EXISTS" "1" "Move: task exists at new location 3.4"
assert_eq "$OLD_EXISTS" "0" "Move: task removed from old location 2.3"

# Restore: move it back
sqlite3 "$DB" "
BEGIN TRANSACTION;
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority,
                   complexity_score, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
SELECT '2.3', '2', title, description, details, test_strategy, status, type, priority,
       complexity_score, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies
FROM tasks WHERE id = '3.4';
DELETE FROM tasks WHERE id = '3.4';
COMMIT;
"

echo ""

# ====================================================================
# TEST 10: Research (P7 - new command)
# ====================================================================
echo "--- Test 10: Research command queries ---"

# Check existing research via FTS5
FTS_SEARCH=$(sqlite3 "$DB" "
SELECT m.id, m.title, m.body, m.importance
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE m.status = 'active'
  AND memories_fts MATCH 'testing'
ORDER BY m.importance DESC
LIMIT 5;
")
assert_not_empty "$FTS_SEARCH" "Research: FTS5 search for 'testing' returns results"
assert_contains "$FTS_SEARCH" "Pest" "Research: found Pest testing memory"

# Insert research memory
sqlite3 "$DB" "
INSERT INTO memories (
    id, title, kind, why_important, body,
    source_type, source_name, source_via, auto_updatable,
    importance, confidence, status,
    scope, tags, links
) VALUES (
    'M-0004',
    'Research: JWT Best Practices 2024',
    'architecture',
    'Informs authentication implementation',
    'JWT tokens should use RS256 algorithm. Access tokens: 15 min TTL. Refresh tokens: 7 day TTL with rotation.',
    'agent', 'research-command', 'taskmanager:research', 1,
    4, 0.85, 'active',
    '{\"domains\": [\"auth\", \"security\"]}',
    '[\"jwt\", \"auth\", \"research\"]',
    '[]'
);
"
RESEARCH_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM memories WHERE id = 'M-0004';")
assert_eq "$RESEARCH_EXISTS" "1" "Research: memory inserted successfully"

# FTS5 search for research
FTS_JWT=$(sqlite3 "$DB" "
SELECT m.id, m.title
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'JWT'
ORDER BY rank
LIMIT 5;
")
assert_contains "$FTS_JWT" "M-0004" "Research: FTS5 finds new research memory"

# Scope search (within research memory scope)
SCOPE_SEARCH=$(sqlite3 "$DB" "
SELECT id, title FROM memories
WHERE status = 'active'
  AND json_extract(scope, '\$.domains') LIKE '%auth%';
")
assert_not_empty "$SCOPE_SEARCH" "Research: scope search for 'auth' domain works"

# Clean up
sqlite3 "$DB" "DELETE FROM memories WHERE id = 'M-0004';"

echo ""

# ====================================================================
# TEST 11: Config (P8)
# ====================================================================
echo "--- Test 11: Config validation ---"

# Valid JSON
if python3 -c "import json; json.load(open('.taskmanager/config.json'))" 2>/dev/null; then
    pass "Config: valid JSON"
else
    fail "Config: invalid JSON"
fi

# Check expected keys
CONFIG_KEYS=$(python3 -c "
import json
c = json.load(open('.taskmanager/config.json'))
keys = sorted(c.keys())
print(','.join(keys))
")
assert_contains "$CONFIG_KEYS" "version" "Config: has 'version' key"
assert_contains "$CONFIG_KEYS" "defaults" "Config: has 'defaults' key"
assert_contains "$CONFIG_KEYS" "dashboard" "Config: has 'dashboard' key"
assert_contains "$CONFIG_KEYS" "execution" "Config: has 'execution' key"
assert_contains "$CONFIG_KEYS" "planning" "Config: has 'planning' key"
assert_contains "$CONFIG_KEYS" "tags" "Config: has 'tags' key"

echo ""

# ====================================================================
# TEST 12: Update-task (P9 - new command)
# ====================================================================
echo "--- Test 12: Update-task command queries ---"

# Direct field update
sqlite3 "$DB" "
UPDATE tasks SET
    title = 'JWT Login/Logout Endpoints',
    priority = 'critical',
    updated_at = datetime('now')
WHERE id = '1.1';
"
UPDATED_TITLE=$(sqlite3 "$DB" "SELECT title FROM tasks WHERE id = '1.1';")
assert_eq "$UPDATED_TITLE" "JWT Login/Logout Endpoints" "Update-task: title updated"

UPDATED_PRIO=$(sqlite3 "$DB" "SELECT priority FROM tasks WHERE id = '1.1';")
assert_eq "$UPDATED_PRIO" "critical" "Update-task: priority updated"

# Cascade dependent query
CASCADE=$(sqlite3 "$DB" "
WITH RECURSIVE dep_chain AS (
    SELECT t.id, t.title, t.description, t.dependencies, 1 as depth
    FROM tasks t
    WHERE t.archived_at IS NULL
      AND t.status NOT IN ('done', 'canceled', 'duplicate')
      AND EXISTS (
          SELECT 1 FROM json_each(t.dependencies) d
          WHERE d.value = '1.1'
      )
    UNION ALL
    SELECT t.id, t.title, t.description, t.dependencies, dc.depth + 1
    FROM tasks t
    JOIN dep_chain dc ON EXISTS (
        SELECT 1 FROM json_each(t.dependencies) d
        WHERE d.value = dc.id
    )
    WHERE t.archived_at IS NULL
      AND t.status NOT IN ('done', 'canceled', 'duplicate')
      AND dc.depth < 5
)
SELECT DISTINCT id, depth FROM dep_chain ORDER BY depth, id;
")
assert_not_empty "$CASCADE" "Update-task: cascade finds dependent tasks"
assert_contains "$CASCADE" "1.2" "Update-task: cascade includes task 1.2"
assert_contains "$CASCADE" "1.3" "Update-task: cascade includes task 1.3"

# Restore original values
sqlite3 "$DB" "UPDATE tasks SET title = 'JWT Login/Logout', priority = 'high' WHERE id = '1.1';"

echo ""

# ====================================================================
# TEST 13: Export --files (P10 - new command)
# ====================================================================
echo "--- Test 13: Export --files query ---"

EXPORT_DATA=$(sqlite3 "$DB" "
SELECT id, parent_id, title, description, details, test_strategy,
       status, type, priority,
       complexity_score, complexity_scale,
       estimate_seconds,
       tags, dependencies
FROM tasks
WHERE archived_at IS NULL
ORDER BY id;
")
assert_not_empty "$EXPORT_DATA" "Export: query returns all active tasks"

EXPORT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL;")
assert_eq "$EXPORT_COUNT" "15" "Export: correct number of active tasks"

# Check export format for markdown (verify subtask listing)
SUBTASKS_OF_1=$(sqlite3 "$DB" "
SELECT id, title, status FROM tasks
WHERE parent_id = '1' AND archived_at IS NULL
ORDER BY id;
")
assert_not_empty "$SUBTASKS_OF_1" "Export: can list subtasks of epic 1"

echo ""

# ====================================================================
# TEST 14: Regression - stats --json
# ====================================================================
echo "--- Test 14: Stats --json ---"

JSON_OUTPUT=$(sqlite3 "$DB" "
SELECT json_object(
    'total', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL),
    'done', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'done'),
    'in_progress', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'in-progress'),
    'blocked', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status = 'blocked'),
    'remaining', (SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL AND status NOT IN ('done', 'canceled', 'duplicate')),
    'by_status', (
        SELECT json_group_object(status, cnt)
        FROM (SELECT status, COUNT(*) as cnt FROM tasks WHERE archived_at IS NULL GROUP BY status)
    ),
    'by_priority', (
        SELECT json_group_object(priority, cnt)
        FROM (SELECT priority, COUNT(*) as cnt FROM tasks WHERE archived_at IS NULL GROUP BY priority)
    ),
    'estimated_remaining_seconds', (
        SELECT COALESCE(SUM(estimate_seconds), 0)
        FROM tasks
        WHERE archived_at IS NULL
          AND status NOT IN ('done', 'canceled', 'duplicate')
          AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id)
    )
);
")
assert_not_empty "$JSON_OUTPUT" "Stats --json: returns output"

# Validate it's valid JSON
if echo "$JSON_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    pass "Stats --json: output is valid JSON"
else
    fail "Stats --json: output is NOT valid JSON"
fi

# Check key values
TOTAL=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])")
assert_eq "$TOTAL" "15" "Stats --json: total tasks = 15"

DONE=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['done'])")
assert_eq "$DONE" "1" "Stats --json: done tasks = 1"

BLOCKED=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['blocked'])")
assert_eq "$BLOCKED" "1" "Stats --json: blocked tasks = 1"

echo ""

# ====================================================================
# TEST 15: Regression - next-task
# ====================================================================
echo "--- Test 15: Next-task ---"

NEXT_TASK=$(sqlite3 "$DB" "
WITH done_ids AS (
    SELECT id FROM tasks
    WHERE status IN ('done', 'canceled', 'duplicate')
)
SELECT t.id, t.title, t.priority, t.complexity_score
FROM tasks t
WHERE t.archived_at IS NULL
  AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
  AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
  AND (
      t.dependencies = '[]'
      OR NOT EXISTS (
          SELECT 1 FROM json_each(t.dependencies) d
          WHERE d.value NOT IN (SELECT id FROM done_ids)
      )
  )
ORDER BY
    CASE t.priority
        WHEN 'critical' THEN 0
        WHEN 'high' THEN 1
        WHEN 'medium' THEN 2
        ELSE 3
    END,
    COALESCE(t.complexity_score, 3),
    t.id
LIMIT 1;
")
assert_not_empty "$NEXT_TASK" "Next-task: found a next task"

# The next task should be a leaf with no unmet deps, highest priority first
# Task 3.1 is critical priority, leaf, deps=[] -> should be first
NEXT_ID=$(echo "$NEXT_TASK" | cut -d'|' -f1)
assert_eq "$NEXT_ID" "3.1" "Next-task: recommends task 3.1 (critical priority, no deps)"

echo ""

# ====================================================================
# TEST 16: Regression - status propagation
# ====================================================================
echo "--- Test 16: Status propagation ---"

# Mark 1.3.1 as in-progress, propagate to ancestors
sqlite3 "$DB" "
UPDATE tasks SET status = 'in-progress', started_at = datetime('now'), updated_at = datetime('now')
WHERE id = '1.3.1';
"

# Propagate to ancestors using recursive CTE
sqlite3 "$DB" "
WITH RECURSIVE ancestors AS (
    SELECT parent_id as id
    FROM tasks
    WHERE id = '1.3.1' AND parent_id IS NOT NULL
    UNION ALL
    SELECT t.parent_id
    FROM tasks t
    JOIN ancestors a ON t.id = a.id
    WHERE t.parent_id IS NOT NULL
)
UPDATE tasks SET
    status = 'in-progress',
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors);
"

STATUS_13=$(sqlite3 "$DB" "SELECT status FROM tasks WHERE id = '1.3';")
assert_eq "$STATUS_13" "in-progress" "Propagation: parent 1.3 became in-progress"

STATUS_1=$(sqlite3 "$DB" "SELECT status FROM tasks WHERE id = '1';")
assert_eq "$STATUS_1" "in-progress" "Propagation: grandparent 1 became in-progress"

# Now mark 1.3.1 done and propagate properly
sqlite3 "$DB" "
UPDATE tasks SET status = 'done', completed_at = datetime('now'), updated_at = datetime('now')
WHERE id = '1.3.1';
"

# Propagate with proper status calculation
sqlite3 "$DB" "
WITH RECURSIVE ancestors AS (
    SELECT parent_id as id
    FROM tasks
    WHERE id = '1.3.1' AND parent_id IS NOT NULL
    UNION ALL
    SELECT t.parent_id
    FROM tasks t
    JOIN ancestors a ON t.id = a.id
    WHERE t.parent_id IS NOT NULL
)
UPDATE tasks SET
    status = (
        SELECT CASE
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress')
                THEN 'in-progress'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked')
                THEN 'blocked'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review')
                THEN 'needs-review'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned', 'draft', 'paused'))
                THEN 'planned'
            WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done')
                THEN 'done'
            ELSE 'canceled'
        END
    ),
    updated_at = datetime('now')
WHERE id IN (SELECT id FROM ancestors);
"

STATUS_13_AFTER=$(sqlite3 "$DB" "SELECT status FROM tasks WHERE id = '1.3';")
assert_eq "$STATUS_13_AFTER" "planned" "Propagation: parent 1.3 back to planned (other children still planned)"

# Restore original statuses
sqlite3 "$DB" "UPDATE tasks SET status = 'planned', started_at = NULL, completed_at = NULL WHERE id = '1.3.1';"
sqlite3 "$DB" "UPDATE tasks SET status = 'planned' WHERE id = '1.3';"
sqlite3 "$DB" "UPDATE tasks SET status = 'in-progress' WHERE id = '1';"

echo ""

# ====================================================================
# TEST 17: Regression - archive cascade
# ====================================================================
echo "--- Test 17: Archive cascade ---"

# Archive task 1.1 (done task)
sqlite3 "$DB" "
UPDATE tasks SET
    archived_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = '1.1';
"
ARCHIVED=$(sqlite3 "$DB" "SELECT archived_at IS NOT NULL FROM tasks WHERE id = '1.1';")
assert_eq "$ARCHIVED" "1" "Archive: task 1.1 archived"

# Check parent NOT archived (other children still active)
PARENT_ARCHIVED=$(sqlite3 "$DB" "SELECT archived_at IS NULL FROM tasks WHERE id = '1';")
assert_eq "$PARENT_ARCHIVED" "1" "Archive: parent 1 NOT archived (has active children)"

# Cascade archive check query
SHOULD_ARCHIVE_PARENT=$(sqlite3 "$DB" "
SELECT NOT EXISTS (
    SELECT 1 FROM tasks c
    WHERE c.parent_id = '1'
      AND c.archived_at IS NULL
);
")
assert_eq "$SHOULD_ARCHIVE_PARENT" "0" "Archive: parent correctly not eligible (has unarchived children)"

# Restore
sqlite3 "$DB" "UPDATE tasks SET archived_at = NULL WHERE id = '1.1';"

echo ""

# ====================================================================
# TEST 18: Regression - Memory FTS5
# ====================================================================
echo "--- Test 18: Memory FTS5 search ---"

# Simple term search
FTS_RESULT=$(sqlite3 "$DB" "
SELECT m.id, m.title
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'Redis'
ORDER BY rank;
")
assert_not_empty "$FTS_RESULT" "FTS5: simple term 'Redis' returns results"
assert_contains "$FTS_RESULT" "M-0002" "FTS5: found Redis memory M-0002"

# Prefix search
FTS_PREFIX=$(sqlite3 "$DB" "
SELECT m.id, m.title
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'test*'
ORDER BY rank;
")
assert_not_empty "$FTS_PREFIX" "FTS5: prefix search 'test*' returns results"
assert_contains "$FTS_PREFIX" "M-0001" "FTS5: prefix search finds M-0001 (testing)"

# Search for a term that should match body text
FTS_BODY=$(sqlite3 "$DB" "
SELECT m.id
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'token bucket';
")
assert_not_empty "$FTS_BODY" "FTS5: body search 'token bucket' returns results"

# Search for tags
FTS_TAG=$(sqlite3 "$DB" "
SELECT m.id
FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'bugfix';
")
assert_not_empty "$FTS_TAG" "FTS5: tag search 'bugfix' returns results"
assert_contains "$FTS_TAG" "M-0003" "FTS5: tag search finds M-0003"

# Verify FTS sync triggers work: insert new memory, search, delete
sqlite3 "$DB" "
INSERT INTO memories (id, title, kind, why_important, body, source_type, importance, confidence, status, scope, tags, links)
VALUES ('M-9999', 'Temporary test memory', 'convention', 'Testing FTS sync', 'Unique keyword xyzzy123 for testing', 'user', 1, 0.5, 'active', '{}', '[]', '[]');
"
FTS_SYNC=$(sqlite3 "$DB" "
SELECT m.id FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'xyzzy123';
")
assert_contains "$FTS_SYNC" "M-9999" "FTS5: sync trigger works for INSERT"

sqlite3 "$DB" "DELETE FROM memories WHERE id = 'M-9999';"
FTS_AFTER_DEL=$(sqlite3 "$DB" "
SELECT COUNT(*) FROM memories m
JOIN memories_fts fts ON m.rowid = fts.rowid
WHERE memories_fts MATCH 'xyzzy123';
")
assert_eq "$FTS_AFTER_DEL" "0" "FTS5: sync trigger works for DELETE"

echo ""

# ====================================================================
# SUMMARY
# ====================================================================
echo "=============================================="
echo "  TEST RESULTS"
echo "=============================================="
echo ""
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
echo "  TOTAL:  $((PASS + FAIL))"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "  FAILURES:"
    echo -e "$ERRORS"
    echo ""
    exit 1
else
    echo "  ALL TESTS PASSED!"
    echo ""
    exit 0
fi
