#!/usr/bin/env bun
/**
 * Config - Modify settings and author configurations
 * 
 * Usage:
 *   bun run config.ts set <path> <value>           # Set a settings value
 *   bun run config.ts set-author <id> <path> <value>  # Set an author value
 *   bun run config.ts reset                        # Reset settings to defaults
 *   bun run config.ts reset-type <type>            # Reset one example type
 */

import { readFile, writeFile, stat, copyFile } from "fs/promises";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = process.env.CLAUDE_PLUGIN_ROOT || dirname(__dirname);

// Project root - use CLAUDE_PROJECT_DIR when available, fall back to process.cwd()
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();

const CONFIG_DIR = join(PROJECT_ROOT, ".article_writer");
const FILES = {
  settings: join(CONFIG_DIR, "settings.json"),
  authors: join(CONFIG_DIR, "authors.json"),
};

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function loadJson(path: string): Promise<any> {
  const content = await readFile(path, "utf-8");
  return JSON.parse(content);
}

async function saveJson(path: string, data: any): Promise<void> {
  await writeFile(path, JSON.stringify(data, null, 2));
}

function setNestedValue(obj: any, path: string, value: any): void {
  const keys = path.split(".");
  let current = obj;
  
  for (let i = 0; i < keys.length - 1; i++) {
    const key = keys[i];
    if (current[key] === undefined) {
      current[key] = {};
    }
    current = current[key];
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

function parseValue(valueStr: string): any {
  // Try to parse as JSON first
  try {
    return JSON.parse(valueStr);
  } catch {
    // Check for boolean
    if (valueStr.toLowerCase() === "true") return true;
    if (valueStr.toLowerCase() === "false") return false;
    
    // Check for number
    const num = Number(valueStr);
    if (!isNaN(num) && valueStr.trim() !== "") return num;
    
    // Return as string
    return valueStr;
  }
}

// ============================================
// Settings Commands
// ============================================

async function setSetting(path: string, valueStr: string): Promise<void> {
  if (!(await exists(FILES.settings))) {
    console.error(`❌ File not found: ${FILES.settings}`);
    console.log(`   Run /article-writer:init first.`);
    process.exit(1);
  }

  const data = await loadJson(FILES.settings);
  const fullPath = path.startsWith("companion_project_defaults.") ? path : `companion_project_defaults.${path}`;
  
  // Get current value
  const currentValue = getNestedValue(data, fullPath);
  const newValue = parseValue(valueStr);

  console.log(`\n📝 Setting Configuration\n`);
  console.log(`  Path: ${fullPath}`);
  console.log(`  Current value: ${JSON.stringify(currentValue)}`);
  console.log(`  New value: ${JSON.stringify(newValue)}`);

  // Set the value
  setNestedValue(data, fullPath, newValue);
  
  // Update metadata
  if (data.metadata) {
    data.metadata.last_updated = new Date().toISOString();
  }

  await saveJson(FILES.settings, data);
  
  console.log(`\n✅ Updated ${FILES.settings}`);
  console.log(`\n   To verify: /article-writer:settings show`);
}

async function resetSettings(): Promise<void> {
  console.log(`\n🔄 Resetting Settings to Defaults\n`);
  
  // Load default settings from plugin
  const defaultSettingsPath = join(PLUGIN_ROOT, "schemas", "settings.sample.json");
  
  if (await exists(defaultSettingsPath)) {
    try {
      const defaultSettings = await loadJson(defaultSettingsPath);
      defaultSettings.metadata = {
        version: "1.0.0",
        last_updated: new Date().toISOString()
      };
      await saveJson(FILES.settings, defaultSettings);
      console.log(`✅ Reset ${FILES.settings} to defaults`);
    } catch (e) {
      console.error(`❌ Failed to reset: ${e}`);
      process.exit(1);
    }
  } else {
    console.error(`❌ Default settings template not found`);
    process.exit(1);
  }
}

async function resetExampleType(type: string): Promise<void> {
  const validTypes = ["code", "document", "diagram", "template", "dataset", "config", "script", "spreadsheet", "other"];
  
  if (!validTypes.includes(type)) {
    console.error(`❌ Unknown example type: ${type}`);
    console.log(`\n   Valid types: ${validTypes.join(", ")}`);
    process.exit(1);
  }

  console.log(`\n🔄 Resetting ${type} Example Defaults\n`);

  // Load current settings
  const data = await loadJson(FILES.settings);
  
  // Load default settings
  const defaultSettingsPath = join(PLUGIN_ROOT, "schemas", "settings.sample.json");
  const defaults = await loadJson(defaultSettingsPath);
  
  if (defaults.companion_project_defaults?.[type]) {
    data.companion_project_defaults[type] = defaults.companion_project_defaults[type];
    data.metadata.last_updated = new Date().toISOString();
    await saveJson(FILES.settings, data);
    console.log(`✅ Reset companion_project_defaults.${type} to defaults`);
  } else {
    console.error(`❌ No default configuration for type: ${type}`);
  }
}

// ============================================
// Author Commands
// ============================================

async function setAuthorValue(authorId: string, path: string, valueStr: string): Promise<void> {
  if (!(await exists(FILES.authors))) {
    console.error(`❌ File not found: ${FILES.authors}`);
    process.exit(1);
  }

  const data = await loadJson(FILES.authors);
  const authors = data.authors || [];
  const authorIndex = authors.findIndex((a: any) => a.id === authorId);

  if (authorIndex === -1) {
    console.error(`❌ Author not found: ${authorId}`);
    console.log(`\n   Available authors:`);
    authors.forEach((a: any) => console.log(`   - ${a.id}`));
    process.exit(1);
  }

  const author = authors[authorIndex];
  const currentValue = getNestedValue(author, path);
  const newValue = parseValue(valueStr);

  console.log(`\n📝 Updating Author: ${authorId}\n`);
  console.log(`  Path: ${path}`);
  console.log(`  Current value: ${JSON.stringify(currentValue)}`);
  console.log(`  New value: ${JSON.stringify(newValue)}`);

  // Set the value
  setNestedValue(author, path, newValue);
  
  // Update metadata
  if (data.metadata) {
    data.metadata.last_updated = new Date().toISOString();
  }

  await saveJson(FILES.authors, data);
  
  console.log(`\n✅ Updated ${FILES.authors}`);
  console.log(`\n   To verify: /article-writer:author show ${authorId}`);
}

async function addAuthorPhrase(authorId: string, phraseType: "signature" | "avoid", phrase: string): Promise<void> {
  if (!(await exists(FILES.authors))) {
    console.error(`❌ File not found: ${FILES.authors}`);
    process.exit(1);
  }

  const data = await loadJson(FILES.authors);
  const authors = data.authors || [];
  const author = authors.find((a: any) => a.id === authorId);

  if (!author) {
    console.error(`❌ Author not found: ${authorId}`);
    process.exit(1);
  }

  if (!author.phrases) {
    author.phrases = {};
  }
  if (!author.phrases[phraseType]) {
    author.phrases[phraseType] = [];
  }
  
  if (!Array.isArray(author.phrases[phraseType])) {
    author.phrases[phraseType] = [author.phrases[phraseType]];
  }

  if (author.phrases[phraseType].includes(phrase)) {
    console.log(`⚠️  Phrase already exists in ${phraseType}`);
    return;
  }

  author.phrases[phraseType].push(phrase);
  data.metadata.last_updated = new Date().toISOString();
  await saveJson(FILES.authors, data);

  console.log(`✅ Added "${phrase}" to ${authorId}'s ${phraseType} phrases`);
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

Settings Paths (prefix with companion_project_defaults. or use shorthand):
  code.technologies                     e.g., '["Laravel 12", "Pest 4"]'
  code.has_tests                        e.g., true
  code.scaffold_command                 e.g., "composer create-project..."
  code.run_command                      e.g., "php artisan serve"
  document.technologies                 e.g., '["Markdown", "AsciiDoc"]'

Author Paths:
  name                                  Author display name
  tone.formality                        1-10 scale
  tone.opinionated                      1-10 scale
  vocabulary.use_freely                 Array of terms
  vocabulary.always_explain             Array of terms

Examples:
  bun run config.ts set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'
  bun run config.ts set code.has_tests true
  bun run config.ts set-author mwguerra tone.formality 6
  bun run config.ts set-author mwguerra name "MW Guerra Jr"
  bun run config.ts add-phrase mwguerra signature "Na prática..."
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
      await setSetting(args[1], args.slice(2).join(" "));
      break;

    case "set-author":
      if (args.length < 4) {
        console.error("❌ Usage: bun run config.ts set-author <id> <path> <value>");
        process.exit(1);
      }
      await setAuthorValue(args[1], args[2], args.slice(3).join(" "));
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
      await addAuthorPhrase(args[1], phraseType, args.slice(3).join(" "));
      break;

    case "reset":
      await resetSettings();
      break;

    case "reset-type":
      if (!args[1]) {
        console.error("❌ Usage: bun run config.ts reset-type <type>");
        process.exit(1);
      }
      await resetExampleType(args[1]);
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
