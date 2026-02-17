-- Secretary Plugin - Encrypted Memory Database Schema
-- Used with SQLCipher (AES-256) when available, plain sqlite3 as fallback
-- Version: 1.0.0

PRAGMA foreign_keys = ON;

-- ============================================================================
-- Memory Table
-- Sensitive data entries (credentials, IPs, phones, secrets)
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,                         -- The sensitive data
    category TEXT NOT NULL DEFAULT 'general',      -- credential, api_key, ip_address, phone, secret, note, general
    tags TEXT,                                     -- JSON array of tags for filtering
    project TEXT,                                  -- Related project (optional)
    metadata TEXT,                                 -- JSON object for extra fields
    is_sensitive INTEGER DEFAULT 1,                -- 1 = encrypted at rest
    expires_at TEXT,                               -- Optional expiration date
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_memory_category ON memory(category);
CREATE INDEX IF NOT EXISTS idx_memory_project ON memory(project);
CREATE INDEX IF NOT EXISTS idx_memory_expires ON memory(expires_at);

-- FTS5 for memory search (searches across title, content, tags)
CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts USING fts5(
    title, content, tags
);

-- Keep FTS in sync
CREATE TRIGGER IF NOT EXISTS memory_ai AFTER INSERT ON memory BEGIN
    INSERT INTO memory_fts(rowid, title, content, tags) VALUES (NEW.rowid, NEW.title, NEW.content, NEW.tags);
END;

CREATE TRIGGER IF NOT EXISTS memory_ad AFTER DELETE ON memory BEGIN
    INSERT INTO memory_fts(memory_fts, rowid, title, content, tags) VALUES ('delete', OLD.rowid, OLD.title, OLD.content, OLD.tags);
END;

CREATE TRIGGER IF NOT EXISTS memory_au AFTER UPDATE ON memory BEGIN
    INSERT INTO memory_fts(memory_fts, rowid, title, content, tags) VALUES ('delete', OLD.rowid, OLD.title, OLD.content, OLD.tags);
    INSERT INTO memory_fts(rowid, title, content, tags) VALUES (NEW.rowid, NEW.title, NEW.content, NEW.tags);
END;

-- ============================================================================
-- Access Log (Audit Trail)
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    memory_id INTEGER,
    action TEXT NOT NULL,                          -- read, write, delete, search
    details TEXT,                                  -- What was accessed/changed
    accessed_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (memory_id) REFERENCES memory(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_memory_access_action ON memory_access_log(action);
CREATE INDEX IF NOT EXISTS idx_memory_access_time ON memory_access_log(accessed_at);
