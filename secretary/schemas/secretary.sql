-- Secretary Plugin - SQLite Schema
-- Version: 1.0.0
-- Architecture: "Capture Fast, Process Later"
-- WAL mode enabled for concurrent hook + worker access

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ============================================================================
-- Schema Version Tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER NOT NULL,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO schema_version (version) VALUES (1);

-- ============================================================================
-- Queue Table (Core of the architecture)
-- All hook events go here as fast INSERTs. Worker processes them later.
-- ============================================================================

CREATE TABLE IF NOT EXISTS queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_type TEXT NOT NULL,                       -- user_prompt, tool_output, commit, agent_output, stop, session_end
    data TEXT NOT NULL,                            -- Raw captured content (JSON or text)
    priority INTEGER DEFAULT 5,                    -- 1=highest, 10=lowest
    session_id TEXT,                               -- Session that produced this item
    project TEXT,                                  -- Project context
    status TEXT DEFAULT 'pending',                 -- pending, processing, processed, failed, expired
    attempts INTEGER DEFAULT 0,                    -- Retry counter (max 3)
    error_message TEXT,                            -- Last error if failed
    processed_at TEXT,                             -- When processing completed
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    ttl_hours INTEGER DEFAULT 24                   -- Auto-expire after this many hours
);

CREATE INDEX IF NOT EXISTS idx_queue_status ON queue(status);
CREATE INDEX IF NOT EXISTS idx_queue_priority ON queue(priority);
CREATE INDEX IF NOT EXISTS idx_queue_created ON queue(created_at);
CREATE INDEX IF NOT EXISTS idx_queue_session ON queue(session_id);
CREATE INDEX IF NOT EXISTS idx_queue_type ON queue(item_type);

-- ============================================================================
-- Sessions Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    project TEXT,
    branch TEXT,
    directory TEXT,
    started_at TEXT NOT NULL,
    ended_at TEXT,
    duration_seconds INTEGER,
    summary TEXT,
    highlights TEXT,                               -- JSON array
    commits TEXT,                                  -- JSON array of commit hashes
    files_changed TEXT,                            -- JSON array
    status TEXT DEFAULT 'active',                  -- active, ending, ended, completed, interrupted
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);

