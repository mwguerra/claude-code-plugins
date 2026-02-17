#!/usr/bin/env bun
/**
 * Shared database module for article-writer plugin.
 * Provides database initialization, connection management, and
 * serialization helpers for the SQLite backend.
 */

import { Database } from "bun:sqlite";
import { existsSync, readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export const PLUGIN_ROOT = process.env.CLAUDE_PLUGIN_ROOT || dirname(__dirname);
export const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();
export const CONFIG_DIR = join(PROJECT_ROOT, ".article_writer");
export const DB_PATH = join(CONFIG_DIR, "article_writer.db");
export const CONTENT_DIR = join(PROJECT_ROOT, "content/articles");
export const DOCS_DIR = join(PROJECT_ROOT, "docs");
export const SCHEMAS_DIR = join(CONFIG_DIR, "schemas");

/**
 * Check if the database file exists.
 */
export function dbExists(): boolean {
  return existsSync(DB_PATH);
}

/**
 * Open the database with WAL mode and foreign keys enabled.
 * Applies any pending migrations automatically.
 */
export function getDb(): Database {
  const db = new Database(DB_PATH);
  db.run("PRAGMA journal_mode = WAL");
  db.run("PRAGMA foreign_keys = ON");
  applyPendingMigrations(db);
  return db;
}

// ============================================
// Schema Migrations
// ============================================

/**
 * Compare two semver strings ("X.Y.Z"). Returns -1, 0, or 1.
 */
function semverCompare(a: string, b: string): number {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) < (pb[i] || 0)) return -1;
    if ((pa[i] || 0) > (pb[i] || 0)) return 1;
  }
  return 0;
}

/**
 * Get the current schema version from the database.
 */
function getCurrentSchemaVersion(db: Database): string {
  try {
    const row = db.query("SELECT MAX(version) as version FROM schema_version").get() as any;
    return row?.version || "1.0.0";
  } catch {
    return "1.0.0";
  }
}

/**
 * Migration to 1.1.0: Add social media platform support.
 */
function migrate_1_1_0(db: Database): void {
  // Check if columns already exist (idempotent)
  const tableInfo = db.query("PRAGMA table_info(articles)").all() as any[];
  const existingColumns = tableInfo.map((col: any) => col.name);

  if (!existingColumns.includes("platform")) {
    db.run("ALTER TABLE articles ADD COLUMN platform TEXT NOT NULL DEFAULT 'blog'");
  }
  if (!existingColumns.includes("derived_from")) {
    db.run("ALTER TABLE articles ADD COLUMN derived_from INTEGER REFERENCES articles(id)");
  }
  if (!existingColumns.includes("platform_data")) {
    db.run("ALTER TABLE articles ADD COLUMN platform_data TEXT");
  }

  // Check settings table
  const settingsInfo = db.query("PRAGMA table_info(settings)").all() as any[];
  const settingsCols = settingsInfo.map((col: any) => col.name);

  if (!settingsCols.includes("platform_defaults")) {
    db.run("ALTER TABLE settings ADD COLUMN platform_defaults TEXT DEFAULT '{}'");
  }

  // Create indexes (IF NOT EXISTS is safe to repeat)
  db.run("CREATE INDEX IF NOT EXISTS idx_articles_platform ON articles(platform)");
  db.run("CREATE INDEX IF NOT EXISTS idx_articles_derived_from ON articles(derived_from)");

  // Record version
  db.run("INSERT OR IGNORE INTO schema_version (version) VALUES ('1.1.0')");

  // Update metadata version
  db.run("UPDATE metadata SET version = '1.1.0' WHERE id = 1 AND version = '1.0.0'");
}

/**
 * Registry of migrations keyed by target version.
 */
const MIGRATIONS: { version: string; apply: (db: Database) => void }[] = [
  { version: "1.1.0", apply: migrate_1_1_0 },
];

/**
 * Apply all pending migrations in order.
 */
function applyPendingMigrations(db: Database): void {
  const currentVersion = getCurrentSchemaVersion(db);

  for (const migration of MIGRATIONS) {
    if (semverCompare(currentVersion, migration.version) < 0) {
      migration.apply(db);
    }
  }
}

/**
 * Initialize the database from schema.sql and insert default settings.
 */
export function initDb(): Database {
  const db = new Database(DB_PATH, { create: true });
  db.run("PRAGMA journal_mode = WAL");
  db.run("PRAGMA foreign_keys = ON");

  const schemaPath = join(PLUGIN_ROOT, "schemas", "schema.sql");
  const schema = readFileSync(schemaPath, "utf-8");

  // Execute schema statements (split on semicolons, skip empty)
  db.exec(schema);

  return db;
}

