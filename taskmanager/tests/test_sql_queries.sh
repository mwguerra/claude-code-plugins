#!/usr/bin/env bash
# Taskmanager SQL Query Tests
#
# Self-contained test script: creates a temp directory with DB + config,
# runs all SQL query tests, then cleans up automatically.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEMA_FILE="$PLUGIN_DIR/schemas/schema.sql"
CONFIG_SRC="$PLUGIN_DIR/schemas/default-config.json"

# Create temp working directory with .taskmanager structure
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/.taskmanager/logs"
cp "$CONFIG_SRC" "$WORK_DIR/.taskmanager/config.json"
touch "$WORK_DIR/.taskmanager/logs/activity.log"

DB="$WORK_DIR/.taskmanager/taskmanager.db"

# Initialize database from schema
sqlite3 "$DB" < "$SCHEMA_FILE"

# Insert sample data: 3 epics, ~15 tasks, 3 memories
sqlite3 "$DB" <<'SEED'
-- Epic 1: Authentication (in-progress, high priority)
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
VALUES
('1', NULL, 'Authentication System', 'Build full auth system', 'JWT-based auth with login, register, reset', NULL, 'in-progress', 'feature', 'high', 'L', 'Multi-endpoint system', 14400, '["auth","security","sprint-1"]', '[]'),
('1.1', '1', 'JWT Login/Logout', 'Implement JWT endpoints', 'POST /login, POST /logout', 'Test valid/invalid credentials, token expiry', 'done', 'feature', 'high', 'S', 'Standard JWT', 3600, '["auth","security"]', '[]'),
('1.2', '1', 'Password Reset', 'Implement password reset via email', 'POST /reset-request, POST /reset-confirm', 'Test email sending, token validation', 'planned', 'feature', 'medium', 'S', 'Email integration', 3600, '["auth","security"]', '["1.1"]'),
('1.3', '1', 'Role-Based Access Control', 'Implement RBAC', 'Admin, User, Guest roles', 'Test role enforcement on endpoints', 'planned', 'feature', 'medium', 'M', 'Complex permissions', 7200, '["auth","security","rbac"]', '["1.1"]'),
('1.3.1', '1.3', 'RBAC Middleware', 'Express middleware for role checks', NULL, 'Test middleware with each role', 'planned', 'feature', 'medium', 'S', 'Standard middleware', 1800, '["auth","security"]', '[]'),
('1.3.2', '1.3', 'RBAC Admin Panel', 'Admin UI for managing roles', NULL, 'Test role CRUD operations', 'planned', 'feature', 'medium', 'S', 'CRUD UI', 3600, '["auth","admin"]', '["1.3.1"]');

-- Epic 2: Dashboard (planned)
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
VALUES
('2', NULL, 'Dashboard', 'Build analytics dashboard', 'Charts, stats, data viz', NULL, 'planned', 'feature', 'medium', 'L', 'Complex frontend', 14400, '["dashboard","frontend","sprint-1"]', '[]'),
('2.1', '2', 'Chart Components', 'Build D3 chart library', 'Line, bar, pie charts', 'Visual regression tests', 'planned', 'feature', 'medium', 'M', 'D3 integration', 3600, '["dashboard","frontend"]', '[]'),
('2.2', '2', 'Data Aggregation API', 'Backend for dashboard data', 'Aggregate queries, caching', 'Test with sample datasets', 'planned', 'feature', 'medium', 'S', 'SQL aggregates', 3600, '["dashboard","api"]', '["2.1"]'),
('2.3', '2', 'Real-time Updates', 'WebSocket live data', 'Socket.io integration', 'Test reconnection, latency', 'planned', 'feature', 'medium', 'M', 'WebSocket complexity', 3600, '["dashboard","websocket"]', '["2.1"]');

-- Epic 3: Infrastructure (critical priority)
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority, complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
VALUES
('3', NULL, 'Infrastructure', 'Set up CI/CD and monitoring', 'Docker, GH Actions, monitoring', NULL, 'planned', 'chore', 'critical', 'M', 'DevOps setup', 10800, '["infra","devops"]', '[]'),
('3.1', '3', 'Docker Setup', 'Containerize application', 'Dockerfile, docker-compose', 'Build and run tests in container', 'planned', 'chore', 'critical', 'XS', 'Standard Docker', 1800, '["infra","docker","security"]', '[]'),
('3.2', '3', 'CI Pipeline', 'GitHub Actions workflow', 'Test, lint, build, deploy', 'Verify pipeline runs', 'planned', 'chore', 'high', 'S', 'Standard CI', 3600, '["infra","ci"]', '["3.1"]'),
('3.3', '3', 'Monitoring', 'Set up Prometheus + Grafana', 'Metrics, alerts, dashboards', 'Test alert triggers', 'blocked', 'chore', 'medium', 'S', 'Standard monitoring', 3600, '["infra","monitoring","security"]', '["3.1","3.2"]');