-- ============================================================================
-- Commitments Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS commitments (
    id TEXT PRIMARY KEY,                           -- C-0001 format
    title TEXT NOT NULL,
    description TEXT,
    source_type TEXT NOT NULL,                     -- conversation, decision, external
    source_session_id TEXT,
    source_context TEXT,
    project TEXT,
    assignee TEXT DEFAULT 'self',
    stakeholder TEXT,
    due_date TEXT,
    due_type TEXT,                                 -- hard, soft, asap, someday
    priority TEXT DEFAULT 'medium',                -- critical, high, medium, low
    status TEXT DEFAULT 'pending',                 -- pending, in_progress, completed, deferred, canceled
    completed_at TEXT,
    deferred_until TEXT,
    deferred_count INTEGER DEFAULT 0,
    notes TEXT,
    related_commitments TEXT,                      -- JSON array
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_commitments_status ON commitments(status);
CREATE INDEX IF NOT EXISTS idx_commitments_due_date ON commitments(due_date);
CREATE INDEX IF NOT EXISTS idx_commitments_project ON commitments(project);
CREATE INDEX IF NOT EXISTS idx_commitments_priority ON commitments(priority);

-- FTS5 for commitment search
CREATE VIRTUAL TABLE IF NOT EXISTS commitments_fts USING fts5(
    title, description,
    content=commitments, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS commitments_ai AFTER INSERT ON commitments BEGIN
    INSERT INTO commitments_fts(rowid, title, description) VALUES (NEW.rowid, NEW.title, COALESCE(NEW.description, ''));
END;

CREATE TRIGGER IF NOT EXISTS commitments_ad AFTER DELETE ON commitments BEGIN
    INSERT INTO commitments_fts(commitments_fts, rowid, title, description) VALUES ('delete', OLD.rowid, OLD.title, COALESCE(OLD.description, ''));
END;

CREATE TRIGGER IF NOT EXISTS commitments_au AFTER UPDATE ON commitments BEGIN
    INSERT INTO commitments_fts(commitments_fts, rowid, title, description) VALUES ('delete', OLD.rowid, OLD.title, COALESCE(OLD.description, ''));
    INSERT INTO commitments_fts(rowid, title, description) VALUES (NEW.rowid, NEW.title, COALESCE(NEW.description, ''));
END;

-- ============================================================================
-- Decisions Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS decisions (
    id TEXT PRIMARY KEY,                           -- D-0001 format
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    rationale TEXT,
    alternatives TEXT,                             -- JSON array
    consequences TEXT,
    category TEXT,                                 -- architecture, process, technology, design
    scope TEXT,                                    -- project-wide, feature, component
    project TEXT,
    source_session_id TEXT,
    source_context TEXT,
    status TEXT DEFAULT 'active',                  -- active, superseded, reversed
    superseded_by TEXT,
    tags TEXT,                                     -- JSON array
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_decisions_category ON decisions(category);
CREATE INDEX IF NOT EXISTS idx_decisions_project ON decisions(project);
CREATE INDEX IF NOT EXISTS idx_decisions_status ON decisions(status);

-- FTS5 for decision search
CREATE VIRTUAL TABLE IF NOT EXISTS decisions_fts USING fts5(
    title, description, rationale,
    content=decisions, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS decisions_ai AFTER INSERT ON decisions BEGIN
    INSERT INTO decisions_fts(rowid, title, description, rationale) VALUES (NEW.rowid, NEW.title, NEW.description, COALESCE(NEW.rationale, ''));
END;

CREATE TRIGGER IF NOT EXISTS decisions_ad AFTER DELETE ON decisions BEGIN
    INSERT INTO decisions_fts(decisions_fts, rowid, title, description, rationale) VALUES ('delete', OLD.rowid, OLD.title, OLD.description, COALESCE(OLD.rationale, ''));
END;

CREATE TRIGGER IF NOT EXISTS decisions_au AFTER UPDATE ON decisions BEGIN
    INSERT INTO decisions_fts(decisions_fts, rowid, title, description, rationale) VALUES ('delete', OLD.rowid, OLD.title, OLD.description, COALESCE(OLD.rationale, ''));
    INSERT INTO decisions_fts(rowid, title, description, rationale) VALUES (NEW.rowid, NEW.title, NEW.description, COALESCE(NEW.rationale, ''));
END;

-- ============================================================================
-- Ideas Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS ideas (
    id TEXT PRIMARY KEY,                           -- I-0001 format
    title TEXT NOT NULL,
    description TEXT,
    idea_type TEXT NOT NULL,                       -- feature, improvement, exploration, refactor
    category TEXT,
    project TEXT,
    source_session_id TEXT,
    source_context TEXT,
    priority TEXT DEFAULT 'medium',
    effort TEXT,                                   -- small, medium, large, unknown
    potential_impact TEXT,                          -- high, medium, low
    status TEXT DEFAULT 'captured',                -- captured, exploring, implementing, parked, done, discarded
    related_ideas TEXT,                            -- JSON array
    related_decisions TEXT,                        -- JSON array
    notes TEXT,
    tags TEXT,                                     -- JSON array
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas(status);
CREATE INDEX IF NOT EXISTS idx_ideas_type ON ideas(idea_type);
CREATE INDEX IF NOT EXISTS idx_ideas_project ON ideas(project);
CREATE INDEX IF NOT EXISTS idx_ideas_priority ON ideas(priority);

-- FTS5 for idea search
CREATE VIRTUAL TABLE IF NOT EXISTS ideas_fts USING fts5(
    title, description,
    content=ideas, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS ideas_ai AFTER INSERT ON ideas BEGIN
    INSERT INTO ideas_fts(rowid, title, description) VALUES (NEW.rowid, NEW.title, COALESCE(NEW.description, ''));
END;

CREATE TRIGGER IF NOT EXISTS ideas_ad AFTER DELETE ON ideas BEGIN
    INSERT INTO ideas_fts(ideas_fts, rowid, title, description) VALUES ('delete', OLD.rowid, OLD.title, COALESCE(OLD.description, ''));
END;

CREATE TRIGGER IF NOT EXISTS ideas_au AFTER UPDATE ON ideas BEGIN
    INSERT INTO ideas_fts(ideas_fts, rowid, title, description) VALUES ('delete', OLD.rowid, OLD.title, COALESCE(OLD.description, ''));
    INSERT INTO ideas_fts(rowid, title, description) VALUES (NEW.rowid, NEW.title, COALESCE(NEW.description, ''));
END;

-- ============================================================================
-- Goals Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY,                           -- G-0001 format
    title TEXT NOT NULL,
    description TEXT,
    goal_type TEXT NOT NULL,                       -- objective, milestone, habit, okr
    timeframe TEXT,                                -- daily, weekly, monthly, quarterly, yearly
    parent_goal_id TEXT,
    project TEXT,
    target_value REAL,
    current_value REAL DEFAULT 0,
    target_unit TEXT,
    target_date TEXT,
    status TEXT DEFAULT 'active',                  -- active, completed, abandoned, paused
    progress_percentage REAL DEFAULT 0,
    milestones TEXT,                               -- JSON array
    tracking_data TEXT,                            -- JSON object
    related_commitments TEXT,                      -- JSON array
    related_decisions TEXT,                        -- JSON array
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_goals_goal_type ON goals(goal_type);
CREATE INDEX IF NOT EXISTS idx_goals_project ON goals(project);
CREATE INDEX IF NOT EXISTS idx_goals_parent ON goals(parent_goal_id);

-- ============================================================================
-- Patterns Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS patterns (
    id TEXT PRIMARY KEY,                           -- P-0001 format
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    pattern_type TEXT NOT NULL,                    -- behavior, preference, workflow, time, tool
    category TEXT,
    frequency TEXT,
    confidence REAL DEFAULT 0.5,
    evidence_count INTEGER DEFAULT 1,
    evidence_data TEXT,                            -- JSON array
    recommendations TEXT,                          -- JSON array
    project TEXT,
    status TEXT DEFAULT 'active',
    first_observed TEXT,
    last_observed TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_patterns_pattern_type ON patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_patterns_status ON patterns(status);

-- ============================================================================
-- Knowledge Graph
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge_nodes (
    id TEXT PRIMARY KEY,                           -- N-0001 format
    name TEXT NOT NULL,
    node_type TEXT NOT NULL,                       -- project, technology, person, concept, tool
    description TEXT,
    properties TEXT,                               -- JSON object
    aliases TEXT,                                  -- JSON array
    external_refs TEXT,                            -- JSON object
    importance INTEGER DEFAULT 3,
    last_interaction TEXT,
    interaction_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_knowledge_nodes_type ON knowledge_nodes(node_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_nodes_name ON knowledge_nodes(name);

CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_nodes_fts USING fts5(
    name, description,
    content=knowledge_nodes, content_rowid=rowid
);

CREATE TRIGGER IF NOT EXISTS knowledge_nodes_ai AFTER INSERT ON knowledge_nodes BEGIN
    INSERT INTO knowledge_nodes_fts(rowid, name, description) VALUES (NEW.rowid, NEW.name, COALESCE(NEW.description, ''));
END;

CREATE TRIGGER IF NOT EXISTS knowledge_nodes_ad AFTER DELETE ON knowledge_nodes BEGIN
    INSERT INTO knowledge_nodes_fts(knowledge_nodes_fts, rowid, name, description) VALUES ('delete', OLD.rowid, OLD.name, COALESCE(OLD.description, ''));
END;

CREATE TRIGGER IF NOT EXISTS knowledge_nodes_au AFTER UPDATE ON knowledge_nodes BEGIN
    INSERT INTO knowledge_nodes_fts(knowledge_nodes_fts, rowid, name, description) VALUES ('delete', OLD.rowid, OLD.name, COALESCE(OLD.description, ''));
    INSERT INTO knowledge_nodes_fts(rowid, name, description) VALUES (NEW.rowid, NEW.name, COALESCE(NEW.description, ''));
END;

CREATE TABLE IF NOT EXISTS knowledge_edges (
    id TEXT PRIMARY KEY,                           -- E-0001 format
    source_node_id TEXT NOT NULL,
    target_node_id TEXT NOT NULL,
    relationship TEXT NOT NULL,
    strength REAL DEFAULT 0.5,
    properties TEXT,                               -- JSON object
    evidence TEXT,                                 -- JSON array
    bidirectional INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (source_node_id) REFERENCES knowledge_nodes(id),
    FOREIGN KEY (target_node_id) REFERENCES knowledge_nodes(id)
);

CREATE INDEX IF NOT EXISTS idx_knowledge_edges_source ON knowledge_edges(source_node_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_edges_target ON knowledge_edges(target_node_id);

-- ============================================================================
-- Activity Timeline
-- ============================================================================

CREATE TABLE IF NOT EXISTS activity_timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    activity_type TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    project TEXT,
    title TEXT NOT NULL,
    details TEXT,                                  -- JSON object
    session_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_timeline(timestamp);
CREATE INDEX IF NOT EXISTS idx_activity_type ON activity_timeline(activity_type);
CREATE INDEX IF NOT EXISTS idx_activity_project ON activity_timeline(project);
CREATE INDEX IF NOT EXISTS idx_activity_session ON activity_timeline(session_id);

-- ============================================================================
-- Daily Notes
-- ============================================================================

CREATE TABLE IF NOT EXISTS daily_notes (
    id TEXT PRIMARY KEY,                           -- YYYY-MM-DD
    date TEXT NOT NULL UNIQUE,
    morning_plan TEXT,
    evening_reflection TEXT,
    work_summary TEXT,
    first_activity_at TEXT,
    last_activity_at TEXT,
    total_work_seconds INTEGER DEFAULT 0,
    projects_worked TEXT,                          -- JSON array
    sessions_count INTEGER DEFAULT 0,
    commits_count INTEGER DEFAULT 0,
    completed_commitments TEXT,                    -- JSON array
    new_commitments TEXT,                          -- JSON array
    overdue_items TEXT,                            -- JSON array
    new_ideas TEXT,                                -- JSON array
    new_decisions TEXT,                            -- JSON array
    highlights TEXT,                               -- JSON array
    blockers TEXT,                                 -- JSON array
    personal_notes TEXT,
    mood_rating INTEGER,
    energy_level INTEGER,
    focus_score INTEGER,
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_daily_notes_date ON daily_notes(date);

-- ============================================================================
-- GitHub Cache
-- ============================================================================

CREATE TABLE IF NOT EXISTS github_cache (
    id TEXT PRIMARY KEY,
    cache_type TEXT NOT NULL,
    data TEXT NOT NULL,
    fetched_at TEXT NOT NULL,
    expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_github_cache_type ON github_cache(cache_type);
CREATE INDEX IF NOT EXISTS idx_github_cache_expires ON github_cache(expires_at);

-- ============================================================================
-- External Changes
-- ============================================================================

CREATE TABLE IF NOT EXISTS external_changes (
    id TEXT PRIMARY KEY,
    change_type TEXT NOT NULL,
    source TEXT NOT NULL,
    description TEXT NOT NULL,
    details TEXT,                                  -- JSON object
    project TEXT,
    file_path TEXT,
    detected_at TEXT NOT NULL,
    acknowledged INTEGER DEFAULT 0,
    acknowledged_at TEXT,
    relevance_score REAL DEFAULT 0.5,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_external_changes_type ON external_changes(change_type);
CREATE INDEX IF NOT EXISTS idx_external_changes_project ON external_changes(project);

-- ============================================================================
-- Worker State
-- ============================================================================

CREATE TABLE IF NOT EXISTS worker_state (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    last_run_at TEXT,
    last_success_at TEXT,
    last_error TEXT,
    items_processed INTEGER DEFAULT 0,
    total_runs INTEGER DEFAULT 0,
    last_vault_sync_at TEXT,
    last_github_refresh_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO worker_state (id) VALUES (1);

-- ============================================================================
-- State Table (singleton)
-- ============================================================================

CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    current_session_id TEXT,
    last_briefing_at TEXT,
    last_sync_at TEXT,
    github_cache_updated_at TEXT,
    settings TEXT,                                 -- JSON runtime settings
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO state (id) VALUES (1);