/**
 * Insert default settings into the settings table.
 */
export function insertDefaultSettings(db: Database): void {
  const samplePath = join(PLUGIN_ROOT, "schemas", "settings.sample.json");
  let defaults: any;

  if (existsSync(samplePath)) {
    defaults = JSON.parse(readFileSync(samplePath, "utf-8"));
  } else {
    // Fallback minimal defaults
    defaults = {
      article_limits: { max_words: 3000 },
      companion_project_defaults: {},
    };
  }

  const articleLimits = JSON.stringify(defaults.article_limits || { max_words: 3000 });
  const companionDefaults = JSON.stringify(defaults.companion_project_defaults || {});
  const platformDefaults = JSON.stringify(defaults.platform_defaults || {});

  db.run(
    `INSERT OR REPLACE INTO settings (id, article_limits, companion_project_defaults, platform_defaults, updated_at)
     VALUES (1, ?, ?, ?, datetime('now'))`,
    [articleLimits, companionDefaults, platformDefaults]
  );
}

/**
 * Get the default author (lowest sort_order).
 */
export function getDefaultAuthor(db: Database): any | null {
  const row = db.query("SELECT * FROM authors ORDER BY sort_order ASC LIMIT 1").get() as any;
  return row ? rowToAuthor(row) : null;
}

/**
 * Get settings from the singleton row.
 */
