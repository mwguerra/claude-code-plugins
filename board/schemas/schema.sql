-- Board Advisory Council SQLite Schema v1.0.0
-- Persistent decision tracking, council performance, and outcome learning

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Decisions table - every deliberation
CREATE TABLE IF NOT EXISTS decisions (
    id TEXT PRIMARY KEY,                    -- "DEC-001", "DEC-002", ...
    question TEXT NOT NULL,                 -- Original question asked
    context TEXT,                           -- Additional context provided
    clean_problem TEXT,                     -- Council Head's neutral restatement
    decision_type TEXT NOT NULL DEFAULT 'general'
        CHECK (decision_type IN ('strategic', 'financial', 'career', 'technical', 'personal', 'risk', 'general')),
    urgency TEXT NOT NULL DEFAULT 'medium'
        CHECK (urgency IN ('low', 'medium', 'high', 'emergency')),
    mode TEXT NOT NULL DEFAULT 'standard'
        CHECK (mode IN ('standard', 'conflict', 'ultra', 'quick', 'premortem')),

    -- Council verdicts (JSON objects with verdict, reasoning, conditions, confidence)
    councils_consulted TEXT DEFAULT '[]',          -- JSON: which councils participated
    intelligence_verdict TEXT,                      -- JSON: {verdict, reasoning, risks, opportunities, confidence}
    business_verdict TEXT,                          -- JSON: {verdict, reasoning, risks, opportunities, confidence}
    life_verdict TEXT,                               -- JSON: {verdict, reasoning, risks, opportunities, confidence}
    security_verdict TEXT,                           -- JSON: {verdict, reasoning, risks, opportunities, confidence}

    -- Master synthesis
    consensus_points TEXT DEFAULT '[]',             -- JSON: where councils agree
    conflict_points TEXT DEFAULT '[]',              -- JSON: where councils disagree and why
    critical_tradeoffs TEXT DEFAULT '[]',           -- JSON: tradeoffs user must accept
    success_conditions TEXT DEFAULT '[]',           -- JSON: what must be true for success
    master_recommendation TEXT,                     -- Final recommendation text
    master_confidence TEXT DEFAULT 'medium'
        CHECK (master_confidence IN ('low', 'medium', 'high', 'very_high')),
    risk_level TEXT DEFAULT 'medium'
        CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
    next_action TEXT,                               -- Concrete first step

    -- Outcome tracking
    outcome TEXT
        CHECK (outcome IN ('success', 'partial', 'fail', 'pending', 'abandoned') OR outcome IS NULL),
    outcome_notes TEXT,                             -- What actually happened
    outcome_date TEXT,                              -- When outcome was recorded

    -- Council accuracy (set after outcome is recorded)
    intelligence_accurate INTEGER,                  -- 1=correct, 0=wrong, NULL=not applicable
    business_accurate INTEGER,
    life_accurate INTEGER,
    security_accurate INTEGER,

    -- Timestamps
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_decisions_type ON decisions(decision_type);
CREATE INDEX IF NOT EXISTS idx_decisions_outcome ON decisions(outcome);
CREATE INDEX IF NOT EXISTS idx_decisions_created ON decisions(created_at);

-- Reviews table - periodic CEO reviews
CREATE TABLE IF NOT EXISTS reviews (
    id TEXT PRIMARY KEY,                    -- "REV-001", "REV-002", ...
    review_type TEXT NOT NULL
        CHECK (review_type IN ('weekly', 'monthly', 'quarterly', 'compass')),
    period_start TEXT,                      -- ISO 8601
    period_end TEXT,                        -- ISO 8601
    content TEXT NOT NULL,                  -- Full review content (markdown)
    insights TEXT DEFAULT '[]',             -- JSON: key insights discovered
    action_items TEXT DEFAULT '[]',         -- JSON: concrete next steps
    decisions_reviewed TEXT DEFAULT '[]',   -- JSON: decision IDs covered
    patterns_identified TEXT DEFAULT '[]',  -- JSON: patterns found

    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_reviews_type ON reviews(review_type);
CREATE INDEX IF NOT EXISTS idx_reviews_created ON reviews(created_at);

-- Config table - key-value settings
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Council stats - aggregate performance per council
CREATE TABLE IF NOT EXISTS council_stats (
    council TEXT PRIMARY KEY
        CHECK (council IN ('intelligence', 'business', 'life', 'security')),
    total_consultations INTEGER DEFAULT 0,
    correct_predictions INTEGER DEFAULT 0,
    accuracy_rate REAL DEFAULT 0.0,
    strongest_types TEXT DEFAULT '[]',      -- JSON: decision types where most accurate
    weakest_types TEXT DEFAULT '[]',        -- JSON: decision types where least accurate
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Initialize council stats
INSERT OR IGNORE INTO council_stats (council) VALUES ('intelligence');
INSERT OR IGNORE INTO council_stats (council) VALUES ('business');
INSERT OR IGNORE INTO council_stats (council) VALUES ('life');
INSERT OR IGNORE INTO council_stats (council) VALUES ('security');

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO schema_version (version) VALUES ('1.0.0');
