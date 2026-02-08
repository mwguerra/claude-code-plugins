-- Taskmanager SQLite Schema v3.0.0
-- This file defines the complete database structure

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    parent_id TEXT REFERENCES tasks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    details TEXT,
    test_strategy TEXT,
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('draft', 'planned', 'in-progress', 'blocked', 'paused', 'done', 'canceled', 'duplicate', 'needs-review')),
    type TEXT NOT NULL DEFAULT 'feature'
        CHECK (type IN ('feature', 'bug', 'chore', 'analysis', 'spike')),
    priority TEXT NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    complexity_scale TEXT CHECK (complexity_scale IN ('XS', 'S', 'M', 'L', 'XL')),
    complexity_reasoning TEXT,
    complexity_expansion_prompt TEXT,
    estimate_seconds INTEGER,
    duration_seconds INTEGER,
    owner TEXT,

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    started_at TEXT,
    completed_at TEXT,
    archived_at TEXT,

    -- Flexible storage (JSON)
    tags TEXT DEFAULT '[]',
    dependencies TEXT DEFAULT '[]',
    dependency_analysis TEXT,
    meta TEXT DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_id);
CREATE INDEX IF NOT EXISTS idx_tasks_archived ON tasks(archived_at);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

-- Memories table
CREATE TABLE IF NOT EXISTS memories (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    kind TEXT NOT NULL
        CHECK (kind IN ('constraint', 'decision', 'bugfix', 'workaround', 'convention', 'architecture', 'process', 'integration', 'anti-pattern', 'other')),
    why_important TEXT NOT NULL,
    body TEXT NOT NULL,

    -- Ownership
    source_type TEXT NOT NULL CHECK (source_type IN ('user', 'agent', 'command', 'hook', 'other')),
    source_name TEXT,
    source_via TEXT,
    auto_updatable INTEGER DEFAULT 1,

    -- Scoring
    importance INTEGER NOT NULL DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),
    confidence REAL NOT NULL DEFAULT 0.8 CHECK (confidence BETWEEN 0 AND 1),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deprecated', 'superseded', 'draft')),
    superseded_by TEXT REFERENCES memories(id),

    -- Scope (JSON)
    scope TEXT DEFAULT '{}',
    tags TEXT DEFAULT '[]',
    links TEXT DEFAULT '[]',

    -- Usage
    use_count INTEGER DEFAULT 0,
    last_used_at TEXT,
    last_conflict_at TEXT,
    conflict_resolutions TEXT DEFAULT '[]',

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Full-text search for memories
CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
    title, body, tags,
    content='memories',
    content_rowid='rowid'
);

-- FTS sync triggers
CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

-- State table (single row)
CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    current_task_id TEXT REFERENCES tasks(id),
    task_memory TEXT DEFAULT '[]',
    debug_enabled INTEGER DEFAULT 0,
    session_id TEXT,
    started_at TEXT,
    last_update TEXT
);

-- Initialize state with single row
INSERT OR IGNORE INTO state (id) VALUES (1);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO schema_version (version) VALUES ('3.0.0');
