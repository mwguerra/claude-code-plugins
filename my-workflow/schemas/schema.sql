-- My Workflow Plugin - SQLite Schema
-- Version: 1.0.0

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- ============================================================================
-- Schema Version Tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER NOT NULL,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO schema_version (version) VALUES (1);

-- ============================================================================
-- Sessions Table
-- Every Claude Code session with summary, outcomes, duration
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,                          -- Session ID (UUID or timestamp-based)
    project TEXT,                                 -- Project name/path
    branch TEXT,                                  -- Git branch at session start
    started_at TEXT NOT NULL,                     -- ISO 8601 timestamp
    ended_at TEXT,                                -- ISO 8601 timestamp
    duration_seconds INTEGER,                     -- Computed duration
    summary TEXT,                                 -- AI-generated session summary
    highlights TEXT,                              -- JSON array of key accomplishments
    commits TEXT,                                 -- JSON array of commit hashes made
    files_changed TEXT,                           -- JSON array of files modified
    status TEXT DEFAULT 'active',                 -- active, completed, interrupted
    vault_note_path TEXT,                         -- Path to Obsidian note if synced
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);

-- ============================================================================
-- Commitments Table
-- Promises, follow-ups, action items with due dates
-- ============================================================================

CREATE TABLE IF NOT EXISTS commitments (
    id TEXT PRIMARY KEY,                          -- Commitment ID (C-0001 format)
    title TEXT NOT NULL,                          -- Brief title
    description TEXT,                             -- Full description
    source_type TEXT NOT NULL,                    -- conversation, decision, external
    source_session_id TEXT,                       -- Session where extracted
    source_context TEXT,                          -- Surrounding conversation context
    project TEXT,                                 -- Related project
    assignee TEXT DEFAULT 'self',                 -- Who is responsible (self, external name)
    stakeholder TEXT,                             -- Who cares about this
    due_date TEXT,                                -- ISO 8601 date
    due_type TEXT,                                -- hard, soft, asap, someday
    priority TEXT DEFAULT 'medium',               -- critical, high, medium, low
    status TEXT DEFAULT 'pending',                -- pending, in_progress, completed, deferred, canceled
    completed_at TEXT,                            -- When marked complete
    deferred_until TEXT,                          -- If deferred, when to resurface
    deferred_count INTEGER DEFAULT 0,             -- How many times deferred
    notes TEXT,                                   -- Additional notes
    related_commitments TEXT,                     -- JSON array of related commitment IDs
    vault_note_path TEXT,                         -- Path to Obsidian note if synced
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_commitments_status ON commitments(status);
CREATE INDEX IF NOT EXISTS idx_commitments_due_date ON commitments(due_date);
CREATE INDEX IF NOT EXISTS idx_commitments_project ON commitments(project);
CREATE INDEX IF NOT EXISTS idx_commitments_priority ON commitments(priority);

-- ============================================================================
-- Decisions Table
-- Architectural/process decisions with rationale
-- ============================================================================

CREATE TABLE IF NOT EXISTS decisions (
    id TEXT PRIMARY KEY,                          -- Decision ID (D-0001 format)
    title TEXT NOT NULL,                          -- Brief title
    description TEXT NOT NULL,                    -- What was decided
    rationale TEXT,                               -- Why this decision was made
    alternatives TEXT,                            -- JSON array of alternatives considered
    consequences TEXT,                            -- Expected consequences/tradeoffs
    category TEXT,                                -- architecture, process, technology, design
    scope TEXT,                                   -- project-wide, feature, component
    project TEXT,                                 -- Related project
    source_session_id TEXT,                       -- Session where made
    source_context TEXT,                          -- Conversation context
    status TEXT DEFAULT 'active',                 -- active, superseded, reversed
    superseded_by TEXT,                           -- ID of decision that superseded this
    tags TEXT,                                    -- JSON array of tags
    vault_note_path TEXT,                         -- Path to Obsidian note if synced
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_decisions_category ON decisions(category);
CREATE INDEX IF NOT EXISTS idx_decisions_project ON decisions(project);
CREATE INDEX IF NOT EXISTS idx_decisions_status ON decisions(status);

-- ============================================================================
-- Goals Table
-- Objectives, milestones, habits with progress tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS goals (
    id TEXT PRIMARY KEY,                          -- Goal ID (G-0001 format)
    title TEXT NOT NULL,                          -- Brief title
    description TEXT,                             -- Full description
    goal_type TEXT NOT NULL,                      -- objective, milestone, habit, okr
    timeframe TEXT,                               -- daily, weekly, monthly, quarterly, yearly
    parent_goal_id TEXT,                          -- For hierarchical goals
    project TEXT,                                 -- Related project (optional)
    target_value REAL,                            -- Numeric target (if measurable)
    current_value REAL DEFAULT 0,                 -- Current progress
    target_unit TEXT,                             -- Unit of measurement
    target_date TEXT,                             -- Target completion date
    status TEXT DEFAULT 'active',                 -- active, completed, abandoned, paused
    progress_percentage REAL DEFAULT 0,           -- 0-100
    milestones TEXT,                              -- JSON array of milestone checkpoints
    tracking_data TEXT,                           -- JSON object for habit tracking
    related_commitments TEXT,                     -- JSON array of related commitment IDs
    related_decisions TEXT,                       -- JSON array of related decision IDs
    vault_note_path TEXT,                         -- Path to Obsidian note if synced
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_goals_goal_type ON goals(goal_type);
CREATE INDEX IF NOT EXISTS idx_goals_project ON goals(project);
CREATE INDEX IF NOT EXISTS idx_goals_parent ON goals(parent_goal_id);

-- ============================================================================
-- Patterns Table
-- Detected behaviors, preferences, workflows
-- ============================================================================

CREATE TABLE IF NOT EXISTS patterns (
    id TEXT PRIMARY KEY,                          -- Pattern ID (P-0001 format)
    title TEXT NOT NULL,                          -- Brief title
    description TEXT NOT NULL,                    -- Description of the pattern
    pattern_type TEXT NOT NULL,                   -- behavior, preference, workflow, time, tool
    category TEXT,                                -- productivity, communication, coding, etc.
    frequency TEXT,                               -- daily, weekly, occasional, situational
    confidence REAL DEFAULT 0.5,                  -- 0.0-1.0 confidence score
    evidence_count INTEGER DEFAULT 1,             -- Number of supporting observations
    evidence_data TEXT,                           -- JSON array of evidence/observations
    recommendations TEXT,                         -- JSON array of suggested actions
    project TEXT,                                 -- Project-specific or NULL for global
    status TEXT DEFAULT 'active',                 -- active, deprecated, investigating
    first_observed TEXT,                          -- When pattern was first seen
    last_observed TEXT,                           -- Most recent observation
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_patterns_pattern_type ON patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_patterns_status ON patterns(status);
CREATE INDEX IF NOT EXISTS idx_patterns_confidence ON patterns(confidence);

-- ============================================================================
-- Knowledge Nodes Table
-- Entities: projects, technologies, people, concepts
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge_nodes (
    id TEXT PRIMARY KEY,                          -- Node ID (N-0001 format)
    name TEXT NOT NULL,                           -- Entity name
    node_type TEXT NOT NULL,                      -- project, technology, person, concept, tool
    description TEXT,                             -- Description
    properties TEXT,                              -- JSON object of type-specific properties
    aliases TEXT,                                 -- JSON array of alternative names
    external_refs TEXT,                           -- JSON object of external references (URLs, etc.)
    importance INTEGER DEFAULT 3,                 -- 1-5 importance rating
    last_interaction TEXT,                        -- Last time this entity was relevant
    interaction_count INTEGER DEFAULT 0,          -- How often encountered
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_knowledge_nodes_type ON knowledge_nodes(node_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_nodes_name ON knowledge_nodes(name);

-- Full-text search on knowledge nodes
CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_nodes_fts USING fts5(
    name,
    description,
    content=knowledge_nodes,
    content_rowid=rowid
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS knowledge_nodes_ai AFTER INSERT ON knowledge_nodes BEGIN
    INSERT INTO knowledge_nodes_fts(rowid, name, description)
    VALUES (NEW.rowid, NEW.name, NEW.description);
END;

CREATE TRIGGER IF NOT EXISTS knowledge_nodes_ad AFTER DELETE ON knowledge_nodes BEGIN
    INSERT INTO knowledge_nodes_fts(knowledge_nodes_fts, rowid, name, description)
    VALUES ('delete', OLD.rowid, OLD.name, OLD.description);
END;

CREATE TRIGGER IF NOT EXISTS knowledge_nodes_au AFTER UPDATE ON knowledge_nodes BEGIN
    INSERT INTO knowledge_nodes_fts(knowledge_nodes_fts, rowid, name, description)
    VALUES ('delete', OLD.rowid, OLD.name, OLD.description);
    INSERT INTO knowledge_nodes_fts(rowid, name, description)
    VALUES (NEW.rowid, NEW.name, NEW.description);
END;

-- ============================================================================
-- Knowledge Edges Table
-- Relationships between entities
-- ============================================================================

CREATE TABLE IF NOT EXISTS knowledge_edges (
    id TEXT PRIMARY KEY,                          -- Edge ID (E-0001 format)
    source_node_id TEXT NOT NULL,                 -- From node
    target_node_id TEXT NOT NULL,                 -- To node
    relationship TEXT NOT NULL,                   -- uses, knows, owns, depends_on, related_to, etc.
    strength REAL DEFAULT 0.5,                    -- 0.0-1.0 relationship strength
    properties TEXT,                              -- JSON object of relationship properties
    evidence TEXT,                                -- JSON array of evidence for this relationship
    bidirectional INTEGER DEFAULT 0,              -- 1 if relationship goes both ways
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (source_node_id) REFERENCES knowledge_nodes(id),
    FOREIGN KEY (target_node_id) REFERENCES knowledge_nodes(id)
);

CREATE INDEX IF NOT EXISTS idx_knowledge_edges_source ON knowledge_edges(source_node_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_edges_target ON knowledge_edges(target_node_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_edges_relationship ON knowledge_edges(relationship);

-- ============================================================================
-- External Changes Table
-- Changes detected outside Claude Code
-- ============================================================================

CREATE TABLE IF NOT EXISTS external_changes (
    id TEXT PRIMARY KEY,                          -- Change ID (X-0001 format)
    change_type TEXT NOT NULL,                    -- file, git, github, calendar, etc.
    source TEXT NOT NULL,                         -- Where the change came from
    description TEXT NOT NULL,                    -- What changed
    details TEXT,                                 -- JSON object with change details
    project TEXT,                                 -- Related project
    file_path TEXT,                               -- Related file path if applicable
    detected_at TEXT NOT NULL,                    -- When change was detected
    acknowledged INTEGER DEFAULT 0,               -- 1 if user has seen this
    acknowledged_at TEXT,                         -- When acknowledged
    relevance_score REAL DEFAULT 0.5,             -- 0.0-1.0 how relevant is this change
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_external_changes_type ON external_changes(change_type);
CREATE INDEX IF NOT EXISTS idx_external_changes_project ON external_changes(project);
CREATE INDEX IF NOT EXISTS idx_external_changes_acknowledged ON external_changes(acknowledged);
CREATE INDEX IF NOT EXISTS idx_external_changes_detected_at ON external_changes(detected_at);

-- ============================================================================
-- Activity Timeline Table
-- Unified activity log for all workflow events
-- ============================================================================

CREATE TABLE IF NOT EXISTS activity_timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    activity_type TEXT NOT NULL,                  -- session_start, session_end, commit, commitment, decision, goal, external_change
    entity_type TEXT,                             -- sessions, commitments, decisions, goals, etc.
    entity_id TEXT,                               -- ID of the related entity
    project TEXT,                                 -- Related project
    title TEXT NOT NULL,                          -- Brief description
    details TEXT,                                 -- JSON object with additional details
    session_id TEXT                               -- Session during which this occurred
);

CREATE INDEX IF NOT EXISTS idx_activity_timeline_timestamp ON activity_timeline(timestamp);
CREATE INDEX IF NOT EXISTS idx_activity_timeline_type ON activity_timeline(activity_type);
CREATE INDEX IF NOT EXISTS idx_activity_timeline_project ON activity_timeline(project);
CREATE INDEX IF NOT EXISTS idx_activity_timeline_session ON activity_timeline(session_id);

-- ============================================================================
-- GitHub Cache Table
-- Cached GitHub data to avoid rate limits
-- ============================================================================

CREATE TABLE IF NOT EXISTS github_cache (
    id TEXT PRIMARY KEY,                          -- Cache key
    cache_type TEXT NOT NULL,                     -- issues, prs, reviews, notifications
    data TEXT NOT NULL,                           -- JSON cached data
    fetched_at TEXT NOT NULL,                     -- When data was fetched
    expires_at TEXT NOT NULL                      -- When cache expires
);

CREATE INDEX IF NOT EXISTS idx_github_cache_type ON github_cache(cache_type);
CREATE INDEX IF NOT EXISTS idx_github_cache_expires ON github_cache(expires_at);

-- ============================================================================
-- State Table
-- Plugin state and configuration
-- ============================================================================

CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- Single row
    current_session_id TEXT,                          -- Active session ID
    last_briefing_at TEXT,                            -- When last briefing was shown
    last_sync_at TEXT,                                -- When last vault sync occurred
    github_cache_updated_at TEXT,                     -- When GitHub cache was last updated
    settings TEXT,                                    -- JSON runtime settings
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Initialize state row
INSERT OR IGNORE INTO state (id) VALUES (1);
