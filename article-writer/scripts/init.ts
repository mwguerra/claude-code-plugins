#!/usr/bin/env bun
/**
 * Initialize article-writer in the current project
 * Creates .article_writer folder with schemas and empty files
 * Completes missing files without deleting existing data
 * 
 * Usage: bun run init.ts [options]
 * 
 * Options:
 *   --check          Only check what's missing, don't create
 *   --author <json>  Create author from JSON string
 */

import { mkdir, copyFile, writeFile, readFile, stat } from "fs/promises";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = process.env.CLAUDE_PLUGIN_ROOT || dirname(__dirname);

const CONFIG_DIR = ".article_writer";
const SCHEMAS_DIR = join(CONFIG_DIR, "schemas");
const CONTENT_DIR = "content/articles";
const DOCS_DIR = "docs";

interface InitStatus {
  configDirExists: boolean;
  schemasDirExists: boolean;
  contentDirExists: boolean;
  docsDirExists: boolean;
  tasksSchemaExists: boolean;
  authorsSchemaExists: boolean;
  tasksFileExists: boolean;
  authorsFileExists: boolean;
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
    tasksFileExists: await exists(join(CONFIG_DIR, "article_tasks.json")),
    authorsFileExists: await exists(join(CONFIG_DIR, "authors.json")),
    missingItems: [],
    existingItems: []
  };

  // Track what's missing vs existing
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

  if (!status.tasksFileExists) status.missingItems.push("article_tasks.json");
  else status.existingItems.push("article_tasks.json");

  if (!status.authorsFileExists) status.missingItems.push("authors.json");
  else status.existingItems.push("authors.json");

  return status;
}

async function copySchema(filename: string, destDir: string): Promise<boolean> {
  const source = join(PLUGIN_ROOT, "schemas", filename);
  const dest = join(destDir, filename);
  
  try {
    await copyFile(source, dest);
    return true;
  } catch (e) {
    // Try to read from plugin schemas directory
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

async function createEmptyTasks(): Promise<void> {
  const emptyTasks = {
    $schema: "./schemas/article-tasks.schema.json",
    metadata: {
      version: "1.0.0",
      last_updated: new Date().toISOString(),
      total_count: 0
    },
    articles: []
  };
  await writeFile(
    join(CONFIG_DIR, "article_tasks.json"), 
    JSON.stringify(emptyTasks, null, 2)
  );
}

async function createEmptyAuthors(): Promise<void> {
  const emptyAuthors = {
    $schema: "./schemas/authors.schema.json",
    metadata: {
      version: "1.0.0",
      last_updated: new Date().toISOString()
    },
    authors: []
  };
  await writeFile(
    join(CONFIG_DIR, "authors.json"), 
    JSON.stringify(emptyAuthors, null, 2)
  );
}

async function addAuthor(authorJson: string): Promise<void> {
  const authorsPath = join(CONFIG_DIR, "authors.json");
  
  let authorsData: any;
  try {
    const content = await readFile(authorsPath, "utf-8");
    authorsData = JSON.parse(content);
  } catch {
    authorsData = {
      $schema: "./schemas/authors.schema.json",
      metadata: { version: "1.0.0", last_updated: new Date().toISOString() },
      authors: []
    };
  }

  const newAuthor = JSON.parse(authorJson);
  
  // Check if author with same ID exists
  const existingIndex = authorsData.authors.findIndex((a: any) => a.id === newAuthor.id);
  if (existingIndex >= 0) {
    authorsData.authors[existingIndex] = newAuthor;
    console.log(`✅ Updated existing author: ${newAuthor.name} (${newAuthor.id})`);
  } else {
    authorsData.authors.push(newAuthor);
    console.log(`✅ Added new author: ${newAuthor.name} (${newAuthor.id})`);
  }

  authorsData.metadata.last_updated = new Date().toISOString();
  await writeFile(authorsPath, JSON.stringify(authorsData, null, 2));
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

  // Report missing items
  if (status.missingItems.length === 0) {
    console.log("✅ Article Writer is fully initialized!\n");
    
    // Check if authors.json has any authors
    try {
      const authorsContent = await readFile(join(CONFIG_DIR, "authors.json"), "utf-8");
      const authors = JSON.parse(authorsContent);
      if (!authors.authors || authors.authors.length === 0) {
        console.log("⚠️  No authors configured yet.");
        console.log("   Run /article-writer:author add to create your first author.\n");
      } else {
        console.log(`📝 ${authors.authors.length} author(s) configured.`);
        console.log("   Run /article-writer:author list to see them.\n");
      }
    } catch {}
    
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

  // Copy schema files
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

  // Create empty data files
  console.log("\n📝 Creating data files...");
  if (!status.tasksFileExists) {
    await createEmptyTasks();
    console.log("   ✓ article_tasks.json");
  }
  if (!status.authorsFileExists) {
    await createEmptyAuthors();
    console.log("   ✓ authors.json");
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
  // Add author mode
  await addAuthor(args[authorIndex + 1]);
} else {
  // Init mode
  await init(checkOnly);
}
