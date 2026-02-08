-- Taskmanager Common SQL Queries
-- Reference file for commands to use via sqlite3

-- ============================================================================
-- TASK QUERIES
-- ============================================================================

-- Get task by ID
-- Usage: sqlite3 .taskmanager/taskmanager.db "SELECT * FROM tasks WHERE id = '1.2.3'"

-- Get all active (non-archived) tasks
-- SELECT * FROM tasks WHERE archived_at IS NULL;

-- Get task with subtasks count
-- SELECT t.*, (SELECT COUNT(*) FROM tasks c WHERE c.parent_id = t.id) as subtask_count
-- FROM tasks t WHERE t.id = ?;

-- Get all descendants of a task (recursive)
-- WITH RECURSIVE descendants AS (
--     SELECT * FROM tasks WHERE id = ?
--     UNION ALL
--     SELECT t.* FROM tasks t JOIN descendants d ON t.parent_id = d.id
-- )
-- SELECT * FROM descendants;

-- Get all ancestors of a task (for status propagation)
-- WITH RECURSIVE ancestors AS (
--     SELECT id, parent_id FROM tasks WHERE id = ?
--     UNION ALL
--     SELECT t.id, t.parent_id FROM tasks t JOIN ancestors a ON t.id = a.parent_id
-- )
-- SELECT id FROM ancestors WHERE id != ?;

-- ============================================================================
-- NEXT TASK SELECTION
-- ============================================================================

-- Find next available task (leaf, not done, dependencies satisfied)
-- WITH done_ids AS (
--     SELECT id FROM tasks
--     WHERE status IN ('done', 'canceled', 'duplicate')
-- )
-- SELECT t.* FROM tasks t
-- WHERE t.archived_at IS NULL
--   AND t.status NOT IN ('done', 'canceled', 'duplicate', 'blocked')
--   AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = t.id)
--   AND (
--       t.dependencies = '[]'
--       OR NOT EXISTS (
--           SELECT 1 FROM json_each(t.dependencies) d
--           WHERE d.value NOT IN (SELECT id FROM done_ids)
--       )
--   )
-- ORDER BY
--     CASE t.priority
--         WHEN 'critical' THEN 0
--         WHEN 'high' THEN 1
--         WHEN 'medium' THEN 2
--         ELSE 3
--     END,
--     CASE t.complexity_scale
--         WHEN 'XS' THEN 0
--         WHEN 'S' THEN 1
--         WHEN 'M' THEN 2
--         WHEN 'L' THEN 3
--         WHEN 'XL' THEN 4
--         ELSE 2
--     END
-- LIMIT 1;

-- ============================================================================
-- STATISTICS
-- ============================================================================

-- Task counts by status
-- SELECT status, COUNT(*) as count FROM tasks WHERE archived_at IS NULL GROUP BY status;

-- Task counts by priority
-- SELECT priority, COUNT(*) as count FROM tasks WHERE archived_at IS NULL GROUP BY priority;

-- Completion stats
-- SELECT
--     COUNT(*) as total,
--     SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
--     SUM(CASE WHEN status = 'in-progress' THEN 1 ELSE 0 END) as in_progress,
--     SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END) as blocked,
--     SUM(CASE WHEN status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as remaining
-- FROM tasks WHERE archived_at IS NULL;

-- Time remaining (sum of leaf task estimates)
-- SELECT COALESCE(SUM(estimate_seconds), 0) as remaining_seconds
-- FROM tasks
-- WHERE archived_at IS NULL
--   AND status NOT IN ('done', 'canceled', 'duplicate')
--   AND NOT EXISTS (SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id);

-- ============================================================================
-- STATUS PROPAGATION
-- ============================================================================

-- Propagate status to a single parent based on children
-- UPDATE tasks SET
--     status = (
--         SELECT CASE
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'in-progress') THEN 'in-progress'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'blocked') THEN 'blocked'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'needs-review') THEN 'needs-review'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status IN ('planned', 'draft', 'paused')) THEN 'planned'
--             WHEN EXISTS(SELECT 1 FROM tasks c WHERE c.parent_id = tasks.id AND c.status = 'done') THEN 'done'
--             ELSE 'canceled'
--         END
--     ),
--     updated_at = datetime('now')
-- WHERE id = ?;

-- ============================================================================
-- MEMORY QUERIES
-- ============================================================================

-- Full-text search in memories
-- SELECT m.* FROM memories m
-- JOIN memories_fts fts ON m.rowid = fts.rowid
-- WHERE memories_fts MATCH ?
-- ORDER BY rank;

-- Get active memories by importance
-- SELECT * FROM memories WHERE status = 'active' AND importance >= 3 ORDER BY importance DESC;

-- ============================================================================
-- ARCHIVAL
-- ============================================================================

-- Archive completed tasks
-- UPDATE tasks SET archived_at = datetime('now'), updated_at = datetime('now')
-- WHERE status IN ('done', 'canceled', 'duplicate') AND archived_at IS NULL;