-- Memories (3 entries for FTS5 tests)
INSERT INTO memories (id, title, kind, why_important, body, source_type, source_name, source_via, auto_updatable, importance, confidence, status, scope, tags, links)
VALUES
('M-0001', 'Use Pest for testing', 'convention', 'Standardizes test framework', 'All tests must use Pest v4 with parallel execution. Use expect() assertions.', 'user', 'developer', 'manual', 1, 4, 0.9, 'active', '{"files": ["tests/"]}', '["testing","pest","convention"]', '[]'),
('M-0002', 'Redis for session caching', 'architecture', 'Performance requirement', 'Use Redis with token bucket rate limiting for API endpoints. TTL: 3600s for sessions.', 'agent', 'research', 'taskmanager:research', 1, 3, 0.8, 'active', '{"domains": ["caching","api"]}', '["redis","caching","architecture"]', '[]'),
('M-0003', 'Fix: SQLite WAL mode on NFS', 'bugfix', 'Prevents data corruption', 'SQLite WAL mode does not work on NFS mounts. Use DELETE journal mode for shared filesystems.', 'user', 'developer', 'manual', 0, 5, 1.0, 'active', '{"files": ["db/"]}', '["sqlite","bugfix","nfs"]', '[]');
SEED

PASS=0
FAIL=0
ERRORS=""

# Work from temp directory (tests use relative .taskmanager path)
cd "$WORK_DIR"

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
TABLE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('tasks','memories','memories_fts','state','schema_version','deferrals');")
assert_eq "$TABLE_COUNT" "6" "All 6 tables exist"

# Check schema version
VERSION=$(sqlite3 "$DB" "SELECT version FROM schema_version LIMIT 1;")
assert_eq "$VERSION" "3.1.0" "Schema version is 3.1.0"

# Negative test: sync_log table must NOT exist
SYNC_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='sync_log';")
assert_eq "$SYNC_EXISTS" "0" "sync_log table does NOT exist"

# State table has only expected columns
STATE_COLS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('state');")
assert_eq "$STATE_COLS" "7" "State table has exactly 7 columns"

# Check state row exists
STATE_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM state WHERE id = 1;")
assert_eq "$STATE_COUNT" "1" "State singleton row exists"

# Check config.json exists
if [[ -f ".taskmanager/config.json" ]]; then
    pass "config.json exists"
else
    fail "config.json does not exist"
fi

# Check activity.log exists
if [[ -f ".taskmanager/logs/activity.log" ]]; then
    pass "activity.log exists"
else
    fail "activity.log does not exist"
fi

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
       complexity_scale
FROM tasks
WHERE id = '1.2' AND archived_at IS NULL;
")
assert_not_empty "$SCOPE_TASK" "Scope: can load task 1.2"

# Update task fields (simulate scope up)
sqlite3 "$DB" "
UPDATE tasks SET
    description = 'Implement password reset via email with rate limiting',
    complexity_scale = 'M',
    estimate_seconds = 7200,
    updated_at = datetime('now')
WHERE id = '1.2';
"
UPDATED_SCALE=$(sqlite3 "$DB" "SELECT complexity_scale FROM tasks WHERE id = '1.2';")
assert_eq "$UPDATED_SCALE" "M" "Scope up: complexity_scale increased to M"