export function getSettings(db: Database): any | null {
  const row = db.query("SELECT * FROM settings WHERE id = 1").get() as any;
  if (!row) return null;
  return {
    article_limits: JSON.parse(row.article_limits || "{}"),
    companion_project_defaults: JSON.parse(row.companion_project_defaults || "{}"),
    platform_defaults: safeParseJson(row.platform_defaults, {}),
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

/**
 * Touch metadata.last_updated to current time.
 */
export function touchMetadata(db: Database): void {
  db.run("UPDATE metadata SET last_updated = datetime('now') WHERE id = 1");
}

// ============================================
// Author serialization
// ============================================

/**
 * Convert an author object (from JSON) to a flat row for INSERT.
 */
export function authorToRow(author: any, sortOrder: number = 0): any {
  return {
    id: author.id,
    name: author.name,
    languages: JSON.stringify(author.languages || []),
    role: author.role !== undefined ? JSON.stringify(author.role) : null,
    experience: author.experience !== undefined ? JSON.stringify(author.experience) : null,
    expertise: author.expertise !== undefined ? JSON.stringify(author.expertise) : null,
    tone_formality: author.tone?.formality ?? null,
    tone_opinionated: author.tone?.opinionated ?? null,
    vocabulary: author.vocabulary ? JSON.stringify(author.vocabulary) : null,
    phrases: author.phrases ? JSON.stringify(author.phrases) : null,
    opinions: author.opinions ? JSON.stringify(author.opinions) : null,
    example_voice: author.example_voice || null,
    voice_analysis: author.voice_analysis ? JSON.stringify(author.voice_analysis) : null,
    notes: author.notes !== undefined ? JSON.stringify(author.notes) : null,
    sort_order: sortOrder,
  };
}

/**
 * Convert a database row to an author object.
 */
export function rowToAuthor(row: any): any {
  const author: any = {
    id: row.id,
    name: row.name,
    languages: safeParseJson(row.languages, []),
  };

  if (row.role) author.role = safeParseJson(row.role);
  if (row.experience) author.experience = safeParseJson(row.experience);
  if (row.expertise) author.expertise = safeParseJson(row.expertise);

  if (row.tone_formality !== null || row.tone_opinionated !== null) {
    author.tone = {};
    if (row.tone_formality !== null) author.tone.formality = row.tone_formality;
    if (row.tone_opinionated !== null) author.tone.opinionated = row.tone_opinionated;
  }

  if (row.vocabulary) author.vocabulary = safeParseJson(row.vocabulary);
  if (row.phrases) author.phrases = safeParseJson(row.phrases);
  if (row.opinions) author.opinions = safeParseJson(row.opinions);
  if (row.example_voice) author.example_voice = row.example_voice;
  if (row.voice_analysis) author.voice_analysis = safeParseJson(row.voice_analysis);
  if (row.notes) author.notes = safeParseJson(row.notes);

  return author;
}

// ============================================
// Article serialization
// ============================================

/**
 * Convert an article object (from JSON) to a flat row for INSERT.
 */
export function articleToRow(article: any): any {
  return {
    id: article.id,
    title: article.title,
    subject: article.subject,
    area: article.area,
    tags: article.tags,
    difficulty: article.difficulty,
    relevance: article.relevance,
    content_type: article.content_type,
    estimated_effort: article.estimated_effort,
    versions: article.versions,
    series_potential: article.series_potential,
    prerequisites: article.prerequisites,
    reference_urls: article.reference_urls,
    author_id: article.author?.id || null,
    author_name: article.author?.name || null,
    author_languages: article.author?.languages ? JSON.stringify(article.author.languages) : null,
    status: article.status || "pending",
    platform: article.platform || "blog",
    derived_from: article.derived_from || null,
    platform_data: article.platform_data ? JSON.stringify(article.platform_data) : null,
    output_folder: article.output_folder || null,
    output_files: article.output_files ? JSON.stringify(article.output_files) : null,
    sources_used: article.sources_used ? JSON.stringify(article.sources_used) : null,
    companion_project: article.companion_project ? JSON.stringify(article.companion_project) : null,
    created_at: article.created_at || null,
    written_at: article.written_at || null,
    published_at: article.published_at || null,
    updated_at: article.updated_at || null,
    error_note: article.error_note || null,
  };
}

/**
 * Convert a database row to an article object.
 */
export function rowToArticle(row: any): any {
  const article: any = {
    id: row.id,
    title: row.title,
    subject: row.subject,
    area: row.area,
    tags: row.tags,
    difficulty: row.difficulty,
    relevance: row.relevance,
    content_type: row.content_type,
    estimated_effort: row.estimated_effort,
    versions: row.versions,
    series_potential: row.series_potential,
    prerequisites: row.prerequisites,
    reference_urls: row.reference_urls,
    status: row.status,
  };

  // Platform fields
  article.platform = row.platform || "blog";
  if (row.derived_from) article.derived_from = row.derived_from;
  if (row.platform_data) article.platform_data = safeParseJson(row.platform_data);

  // Reconstruct author reference
  if (row.author_id) {
    article.author = { id: row.author_id };
    if (row.author_name) article.author.name = row.author_name;
    if (row.author_languages) article.author.languages = safeParseJson(row.author_languages, []);
  }

  if (row.output_folder) article.output_folder = row.output_folder;
  if (row.output_files) article.output_files = safeParseJson(row.output_files, []);
  if (row.sources_used) article.sources_used = safeParseJson(row.sources_used, []);
  if (row.companion_project) article.companion_project = safeParseJson(row.companion_project);
  if (row.created_at) article.created_at = row.created_at;
  if (row.written_at) article.written_at = row.written_at;
  if (row.published_at) article.published_at = row.published_at;
  if (row.updated_at) article.updated_at = row.updated_at;
  if (row.error_note) article.error_note = row.error_note;

  return article;
}

// ============================================
// Platform Helpers
// ============================================

/** Valid platform values */
export const VALID_PLATFORMS = ["blog", "linkedin", "instagram", "x"] as const;
export type Platform = (typeof VALID_PLATFORMS)[number];

/**
 * Get defaults for a specific platform from settings.
 */
export function getPlatformDefaults(db: Database, platform: string): any {
  const settings = getSettings(db);
  if (!settings?.platform_defaults) return null;
  return settings.platform_defaults[platform] || null;
}

/**
 * Compute effective tone by applying platform offset to author's base tone.
 * Result is clamped to [1, 10].
 */
export function getEffectiveTone(
  author: { tone?: { formality?: number; opinionated?: number } },
  platformDefaults: { tone_adjustment?: { formality_offset?: number; opinionated_offset?: number } } | null
): { formality: number; opinionated: number } {
  const baseFormality = author.tone?.formality ?? 5;
  const baseOpinionated = author.tone?.opinionated ?? 5;

  const fOffset = platformDefaults?.tone_adjustment?.formality_offset ?? 0;
  const oOffset = platformDefaults?.tone_adjustment?.opinionated_offset ?? 0;

  return {
    formality: Math.max(1, Math.min(10, baseFormality + fOffset)),
    opinionated: Math.max(1, Math.min(10, baseOpinionated + oOffset)),
  };
}

// ============================================
// Helpers
// ============================================

function safeParseJson(value: string | null | undefined, fallback?: any): any {
  if (value === null || value === undefined) return fallback ?? null;
  try {
    return JSON.parse(value);
  } catch {
    return fallback ?? value;
  }
}
