#!/usr/bin/env bun
/**
 * Migrate article-writer data from JSON files to SQLite database.
 *
 * Usage:
 *   bun run migrate.ts             # Run migration
 *   bun run migrate.ts --check     # Dry-run: show what would migrate
 *   bun run migrate.ts --rollback  # Undo migration: restore JSON files, remove db
 */

import { existsSync, readFileSync, renameSync, unlinkSync, copyFileSync } from "fs";
import { join } from "path";
import {
  CONFIG_DIR, DB_PATH, PLUGIN_ROOT,
  initDb, insertDefaultSettings, touchMetadata,
  authorToRow, articleToRow,
} from "./db";

const JSON_FILES = {
  tasks: join(CONFIG_DIR, "article_tasks.json"),
  authors: join(CONFIG_DIR, "authors.json"),
  settings: join(CONFIG_DIR, "settings.json"),
};

const MIGRATED_SUFFIX = ".migrated";

function migratedPath(path: string): string {
  return path + MIGRATED_SUFFIX;
}

// ============================================
// Detect state
// ============================================

function detectState(): {
  hasDb: boolean;
  hasJson: Record<string, boolean>;
  hasMigrated: Record<string, boolean>;
} {
  return {
    hasDb: existsSync(DB_PATH),
    hasJson: {
      tasks: existsSync(JSON_FILES.tasks),
      authors: existsSync(JSON_FILES.authors),
      settings: existsSync(JSON_FILES.settings),
    },
    hasMigrated: {
      tasks: existsSync(migratedPath(JSON_FILES.tasks)),
      authors: existsSync(migratedPath(JSON_FILES.authors)),
      settings: existsSync(migratedPath(JSON_FILES.settings)),
    },
  };
}

// ============================================
// Check mode
// ============================================

function check(): void {
  const state = detectState();

  console.log("\n🔍 Migration Check (dry-run)\n");

  if (state.hasDb) {
    console.log("  ✓ Database already exists: article_writer.db");
  } else {
    console.log("  ○ Database does not exist (will be created)");
  }

  console.log("");

  for (const [key, path] of Object.entries(JSON_FILES)) {
    const hasJson = state.hasJson[key];
    const hasMigrated = state.hasMigrated[key];

    if (hasJson) {
      try {
        const data = JSON.parse(readFileSync(path, "utf-8"));
        const count = key === "tasks"
          ? (data.articles || data || []).length
          : key === "authors"
          ? (data.authors || []).length
          : 1;
        console.log(`  ○ ${key}: ${count} record(s) to migrate from ${path}`);
      } catch {
        console.log(`  ⚠ ${key}: exists but could not be parsed`);
      }
    } else if (hasMigrated) {
      console.log(`  ✓ ${key}: already migrated (${migratedPath(path)} exists)`);
    } else {
      console.log(`  - ${key}: not found (empty table will be created)`);
    }
  }

  console.log("\n  Run without --check to perform migration.\n");
}

// ============================================
// Rollback mode
// ============================================

function rollback(): void {
  const state = detectState();

  console.log("\n🔄 Rolling back migration...\n");

  let restored = 0;

  for (const [key, path] of Object.entries(JSON_FILES)) {
    const mp = migratedPath(path);
    if (state.hasMigrated[key]) {
      renameSync(mp, path);
      console.log(`  ✓ Restored: ${path}`);
      restored++;
    } else if (state.hasJson[key]) {
      console.log(`  ⏭ ${key}: JSON file already exists`);
    } else {
      console.log(`  - ${key}: no backup to restore`);
    }
  }

  if (state.hasDb) {
    unlinkSync(DB_PATH);
    // Also remove WAL/SHM files if present
    const walPath = DB_PATH + "-wal";
    const shmPath = DB_PATH + "-shm";
    if (existsSync(walPath)) unlinkSync(walPath);
    if (existsSync(shmPath)) unlinkSync(shmPath);
    console.log(`  ✓ Removed: article_writer.db`);
  }

  console.log(`\n✅ Rollback complete. Restored ${restored} file(s).\n`);
}

// ============================================
// Migration
// ============================================

