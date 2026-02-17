#!/usr/bin/env bun
/**
 * Config - Modify settings and author configurations (SQLite)
 *
 * Usage:
 *   bun run config.ts set <path> <value>              # Set a settings value
 *   bun run config.ts set-author <id> <path> <value>  # Set an author value
 *   bun run config.ts add-phrase <id> <type> <phrase>  # Add phrase to author
 *   bun run config.ts reset                           # Reset settings to defaults
 *   bun run config.ts reset-type <type>               # Reset one companion project type
 */

import { existsSync, readFileSync } from "fs";
import { join } from "path";
import { getDb, dbExists, getSettings, PLUGIN_ROOT, touchMetadata, rowToAuthor, authorToRow } from "./db";

function ensureDb(): void {
  if (!dbExists()) {
    console.error("❌ Database not found. Run /article-writer:init first.");
    process.exit(1);
  }
}

function parseValue(valueStr: string): any {
  try {
    return JSON.parse(valueStr);
  } catch {
    if (valueStr.toLowerCase() === "true") return true;
    if (valueStr.toLowerCase() === "false") return false;
    const num = Number(valueStr);
    if (!isNaN(num) && valueStr.trim() !== "") return num;
    return valueStr;
  }
}

function setNestedValue(obj: any, path: string, value: any): void {
  const keys = path.split(".");
  let current = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    if (current[keys[i]] === undefined) current[keys[i]] = {};
    current = current[keys[i]];
  }
  current[keys[keys.length - 1]] = value;
}

function getNestedValue(obj: any, path: string): any {
  const keys = path.split(".");
  let current = obj;
  for (const key of keys) {
    if (current === undefined || current === null) return undefined;
    current = current[key];
  }
  return current;
}

// ============================================
// Settings Commands
// ============================================

function setSetting(path: string, valueStr: string): void {
  ensureDb();
  const db = getDb();
  const settings = getSettings(db);

  if (!settings) {
    console.error("❌ Settings not found in database.");
    db.close();
    process.exit(1);
  }

  const newValue = parseValue(valueStr);

  // Determine which column to update
  if (path.startsWith("article_limits.") || path === "article_limits") {
    // Update article_limits column
    const articleLimits = settings.article_limits || {};
    if (path === "article_limits") {
      // Replace entire object
      db.run("UPDATE settings SET article_limits = ?, updated_at = datetime('now') WHERE id = 1",
        [JSON.stringify(newValue)]);
    } else {
      const subPath = path.replace("article_limits.", "");
      const currentValue = getNestedValue(articleLimits, subPath);

      console.log(`\n📝 Setting Configuration\n`);
      console.log(`  Path: article_limits.${subPath}`);
      console.log(`  Current value: ${JSON.stringify(currentValue)}`);
      console.log(`  New value: ${JSON.stringify(newValue)}`);

      setNestedValue(articleLimits, subPath, newValue);
      db.run("UPDATE settings SET article_limits = ?, updated_at = datetime('now') WHERE id = 1",
        [JSON.stringify(articleLimits)]);
    }
  } else {
    // Update companion_project_defaults column
    const fullPath = path.startsWith("companion_project_defaults.") ? path.replace("companion_project_defaults.", "") : path;
    const cpd = settings.companion_project_defaults || {};
    const currentValue = getNestedValue(cpd, fullPath);

    console.log(`\n📝 Setting Configuration\n`);
    console.log(`  Path: companion_project_defaults.${fullPath}`);
    console.log(`  Current value: ${JSON.stringify(currentValue)}`);
    console.log(`  New value: ${JSON.stringify(newValue)}`);

    setNestedValue(cpd, fullPath, newValue);
    db.run("UPDATE settings SET companion_project_defaults = ?, updated_at = datetime('now') WHERE id = 1",
      [JSON.stringify(cpd)]);
  }

  touchMetadata(db);
  console.log(`\n✅ Updated settings`);
  console.log(`\n   To verify: /article-writer:settings show`);
  db.close();
}

function resetSettings(): void {
  ensureDb();
  console.log(`\n🔄 Resetting Settings to Defaults\n`);

  const defaultSettingsPath = join(PLUGIN_ROOT, "schemas", "settings.sample.json");

  if (!existsSync(defaultSettingsPath)) {
    console.error("❌ Default settings template not found");
    process.exit(1);
  }

  try {
    const defaults = JSON.parse(readFileSync(defaultSettingsPath, "utf-8"));
    const articleLimits = JSON.stringify(defaults.article_limits || { max_words: 3000 });
    const companionDefaults = JSON.stringify(defaults.companion_project_defaults || {});

    const db = getDb();
    db.run(
      "UPDATE settings SET article_limits = ?, companion_project_defaults = ?, updated_at = datetime('now') WHERE id = 1",
      [articleLimits, companionDefaults]
    );
    touchMetadata(db);
    console.log("✅ Reset settings to defaults");
    db.close();
  } catch (e) {
    console.error(`❌ Failed to reset: ${e}`);
    process.exit(1);
  }
}

