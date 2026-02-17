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
 */
export function getDb(): Database {
  const db = new Database(DB_PATH);
  db.run("PRAGMA journal_mode = WAL");
  db.run("PRAGMA foreign_keys = ON");
  return db;
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

  db.run(
    `INSERT OR REPLACE INTO settings (id, article_limits, companion_project_defaults, updated_at)
     VALUES (1, ?, ?, datetime('now'))`,
    [articleLimits, companionDefaults]
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