function migrate(): void {
  const state = detectState();

  console.log("\n🚀 Migrating article-writer from JSON to SQLite...\n");

  // Check if already migrated
  if (state.hasDb && !state.hasJson.tasks && !state.hasJson.authors && !state.hasJson.settings) {
    console.log("  ✅ Already migrated. Database exists and no JSON files found.\n");
    return;
  }

  // Check if any JSON files exist to migrate
  const hasAnyJson = Object.values(state.hasJson).some(Boolean);
  if (!hasAnyJson) {
    console.log("  ⚠ No JSON files found to migrate.");
    console.log("  Run /article-writer:init to create a fresh database.\n");
    return;
  }

  // Phase 1: Read JSON files
  console.log("📖 Phase 1: Reading JSON files...");

  let authorsData: any[] = [];
  let articlesData: any[] = [];
  let settingsData: any = null;

  if (state.hasJson.authors) {
    try {
      const raw = JSON.parse(readFileSync(JSON_FILES.authors, "utf-8"));
      authorsData = raw.authors || [];
      console.log(`  ✓ authors.json: ${authorsData.length} author(s)`);
    } catch (e: any) {
      console.error(`  ✗ Failed to parse authors.json: ${e.message}`);
      process.exit(1);
    }
  }

  if (state.hasJson.tasks) {
    try {
      const raw = JSON.parse(readFileSync(JSON_FILES.tasks, "utf-8"));
      articlesData = raw.articles || (Array.isArray(raw) ? raw : []);
      console.log(`  ✓ article_tasks.json: ${articlesData.length} article(s)`);
    } catch (e: any) {
      console.error(`  ✗ Failed to parse article_tasks.json: ${e.message}`);
      process.exit(1);
    }
  }

  if (state.hasJson.settings) {
    try {
      settingsData = JSON.parse(readFileSync(JSON_FILES.settings, "utf-8"));
      console.log(`  ✓ settings.json: loaded`);
    } catch (e: any) {
      console.error(`  ✗ Failed to parse settings.json: ${e.message}`);
      process.exit(1);
    }
  }

  // Phase 2: Create database
  console.log("\n📦 Phase 2: Creating database...");

  // Remove existing db if present (fresh migration)
  if (state.hasDb) {
    // Backup existing db first
    const backupPath = DB_PATH + ".pre-migration";
    copyFileSync(DB_PATH, backupPath);
    console.log(`  ⚠ Existing db backed up to: article_writer.db.pre-migration`);
    unlinkSync(DB_PATH);
    const walPath = DB_PATH + "-wal";
    const shmPath = DB_PATH + "-shm";
    if (existsSync(walPath)) unlinkSync(walPath);
    if (existsSync(shmPath)) unlinkSync(shmPath);
  }

  const db = initDb();
  console.log(`  ✓ Database created: article_writer.db`);

  // Phase 3: Insert authors
  console.log("\n👤 Phase 3: Inserting authors...");

  const insertAuthor = db.prepare(`
    INSERT INTO authors (id, name, languages, role, experience, expertise,
      tone_formality, tone_opinionated, vocabulary, phrases, opinions,
      example_voice, voice_analysis, notes, sort_order, created_at, updated_at)
    VALUES ($id, $name, $languages, $role, $experience, $expertise,
      $tone_formality, $tone_opinionated, $vocabulary, $phrases, $opinions,
      $example_voice, $voice_analysis, $notes, $sort_order, datetime('now'), datetime('now'))
  `);

  const insertAuthorsTransaction = db.transaction(() => {
    for (let i = 0; i < authorsData.length; i++) {
      const row = authorToRow(authorsData[i], i);
      insertAuthor.run({
        $id: row.id,
        $name: row.name,
        $languages: row.languages,
        $role: row.role,
        $experience: row.experience,
        $expertise: row.expertise,
        $tone_formality: row.tone_formality,
        $tone_opinionated: row.tone_opinionated,
        $vocabulary: row.vocabulary,
        $phrases: row.phrases,
        $opinions: row.opinions,
        $example_voice: row.example_voice,
        $voice_analysis: row.voice_analysis,
        $notes: row.notes,
        $sort_order: row.sort_order,
      });
    }
  });

  insertAuthorsTransaction();
  console.log(`  ✓ Inserted ${authorsData.length} author(s)`);

  // Phase 4: Insert settings
  console.log("\n⚙️  Phase 4: Inserting settings...");

  if (settingsData) {
    const articleLimits = JSON.stringify(settingsData.article_limits || { max_words: 3000 });
    const companionDefaults = JSON.stringify(settingsData.companion_project_defaults || {});

    db.run(
      `INSERT OR REPLACE INTO settings (id, article_limits, companion_project_defaults, updated_at)
       VALUES (1, ?, ?, datetime('now'))`,
      [articleLimits, companionDefaults]
    );
    console.log(`  ✓ Settings inserted`);
  } else {
    insertDefaultSettings(db);
    console.log(`  ✓ Default settings inserted`);
  }

  // Phase 5: Insert articles
  console.log("\n📝 Phase 5: Inserting articles...");

  const insertArticle = db.prepare(`
    INSERT INTO articles (id, title, subject, area, tags, difficulty, relevance,
      content_type, estimated_effort, versions, series_potential, prerequisites,
      reference_urls, author_id, author_name, author_languages, status,
      output_folder, output_files, sources_used, companion_project,
      created_at, written_at, published_at, updated_at, error_note)
    VALUES ($id, $title, $subject, $area, $tags, $difficulty, $relevance,
      $content_type, $estimated_effort, $versions, $series_potential, $prerequisites,
      $reference_urls, $author_id, $author_name, $author_languages, $status,
      $output_folder, $output_files, $sources_used, $companion_project,
      $created_at, $written_at, $published_at, $updated_at, $error_note)
  `);

  let articleErrors = 0;
  const insertArticlesTransaction = db.transaction(() => {
    for (const article of articlesData) {
      try {
        const row = articleToRow(article);
        insertArticle.run({
          $id: row.id,
          $title: row.title,
          $subject: row.subject,
          $area: row.area,
          $tags: row.tags,
          $difficulty: row.difficulty,
          $relevance: row.relevance,
          $content_type: row.content_type,
          $estimated_effort: row.estimated_effort,
          $versions: row.versions,
          $series_potential: row.series_potential,
          $prerequisites: row.prerequisites,
          $reference_urls: row.reference_urls,
          $author_id: row.author_id,
          $author_name: row.author_name,
          $author_languages: row.author_languages,
          $status: row.status,
          $output_folder: row.output_folder,
          $output_files: row.output_files,
          $sources_used: row.sources_used,
          $companion_project: row.companion_project,
          $created_at: row.created_at,
          $written_at: row.written_at,
          $published_at: row.published_at,
          $updated_at: row.updated_at,
          $error_note: row.error_note,
        });
      } catch (e: any) {
        console.error(`  ✗ Article #${article.id}: ${e.message}`);
        articleErrors++;
      }
    }
  });

  insertArticlesTransaction();
  console.log(`  ✓ Inserted ${articlesData.length - articleErrors} article(s)${articleErrors > 0 ? ` (${articleErrors} errors)` : ""}`);

  // Phase 6: Verify counts
  console.log("\n✅ Phase 6: Verifying...");

  const dbAuthors = (db.query("SELECT COUNT(*) as count FROM authors").get() as any).count;
  const dbArticles = (db.query("SELECT COUNT(*) as count FROM articles").get() as any).count;
  const dbSettings = (db.query("SELECT COUNT(*) as count FROM settings").get() as any).count;

  const authorsMatch = dbAuthors === authorsData.length;
  const articlesMatch = dbArticles === (articlesData.length - articleErrors);

  console.log(`  Authors:  ${dbAuthors}/${authorsData.length} ${authorsMatch ? "✓" : "⚠"}`);
  console.log(`  Articles: ${dbArticles}/${articlesData.length} ${articlesMatch ? "✓" : "⚠"}`);
  console.log(`  Settings: ${dbSettings} ✓`);

  touchMetadata(db);
  db.close();

  // Phase 7: Rename JSON files
  console.log("\n📁 Phase 7: Archiving JSON files...");

  for (const [key, path] of Object.entries(JSON_FILES)) {
    if (existsSync(path)) {
      const dest = migratedPath(path);
      renameSync(path, dest);
      console.log(`  ✓ ${path} → ${dest}`);
    }
  }

  console.log("\n" + "─".repeat(50));
  console.log("✅ Migration complete!");
  console.log(`   Database: ${DB_PATH}`);
  console.log(`   Original JSON files renamed to *.json.migrated`);
  console.log(`   To undo: bun run migrate.ts --rollback\n`);
}

// ============================================
// Main
// ============================================

const args = process.argv.slice(2);

if (args.includes("--check")) {
  check();
} else if (args.includes("--rollback")) {
  rollback();
} else {
  migrate();
}