function resetExampleType(type: string): void {
  const validTypes = ["code", "node", "python", "document", "diagram", "template", "dataset", "config", "script", "spreadsheet", "other"];

  if (!validTypes.includes(type)) {
    console.error(`❌ Unknown example type: ${type}`);
    console.log(`\n   Valid types: ${validTypes.join(", ")}`);
    process.exit(1);
  }

  ensureDb();
  console.log(`\n🔄 Resetting ${type} Companion Project Defaults\n`);

  const defaultSettingsPath = join(PLUGIN_ROOT, "schemas", "settings.sample.json");
  const defaults = JSON.parse(readFileSync(defaultSettingsPath, "utf-8"));

  if (defaults.companion_project_defaults?.[type]) {
    const db = getDb();
    const settings = getSettings(db);
    if (!settings) {
      console.error("❌ Settings not found in database.");
      db.close();
      process.exit(1);
    }

    settings.companion_project_defaults[type] = defaults.companion_project_defaults[type];
    db.run(
      "UPDATE settings SET companion_project_defaults = ?, updated_at = datetime('now') WHERE id = 1",
      [JSON.stringify(settings.companion_project_defaults)]
    );
    touchMetadata(db);
    console.log(`✅ Reset companion_project_defaults.${type} to defaults`);
    db.close();
  } else {
    console.error(`❌ No default configuration for type: ${type}`);
  }
}

// ============================================
// Author Commands
// ============================================

function setAuthorValue(authorId: string, path: string, valueStr: string): void {
  ensureDb();
  const db = getDb();

  const row = db.query("SELECT * FROM authors WHERE id = ?").get(authorId) as any;
  if (!row) {
    console.error(`❌ Author not found: ${authorId}`);
    const all = db.query("SELECT id FROM authors ORDER BY sort_order").all() as any[];
    console.log(`\n   Available authors:`);
    all.forEach((a: any) => console.log(`   - ${a.id}`));
    db.close();
    process.exit(1);
  }

  const newValue = parseValue(valueStr);

  // Direct column updates for scalar fields
  const scalarColumns: Record<string, string> = {
    "name": "name",
    "tone.formality": "tone_formality",
    "tone.opinionated": "tone_opinionated",
    "example_voice": "example_voice",
  };

  if (scalarColumns[path]) {
    const col = scalarColumns[path];
    const currentValue = row[col];

    console.log(`\n📝 Updating Author: ${authorId}\n`);
    console.log(`  Path: ${path}`);
    console.log(`  Current value: ${JSON.stringify(currentValue)}`);
    console.log(`  New value: ${JSON.stringify(newValue)}`);

    db.run(`UPDATE authors SET ${col} = ?, updated_at = datetime('now') WHERE id = ?`, [newValue, authorId]);
  } else if (path === "languages") {
    const currentValue = JSON.parse(row.languages || "[]");
    const newLangs = Array.isArray(newValue) ? newValue : [newValue];

    console.log(`\n📝 Updating Author: ${authorId}\n`);
    console.log(`  Path: languages`);
    console.log(`  Current value: ${JSON.stringify(currentValue)}`);
    console.log(`  New value: ${JSON.stringify(newLangs)}`);

    db.run("UPDATE authors SET languages = ?, updated_at = datetime('now') WHERE id = ?",
      [JSON.stringify(newLangs), authorId]);
  } else {
    // JSON column updates (vocabulary, phrases, opinions, role, experience, expertise, notes)
    const jsonColumns: Record<string, string> = {
      "vocabulary": "vocabulary",
      "phrases": "phrases",
      "opinions": "opinions",
      "role": "role",
      "experience": "experience",
      "expertise": "expertise",
      "notes": "notes",
      "voice_analysis": "voice_analysis",
    };

    // Find which JSON column this path belongs to
    const topKey = path.split(".")[0];
    const col = jsonColumns[topKey];

    if (!col) {
      console.error(`❌ Unknown author field path: ${path}`);
      db.close();
      process.exit(1);
    }

    const jsonData = row[col] ? JSON.parse(row[col]) : {};
    const subPath = path.includes(".") ? path.split(".").slice(1).join(".") : null;

    const currentValue = subPath ? getNestedValue(jsonData, subPath) : jsonData;

    console.log(`\n📝 Updating Author: ${authorId}\n`);
    console.log(`  Path: ${path}`);
    console.log(`  Current value: ${JSON.stringify(currentValue)}`);
    console.log(`  New value: ${JSON.stringify(newValue)}`);

    if (subPath) {
      setNestedValue(jsonData, subPath, newValue);
    } else {
      // Replace entire column value
      db.run(`UPDATE authors SET ${col} = ?, updated_at = datetime('now') WHERE id = ?`,
        [JSON.stringify(newValue), authorId]);
      touchMetadata(db);
      console.log(`\n✅ Updated author ${authorId}`);
      console.log(`\n   To verify: /article-writer:author show ${authorId}`);
      db.close();
      return;
    }

    db.run(`UPDATE authors SET ${col} = ?, updated_at = datetime('now') WHERE id = ?`,
      [JSON.stringify(jsonData), authorId]);
  }

  touchMetadata(db);
  console.log(`\n✅ Updated author ${authorId}`);
  console.log(`\n   To verify: /article-writer:author show ${authorId}`);
  db.close();
}

