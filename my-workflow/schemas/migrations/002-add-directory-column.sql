-- Migration 002: Add directory column to sessions table
-- This enables proper session cleanup by tracking the working directory

-- Add directory column if it doesn't exist
-- SQLite doesn't support IF NOT EXISTS for ALTER TABLE, so we check first
SELECT CASE
    WHEN COUNT(*) = 0 THEN 'ALTER TABLE sessions ADD COLUMN directory TEXT'
    ELSE 'SELECT 1'
END
FROM pragma_table_info('sessions')
WHERE name = 'directory';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_sessions_directory ON sessions(directory);

-- Update schema version
INSERT OR REPLACE INTO schema_version (id, version, applied_at)
VALUES (1, '002', datetime('now'));
