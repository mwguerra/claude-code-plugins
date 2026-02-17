#!/usr/bin/env bun
/**
 * Initialize article-writer in the current project.
 * Creates .article_writer folder with SQLite database and schema files.
 * Completes missing items without deleting existing data.
 *
 * Usage: bun run init.ts [options]
 *
 * Options:
 *   --check          Only check what's missing, don't create
 *   --author <json>  Create author from JSON string
 */

import { mkdir, copyFile, readFile, writeFile, stat } from "fs/promises";
import { existsSync } from "fs";
import { join } from "path";
import {
  PLUGIN_ROOT, CONFIG_DIR, SCHEMAS_DIR, CONTENT_DIR, DOCS_DIR, DB_PATH,
  dbExists, initDb, insertDefaultSettings, getDb,
  authorToRow,
} from "./db";

interface InitStatus {
  configDirExists: boolean;
  schemasDirExists: boolean;
  contentDirExists: boolean;
  docsDirExists: boolean;
  tasksSchemaExists: boolean;
  authorsSchemaExists: boolean;
  settingsSchemaExists: boolean;
  dbFileExists: boolean;
  jsonFilesExist: boolean;
  missingItems: string[];
  existingItems: string[];
}

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function checkStatus(): Promise<InitStatus> {
  const status: InitStatus = {
    configDirExists: await exists(CONFIG_DIR),
    schemasDirExists: await exists(SCHEMAS_DIR),
    contentDirExists: await exists(CONTENT_DIR),
    docsDirExists: await exists(DOCS_DIR),
    tasksSchemaExists: await exists(join(SCHEMAS_DIR, "article-tasks.schema.json")),
    authorsSchemaExists: await exists(join(SCHEMAS_DIR, "authors.schema.json")),
    settingsSchemaExists: await exists(join(SCHEMAS_DIR, "settings.schema.json")),
    dbFileExists: dbExists(),
    jsonFilesExist: await exists(join(CONFIG_DIR, "article_tasks.json")) ||
                    await exists(join(CONFIG_DIR, "authors.json")) ||
                    await exists(join(CONFIG_DIR, "settings.json")),
    missingItems: [],
    existingItems: [],
  };

  if (!status.configDirExists) status.missingItems.push(CONFIG_DIR);
  else status.existingItems.push(CONFIG_DIR);

  if (!status.schemasDirExists) status.missingItems.push(SCHEMAS_DIR);
  else status.existingItems.push(SCHEMAS_DIR);

  if (!status.contentDirExists) status.missingItems.push(CONTENT_DIR);
  else status.existingItems.push(CONTENT_DIR);

  if (!status.docsDirExists) status.missingItems.push(DOCS_DIR);
  else status.existingItems.push(DOCS_DIR);

  if (!status.tasksSchemaExists) status.missingItems.push("schemas/article-tasks.schema.json");
  else status.existingItems.push("schemas/article-tasks.schema.json");

  if (!status.authorsSchemaExists) status.missingItems.push("schemas/authors.schema.json");
  else status.existingItems.push("schemas/authors.schema.json");

  if (!status.settingsSchemaExists) status.missingItems.push("schemas/settings.schema.json");
  else status.existingItems.push("schemas/settings.schema.json");

  if (!status.dbFileExists) status.missingItems.push("article_writer.db");
  else status.existingItems.push("article_writer.db");

  return status;
}

async function copySchema(filename: string, destDir: string): Promise<boolean> {
  const source = join(PLUGIN_ROOT, "schemas", filename);
  const dest = join(destDir, filename);

  try {
    await copyFile(source, dest);
    return true;
  } catch {
    try {
      const content = await readFile(source, "utf-8");
      await writeFile(dest, content);
      return true;
    } catch {
      console.error(`   ✗ Could not copy ${filename}`);
      return false;
    }
  }
}