function addAuthorPhrase(authorId: string, phraseType: "signature" | "avoid", phrase: string): void {
  ensureDb();
  const db = getDb();

  const row = db.query("SELECT phrases FROM authors WHERE id = ?").get(authorId) as any;
  if (!row) {
    console.error(`❌ Author not found: ${authorId}`);
    db.close();
    process.exit(1);
  }

  const phrases = row.phrases ? JSON.parse(row.phrases) : {};
  if (!phrases[phraseType]) phrases[phraseType] = [];
  if (!Array.isArray(phrases[phraseType])) phrases[phraseType] = [phrases[phraseType]];

  if (phrases[phraseType].includes(phrase)) {
    console.log(`⚠️  Phrase already exists in ${phraseType}`);
    db.close();
    return;
  }

  phrases[phraseType].push(phrase);
  db.run("UPDATE authors SET phrases = ?, updated_at = datetime('now') WHERE id = ?",
    [JSON.stringify(phrases), authorId]);
  touchMetadata(db);

  console.log(`✅ Added "${phrase}" to ${authorId}'s ${phraseType} phrases`);
  db.close();
}

// ============================================
// Main
// ============================================

const args = process.argv.slice(2);
const command = args[0];

function showHelp(): void {
  console.log(`
Usage: bun run config.ts <command> [options]

Commands:
  set <path> <value>                    Set a settings value
  set-author <id> <path> <value>        Set an author value
  add-phrase <id> <signature|avoid> <phrase>  Add a phrase to author
  reset                                 Reset all settings to defaults
  reset-type <type>                     Reset one companion project type to defaults

Settings Paths:
  article_limits.max_words              e.g., 3000
  code.technologies                     e.g., '["Laravel 12", "Pest 4"]'
  code.has_tests                        e.g., true
  code.scaffold_command                 e.g., "composer create-project..."

Author Paths:
  name                                  Author display name
  tone.formality                        1-10 scale
  tone.opinionated                      1-10 scale
  vocabulary.use_freely                 Array of terms
  vocabulary.always_explain             Array of terms

Examples:
  bun run config.ts set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'
  bun run config.ts set article_limits.max_words 5000
  bun run config.ts set-author mwguerra tone.formality 6
  bun run config.ts add-phrase mwguerra signature "Na pratica..."
  bun run config.ts reset
  bun run config.ts reset-type code
`);
}

async function main(): Promise<void> {
  if (!command || command === "--help" || command === "-h") {
    showHelp();
    process.exit(0);
  }

  switch (command) {
    case "set":
      if (args.length < 3) {
        console.error("❌ Usage: bun run config.ts set <path> <value>");
        process.exit(1);
      }
      setSetting(args[1], args.slice(2).join(" "));
      break;

    case "set-author":
      if (args.length < 4) {
        console.error("❌ Usage: bun run config.ts set-author <id> <path> <value>");
        process.exit(1);
      }
      setAuthorValue(args[1], args[2], args.slice(3).join(" "));
      break;

    case "add-phrase":
      if (args.length < 4) {
        console.error("❌ Usage: bun run config.ts add-phrase <id> <signature|avoid> <phrase>");
        process.exit(1);
      }
      const phraseType = args[2] as "signature" | "avoid";
      if (phraseType !== "signature" && phraseType !== "avoid") {
        console.error("❌ Phrase type must be 'signature' or 'avoid'");
        process.exit(1);
      }
      addAuthorPhrase(args[1], phraseType, args.slice(3).join(" "));
      break;

    case "reset":
      resetSettings();
      break;

    case "reset-type":
      if (!args[1]) {
        console.error("❌ Usage: bun run config.ts reset-type <type>");
        process.exit(1);
      }
      resetExampleType(args[1]);
      break;

    default:
      console.error(`❌ Unknown command: ${command}`);
      showHelp();
      process.exit(1);
  }
}

main().catch((e) => {
  console.error("Error:", e.message);
  process.exit(1);
});
