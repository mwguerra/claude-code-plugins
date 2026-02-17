-- Migration from 1.0.0 to 1.1.0
-- Adds social media platform support (LinkedIn, Instagram, X/Twitter)

-- Add platform column to articles (defaults to 'blog' for existing rows)
ALTER TABLE articles ADD COLUMN platform TEXT NOT NULL DEFAULT 'blog';

-- Add derived_from foreign key for posts derived from blog articles
ALTER TABLE articles ADD COLUMN derived_from INTEGER REFERENCES articles(id);

-- Add platform_data for platform-specific structured content (JSON)
ALTER TABLE articles ADD COLUMN platform_data TEXT;

-- Add platform_defaults to settings (JSON)
ALTER TABLE settings ADD COLUMN platform_defaults TEXT DEFAULT '{}';

-- Indexes for new columns
CREATE INDEX IF NOT EXISTS idx_articles_platform ON articles(platform);
CREATE INDEX IF NOT EXISTS idx_articles_derived_from ON articles(derived_from);

-- Record schema version
INSERT OR IGNORE INTO schema_version (version) VALUES ('1.1.0');