async function addAuthor(authorJson: string): Promise<void> {
  if (!dbExists()) {
    console.error("❌ Database not found. Run /article-writer:init first.");
    process.exit(1);
  }

  const newAuthor = JSON.parse(authorJson);
  const db = getDb();

  // Check if author exists
  const existing = db.query("SELECT id FROM authors WHERE id = ?").get(newAuthor.id) as any;

  // Get next sort_order
  const maxOrder = (db.query("SELECT MAX(sort_order) as m FROM authors").get() as any)?.m ?? -1;
  const sortOrder = existing ? (db.query("SELECT sort_order FROM authors WHERE id = ?").get(newAuthor.id) as any).sort_order : maxOrder + 1;

  const row = authorToRow(newAuthor, sortOrder);

  db.run(`
    INSERT OR REPLACE INTO authors (id, name, languages, role, experience, expertise,
      tone_formality, tone_opinionated, vocabulary, phrases, opinions,
      example_voice, voice_analysis, notes, sort_order, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
  `, [
    row.id, row.name, row.languages, row.role, row.experience, row.expertise,
    row.tone_formality, row.tone_opinionated, row.vocabulary, row.phrases, row.opinions,
    row.example_voice, row.voice_analysis, row.notes, row.sort_order,
  ]);

  if (existing) {
    console.log(`✅ Updated existing author: ${newAuthor.name} (${newAuthor.id})`);
  } else {
    console.log(`✅ Added new author: ${newAuthor.name} (${newAuthor.id})`);
  }

  db.close();
}

async function init(checkOnly: boolean = false): Promise<void> {
  console.log("\n🚀 Article Writer Initialization\n");

  const status = await checkStatus();

  // Report existing items
  if (status.existingItems.length > 0) {
    console.log("✅ Already exists (will not modify):");
    for (const item of status.existingItems) {
      console.log(`   • ${item}`);
    }
    console.log("");
  }

  // Detect existing JSON files and suggest migration
  if (status.jsonFilesExist && !status.dbFileExists) {
    console.log("⚠️  Existing JSON files detected.");
    console.log("   Run: bun run \"${CLAUDE_PLUGIN_ROOT}\"/scripts/migrate.ts");
    console.log("   to migrate data to SQLite.\n");
  }

  // Report missing items
  if (status.missingItems.length === 0) {
    console.log("✅ Article Writer is fully initialized!\n");

    // Check if authors table has any authors
    if (status.dbFileExists) {
      try {
        const db = getDb();
        const count = (db.query("SELECT COUNT(*) as c FROM authors").get() as any).c;
        if (count === 0) {
          console.log("⚠️  No authors configured yet.");
          console.log("   Run /article-writer:author add to create your first author.\n");
        } else {
          console.log(`📝 ${count} author(s) configured.`);
          console.log("   Run /article-writer:author list to see them.\n");
        }
        db.close();
      } catch {}
    }

    return;
  }

  console.log("📋 Missing items to create:");
  for (const item of status.missingItems) {
    console.log(`   • ${item}`);
  }
  console.log("");

  if (checkOnly) {
    console.log("Run without --check to create missing items.\n");
    return;
  }

  // Create missing directories
  console.log("📁 Creating directories...");
  if (!status.configDirExists || !status.schemasDirExists) {
    await mkdir(SCHEMAS_DIR, { recursive: true });
    console.log(`   ✓ ${SCHEMAS_DIR}/`);
  }
  if (!status.contentDirExists) {
    await mkdir(CONTENT_DIR, { recursive: true });
    console.log(`   ✓ ${CONTENT_DIR}/`);
  }
  if (!status.docsDirExists) {
    await mkdir(DOCS_DIR, { recursive: true });
    console.log(`   ✓ ${DOCS_DIR}/`);
  }

  // Copy schema files (documentation reference)
  console.log("\n📋 Setting up schema files...");
  if (!status.tasksSchemaExists) {
    if (await copySchema("article-tasks.schema.json", SCHEMAS_DIR)) {
      console.log("   ✓ article-tasks.schema.json");
    }
  }
  if (!status.authorsSchemaExists) {
    if (await copySchema("authors.schema.json", SCHEMAS_DIR)) {
      console.log("   ✓ authors.schema.json");
    }
  }
  if (!status.settingsSchemaExists) {
    if (await copySchema("settings.schema.json", SCHEMAS_DIR)) {
      console.log("   ✓ settings.schema.json");
    }
  }

  // Create database
  if (!status.dbFileExists) {
    console.log("\n💾 Creating database...");
    const db = initDb();
    insertDefaultSettings(db);
    db.close();
    console.log("   ✓ article_writer.db (with default settings)");
  }

  // Summary
  console.log("\n" + "─".repeat(50));
  console.log("✅ Article Writer initialized!\n");
  console.log("Next step: Create your first author profile:");
  console.log("   /article-writer:author add\n");
}

// Parse arguments
const args = process.argv.slice(2);
const checkOnly = args.includes("--check");
const authorIndex = args.indexOf("--author");

if (authorIndex >= 0 && args[authorIndex + 1]) {
  await addAuthor(args[authorIndex + 1]);
} else {
  await init(checkOnly);
}