# Find dependent tasks (cascade query)
DEPENDENTS=$(sqlite3 "$DB" "
SELECT id, title, description
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND EXISTS (
      SELECT 1 FROM json_each(tasks.dependencies) d
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
sqlite3 "$DB" "UPDATE tasks SET description = 'Implement password reset via email', complexity_scale = 'S', estimate_seconds = 3600 WHERE id = '1.2';"

echo ""

# ====================================================================
# TEST 7: Expand (P4 - new command)
# ====================================================================
echo "--- Test 7: Expand command queries ---"

# Find expandable tasks (bulk mode query using complexity_scale)
EXPANDABLE=$(sqlite3 "$DB" "
SELECT id, title, complexity_scale
FROM tasks
WHERE archived_at IS NULL
  AND status NOT IN ('done', 'canceled', 'duplicate')
  AND CASE complexity_scale
      WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE -1
  END >= 2
  AND NOT EXISTS (
      SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id
  )
ORDER BY
  CASE complexity_scale WHEN 'XL' THEN 0 WHEN 'L' THEN 1 WHEN 'M' THEN 2 WHEN 'S' THEN 3 ELSE 4 END,
  id;
")
assert_not_empty "$EXPANDABLE" "Expand: found expandable tasks"

# Insert a subtask (simulate expansion)
sqlite3 "$DB" "
INSERT INTO tasks (id, parent_id, title, description, details, test_strategy, status, type, priority,
                   complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
VALUES ('2.1.1', '2.1', 'Line Chart Component', 'Build D3 line chart', 'SVG-based responsive line chart', 'Snapshot test', 'planned', 'feature', 'medium', 'XS', 'Simple D3 component', 1800, '[\"dashboard\"]', '[]');
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
SELECT id, title, complexity_scale
FROM tasks
WHERE parent_id = '2.1'
  AND CASE complexity_scale
      WHEN 'XS' THEN 0 WHEN 'S' THEN 1 WHEN 'M' THEN 2 WHEN 'L' THEN 3 WHEN 'XL' THEN 4 ELSE -1
  END >= 2
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
        FROM json_each(tasks.dependencies) d
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
        FROM json_each(tasks.dependencies) d
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
        FROM json_each(tasks.dependencies) d
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
                   complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
SELECT '3.4', '3', title, description, details, test_strategy, status, type, priority,
       complexity_scale, complexity_reasoning, estimate_seconds, tags,
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
                   complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies)
SELECT '2.3', '2', title, description, details, test_strategy, status, type, priority,
       complexity_scale, complexity_reasoning, estimate_seconds, tags, dependencies
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

# Verify simplified config has no deprecated sections
if echo "$CONFIG_KEYS" | grep -qF "execution"; then
    fail "Config: should not have 'execution' key (deprecated)"
else
    pass "Config: no deprecated 'execution' key"
fi
if echo "$CONFIG_KEYS" | grep -qF "planning"; then
    fail "Config: should not have 'planning' key (deprecated)"
else
    pass "Config: no deprecated 'planning' key"
fi

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
       complexity_scale,
       estimate_seconds,
       tags, dependencies
FROM tasks
WHERE archived_at IS NULL
ORDER BY id;
")
assert_not_empty "$EXPORT_DATA" "Export: query returns all active tasks"

EXPORT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE archived_at IS NULL;")
assert_eq "$EXPORT_COUNT" "14" "Export: correct number of active tasks"

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
assert_eq "$TOTAL" "14" "Stats --json: total tasks = 14"

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
SELECT t.id, t.title, t.priority, t.complexity_scale
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
    CASE t.complexity_scale
        WHEN 'XS' THEN 0
        WHEN 'S' THEN 1
        WHEN 'M' THEN 2
        WHEN 'L' THEN 3
        WHEN 'XL' THEN 4
        ELSE 2
    END,
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
# TEST 19: Deferrals
# ====================================================================
echo "--- Test 19: Deferrals ---"

# 19a: INSERT/SELECT CRUD
NEXT_DEF_ID=$(sqlite3 "$DB" "SELECT 'D-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) FROM deferrals;")
assert_eq "$NEXT_DEF_ID" "D-0001" "Deferrals: next ID is D-0001 (empty table)"

sqlite3 "$DB" "
INSERT INTO deferrals (id, source_task_id, target_task_id, title, body, reason)
VALUES ('D-0001', '1.1', '3.1', 'Add OAuth support', 'Implement OAuth2 with Google and GitHub providers', 'Too complex for MVP');
INSERT INTO deferrals (id, source_task_id, target_task_id, title, body, reason)
VALUES ('D-0002', '2.1', '2.3', 'Chart animations', 'Add smooth transitions to chart updates', 'Non-critical, defer to polish phase');
INSERT INTO deferrals (id, source_task_id, title, body, reason)
VALUES ('D-0003', '1.2', 'Rate limiting edge cases', 'Handle burst traffic scenarios for API endpoints', 'Deferred to hardening phase');
"

DEF_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM deferrals;")
assert_eq "$DEF_COUNT" "3" "Deferrals: 3 records inserted"

# Read back a specific deferral
DEF_TITLE=$(sqlite3 "$DB" "SELECT title FROM deferrals WHERE id = 'D-0001';")
assert_eq "$DEF_TITLE" "Add OAuth support" "Deferrals: can read back deferral by ID"

# 19b: Query deferrals by target task
TARGET_DEFS=$(sqlite3 "$DB" "
SELECT d.id, d.title, d.body, d.reason, d.source_task_id,
       t.title as source_title
FROM deferrals d
LEFT JOIN tasks t ON t.id = d.source_task_id
WHERE d.target_task_id = '3.1' AND d.status = 'pending'
ORDER BY d.created_at;
")
assert_not_empty "$TARGET_DEFS" "Deferrals: query by target returns results"
assert_contains "$TARGET_DEFS" "D-0001" "Deferrals: target query finds D-0001"
assert_contains "$TARGET_DEFS" "OAuth" "Deferrals: target query includes title"

# 19c: Query deferrals by source task
SOURCE_DEFS=$(sqlite3 "$DB" "SELECT id, title FROM deferrals WHERE source_task_id = '1.1';")
assert_contains "$SOURCE_DEFS" "D-0001" "Deferrals: query by source finds D-0001"

# 19d: Unassigned deferral (target_task_id IS NULL)
UNASSIGNED=$(sqlite3 "$DB" "
SELECT d.id, d.title FROM deferrals d
WHERE d.status = 'pending' AND d.target_task_id IS NULL;
")
assert_contains "$UNASSIGNED" "D-0003" "Deferrals: D-0003 is unassigned (NULL target)"

# 19e: Dashboard aggregate query
DASH_DEF=$(sqlite3 "$DB" "
SELECT
    COUNT(*) as pending,
    SUM(CASE WHEN target_task_id IS NOT NULL THEN 1 ELSE 0 END) as assigned,
    SUM(CASE WHEN target_task_id IS NULL THEN 1 ELSE 0 END) as unassigned
FROM deferrals WHERE status = 'pending';
")
assert_contains "$DASH_DEF" "3" "Deferrals: dashboard shows 3 pending"

# 19f: Status transitions
# pending -> applied
sqlite3 "$DB" "UPDATE deferrals SET status = 'applied', applied_at = datetime('now'), updated_at = datetime('now') WHERE id = 'D-0001';"
APPLIED_STATUS=$(sqlite3 "$DB" "SELECT status FROM deferrals WHERE id = 'D-0001';")
assert_eq "$APPLIED_STATUS" "applied" "Deferrals: D-0001 status -> applied"

APPLIED_AT=$(sqlite3 "$DB" "SELECT applied_at IS NOT NULL FROM deferrals WHERE id = 'D-0001';")
assert_eq "$APPLIED_AT" "1" "Deferrals: applied_at is set after apply"

# pending -> canceled
sqlite3 "$DB" "UPDATE deferrals SET status = 'canceled', updated_at = datetime('now') WHERE id = 'D-0002';"
CANCELED_STATUS=$(sqlite3 "$DB" "SELECT status FROM deferrals WHERE id = 'D-0002';")
assert_eq "$CANCELED_STATUS" "canceled" "Deferrals: D-0002 status -> canceled"

# pending -> reassigned (with new deferral)
sqlite3 "$DB" "
UPDATE deferrals SET status = 'reassigned', updated_at = datetime('now') WHERE id = 'D-0003';
INSERT INTO deferrals (id, source_task_id, target_task_id, title, body, reason)
VALUES ('D-0004', '1.2', '3.2', 'Rate limiting edge cases', 'Handle burst traffic scenarios for API endpoints', 'Reassigned from unassigned to task 3.2');
"
REASSIGNED_STATUS=$(sqlite3 "$DB" "SELECT status FROM deferrals WHERE id = 'D-0003';")
assert_eq "$REASSIGNED_STATUS" "reassigned" "Deferrals: D-0003 status -> reassigned"

NEW_DEF_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM deferrals WHERE id = 'D-0004' AND target_task_id = '3.2';")
assert_eq "$NEW_DEF_EXISTS" "1" "Deferrals: reassignment created D-0004 targeting 3.2"

# 19g: CHECK constraint validation
INVALID_STATUS=$(sqlite3 "$DB" "UPDATE deferrals SET status = 'invalid' WHERE id = 'D-0004';" 2>&1 || true)
if echo "$INVALID_STATUS" | grep -qi "constraint\|check"; then
    pass "Deferrals: CHECK constraint rejects invalid status"
else
    # Verify status was not actually changed
    STILL_PENDING=$(sqlite3 "$DB" "SELECT status FROM deferrals WHERE id = 'D-0004';")
    if [[ "$STILL_PENDING" == "pending" ]]; then
        pass "Deferrals: CHECK constraint rejects invalid status"
    else
        fail "Deferrals: CHECK constraint did NOT reject invalid status"
    fi
fi

# 19h: FK constraint - ON DELETE RESTRICT (source)
RESTRICT_RESULT=$(sqlite3 "$DB" "PRAGMA foreign_keys = ON; DELETE FROM tasks WHERE id = '1.2';" 2>&1 || true)
TASK_STILL_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE id = '1.2';")
assert_eq "$TASK_STILL_EXISTS" "1" "Deferrals: FK RESTRICT prevents deleting source task 1.2"

# 19i: FK constraint - ON DELETE SET NULL (target)
# Create a temporary task to use as target, then delete it
sqlite3 "$DB" "INSERT INTO tasks (id, title, status) VALUES ('99', 'Temp target', 'planned');"
sqlite3 "$DB" "INSERT INTO deferrals (id, source_task_id, target_task_id, title, body, reason) VALUES ('D-0005', '1.1', '99', 'Temp deferral', 'Test SET NULL', 'Testing FK');"
sqlite3 "$DB" "PRAGMA foreign_keys = ON; DELETE FROM tasks WHERE id = '99';"
NULL_TARGET=$(sqlite3 "$DB" "SELECT target_task_id IS NULL FROM deferrals WHERE id = 'D-0005';")
assert_eq "$NULL_TARGET" "1" "Deferrals: FK SET NULL nullifies target when task deleted"

# 19j: Stale deferral validation (target task is terminal but deferral pending)
# D-0004 targets 3.2 (planned). Mark 3.2 as done to make D-0004 stale.
sqlite3 "$DB" "UPDATE tasks SET status = 'done' WHERE id = '3.2';"
STALE=$(sqlite3 "$DB" "
SELECT d.id, d.title, d.target_task_id, t.status as target_status
FROM deferrals d
JOIN tasks t ON t.id = d.target_task_id
WHERE d.status = 'pending'
  AND t.status IN ('done', 'canceled', 'duplicate');
")
assert_contains "$STALE" "D-0004" "Deferrals: stale validation finds D-0004 (target 3.2 is done)"

# Restore 3.2 status
sqlite3 "$DB" "UPDATE tasks SET status = 'blocked' WHERE id = '3.2';"

# 19k: Move integration - update source/target IDs
# Simulate task move: if 3.1 moves to 4.1, all deferral references should update
sqlite3 "$DB" "
UPDATE deferrals SET source_task_id = '4.1', updated_at = datetime('now')
WHERE source_task_id = '3.1';
UPDATE deferrals SET target_task_id = '4.1', updated_at = datetime('now')
WHERE target_task_id = '3.1';
"
MOVED_TARGET=$(sqlite3 "$DB" "SELECT target_task_id FROM deferrals WHERE id = 'D-0001';")
assert_eq "$MOVED_TARGET" "4.1" "Deferrals: move updates target_task_id from 3.1 to 4.1"

# Restore
sqlite3 "$DB" "
UPDATE deferrals SET target_task_id = '3.1', updated_at = datetime('now')
WHERE id = 'D-0001';
UPDATE deferrals SET source_task_id = '3.1', updated_at = datetime('now')
WHERE source_task_id = '4.1';
"

# 19l: Next deferral ID after inserts
NEXT_ID_AFTER=$(sqlite3 "$DB" "SELECT 'D-' || printf('%04d', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1) FROM deferrals;")
assert_eq "$NEXT_ID_AFTER" "D-0006" "Deferrals: next ID after 5 records is D-0006"

# 19m: Deferral indexes exist
IDX_TARGET=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_deferrals_target';")
assert_eq "$IDX_TARGET" "1" "Deferrals: target index exists"

IDX_SOURCE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_deferrals_source';")
assert_eq "$IDX_SOURCE" "1" "Deferrals: source index exists"

IDX_STATUS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_deferrals_status';")
assert_eq "$IDX_STATUS" "1" "Deferrals: status index exists"

# Clean up test deferrals
sqlite3 "$DB" "DELETE FROM deferrals;"

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
