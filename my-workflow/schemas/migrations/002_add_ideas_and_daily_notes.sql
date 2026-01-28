-- Migration 002: Add ideas, daily_notes, and personal_notes tables
-- Version: 2

-- ============================================================================
-- Ideas Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS ideas (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    idea_type TEXT NOT NULL,
    category TEXT,
    project TEXT,
    source_session_id TEXT,
    source_context TEXT,
    priority TEXT DEFAULT 'medium',
    effort TEXT,
    potential_impact TEXT,
    status TEXT DEFAULT 'captured',
    related_ideas TEXT,
    related_decisions TEXT,
    notes TEXT,
    tags TEXT,
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas(status);
CREATE INDEX IF NOT EXISTS idx_ideas_type ON ideas(idea_type);
CREATE INDEX IF NOT EXISTS idx_ideas_project ON ideas(project);
CREATE INDEX IF NOT EXISTS idx_ideas_priority ON ideas(priority);

-- ============================================================================
-- Daily Notes Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS daily_notes (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL UNIQUE,
    morning_plan TEXT,
    evening_reflection TEXT,
    work_summary TEXT,
    first_activity_at TEXT,
    last_activity_at TEXT,
    total_work_seconds INTEGER DEFAULT 0,
    projects_worked TEXT,
    sessions_count INTEGER DEFAULT 0,
    commits_count INTEGER DEFAULT 0,
    completed_commitments TEXT,
    new_commitments TEXT,
    overdue_items TEXT,
    new_ideas TEXT,
    new_decisions TEXT,
    highlights TEXT,
    blockers TEXT,
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
-- Personal Notes Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS personal_notes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    note_type TEXT DEFAULT 'general',
    project TEXT,
    session_id TEXT,
    tags TEXT,
    pinned INTEGER DEFAULT 0,
    archived INTEGER DEFAULT 0,
    vault_note_path TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_personal_notes_type ON personal_notes(note_type);
CREATE INDEX IF NOT EXISTS idx_personal_notes_pinned ON personal_notes(pinned);
CREATE INDEX IF NOT EXISTS idx_personal_notes_archived ON personal_notes(archived);

-- Update schema version
INSERT INTO schema_version (version) VALUES (2);
