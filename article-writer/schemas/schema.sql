-- Article Writer SQLite Schema
-- Version: 1.0.0
-- All tables for the article-writer plugin.
-- Replaces: article_tasks.json, authors.json, settings.json

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Schema versioning
CREATE TABLE IF NOT EXISTS schema_version (
  version TEXT PRIMARY KEY,
  applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO schema_version (version) VALUES ('1.0.0');

-- Authors table
CREATE TABLE IF NOT EXISTS authors (
  id TEXT PRIMARY KEY CHECK(id GLOB '[a-z0-9-]*'),
  name TEXT NOT NULL,
  languages TEXT NOT NULL DEFAULT '["en_US"]',  -- JSON array
  role TEXT,           -- JSON: string or array
  experience TEXT,     -- JSON: string or array
  expertise TEXT,      -- JSON: string or array
  tone_formality INTEGER CHECK(tone_formality IS NULL OR (tone_formality >= 1 AND tone_formality <= 10)),
  tone_opinionated INTEGER CHECK(tone_opinionated IS NULL OR (tone_opinionated >= 1 AND tone_opinionated <= 10)),
  vocabulary TEXT,     -- JSON object {use_freely, always_explain}
  phrases TEXT,        -- JSON object {signature, avoid}
  opinions TEXT,       -- JSON object {strong_positions, stay_neutral}
  example_voice TEXT,
  voice_analysis TEXT, -- JSON object (full voice analysis data)
  notes TEXT,          -- JSON: string or array
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Articles table
CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY CHECK(id >= 1),
  title TEXT NOT NULL CHECK(length(title) >= 10 AND length(title) <= 200),
  subject TEXT NOT NULL CHECK(length(subject) >= 3 AND length(subject) <= 100),
  area TEXT NOT NULL CHECK(area IN (
    'Architecture', 'Backend', 'Business', 'Database', 'DevOps',
    'Files', 'Frontend', 'Full-stack', 'JavaScript', 'Laravel',
    'Native Apps', 'Notifications', 'Performance', 'PHP', 'Quality',
    'Security', 'Soft Skills', 'Testing', 'Tools', 'AI/ML'
  )),
  tags TEXT NOT NULL,
  difficulty TEXT NOT NULL CHECK(difficulty IN (
    'Beginner', 'Intermediate', 'Advanced', 'All Levels'
  )),
  relevance TEXT NOT NULL,
  content_type TEXT NOT NULL CHECK(content_type IN (
    'Deep-dive Tutorial', 'Tutorial with Examples', 'Tutorial',
    'Deep-dive', 'Comprehensive Guide', 'Comprehensive Tutorial',
    'Quick Tutorial', 'Quick Tip', 'Quick Setup', 'Project Tutorial',
    'Project Series', 'Tips & Tricks', 'Case Study', 'Pattern Guide',
    'Feature Overview', 'Reference Guide', 'Comparison', 'Collection',
    'Checklist', 'Setup Guide', 'Guide', 'Tool Introduction',
    'Tool Tutorial', 'Tool Review', 'Opinion', 'Opinion + Tutorial',
    'Opinion/Experience', 'Experience Sharing', 'Strategic Guide',
    'Practical Guide', 'Framework Guide', 'Idea Collection + Guide',
    'Comparison Guide', 'Step-by-step Tutorial'
  )),
  estimated_effort TEXT NOT NULL CHECK(estimated_effort IN (
    'Short', 'Medium', 'Long', 'Long (Series)'
  )),
  versions TEXT NOT NULL,
  series_potential TEXT NOT NULL,
  prerequisites TEXT NOT NULL CHECK(length(prerequisites) >= 1),
  reference_urls TEXT NOT NULL CHECK(length(reference_urls) >= 1),
  author_id TEXT REFERENCES authors(id),
  author_name TEXT,       -- cached for convenience
  author_languages TEXT,  -- JSON array, cached subset for this article
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN (
    'pending', 'in_progress', 'draft', 'review', 'published', 'archived'
  )),
  output_folder TEXT,
  output_files TEXT,       -- JSON array of {language, path, translated_at}
  sources_used TEXT,       -- JSON array of {url, title, summary, usage, accessed_at, type}
  companion_project TEXT,  -- JSON object (type, path, description, technologies, etc.)
  created_at TEXT DEFAULT (datetime('now')),
  written_at TEXT,
  published_at TEXT,
  updated_at TEXT DEFAULT (datetime('now')),
  error_note TEXT
);

-- Settings table (singleton)
CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY CHECK(id = 1) DEFAULT 1,
  article_limits TEXT DEFAULT '{"max_words":3000}',  -- JSON object
  companion_project_defaults TEXT NOT NULL,           -- JSON object
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Metadata table (singleton)
CREATE TABLE IF NOT EXISTS metadata (
  id INTEGER PRIMARY KEY CHECK(id = 1) DEFAULT 1,
  version TEXT NOT NULL DEFAULT '1.0.0',
  last_updated TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO metadata (id, version) VALUES (1, '1.0.0');

-- FTS5 virtual table for full-text search on articles
CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
  title,
  subject,
  tags,
  content='articles',
  content_rowid='id'
);

-- Triggers to keep FTS index in sync
CREATE TRIGGER IF NOT EXISTS articles_ai AFTER INSERT ON articles BEGIN
  INSERT INTO articles_fts(rowid, title, subject, tags)
  VALUES (new.id, new.title, new.subject, new.tags);
END;

CREATE TRIGGER IF NOT EXISTS articles_ad AFTER DELETE ON articles BEGIN
  INSERT INTO articles_fts(articles_fts, rowid, title, subject, tags)
  VALUES ('delete', old.id, old.title, old.subject, old.tags);
END;

CREATE TRIGGER IF NOT EXISTS articles_au AFTER UPDATE ON articles BEGIN
  INSERT INTO articles_fts(articles_fts, rowid, title, subject, tags)
  VALUES ('delete', old.id, old.title, old.subject, old.tags);
  INSERT INTO articles_fts(rowid, title, subject, tags)
  VALUES (new.id, new.title, new.subject, new.tags);
END;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_articles_status ON articles(status);
CREATE INDEX IF NOT EXISTS idx_articles_area ON articles(area);
CREATE INDEX IF NOT EXISTS idx_articles_difficulty ON articles(difficulty);
CREATE INDEX IF NOT EXISTS idx_articles_author_id ON articles(author_id);
CREATE INDEX IF NOT EXISTS idx_articles_estimated_effort ON articles(estimated_effort);
CREATE INDEX IF NOT EXISTS idx_authors_sort_order ON authors(sort_order);
