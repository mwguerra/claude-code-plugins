#!/usr/bin/env bun
import { existsSync, mkdirSync, writeFileSync, copyFileSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";

const PLUGIN_HISTORY_DIR = join(homedir(), ".claude", ".plugin-history");
const LOG_FILE_PATH = join(PLUGIN_HISTORY_DIR, "usage-log.json");
const CONFIG_PATH = join(PLUGIN_HISTORY_DIR, "config.json");
const SCHEMA_PATH = join(PLUGIN_HISTORY_DIR, "usage-log-schema.json");

// Get the plugin root directory (parent of scripts dir)
const PLUGIN_ROOT = dirname(dirname(new URL(import.meta.url).pathname));
const SOURCE_SCHEMA_PATH = join(PLUGIN_ROOT, "schemas", "usage-log-schema.json");

interface Config {
  version: string;
  initialized_at: string;
  tracking_enabled: boolean;
  log_user_prompts: boolean;
  log_tool_inputs: boolean;
  log_tool_outputs: boolean;
  max_sessions_to_keep: number;
  auto_cleanup_enabled: boolean;
}

function createEmptyLog() {
  const now = new Date().toISOString();
  return {
    version: "1.0.0",
    created_at: now,
    updated_at: now,
    sessions: [],
    aggregate_stats: {
      total_sessions: 0,
      total_events: 0,
      total_tool_calls: 0,
      total_time_tracked_ms: 0,
      tool_usage_counts: {},
      tool_time_spent: {},
      project_usage: {},
      daily_activity: {},
    },
  };
}

function createDefaultConfig(): Config {
  return {
    version: "1.0.0",
    initialized_at: new Date().toISOString(),
    tracking_enabled: true,
    log_user_prompts: true,
    log_tool_inputs: true,
    log_tool_outputs: true,
    max_sessions_to_keep: 100,
    auto_cleanup_enabled: true,
  };
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes("--force") || args.includes("-f");
  
  console.log("🔧 Initializing Plugin Usage Tracker...\n");
  
  // Create directory if it doesn't exist
  if (!existsSync(PLUGIN_HISTORY_DIR)) {
    mkdirSync(PLUGIN_HISTORY_DIR, { recursive: true });
    console.log(`✅ Created directory: ${PLUGIN_HISTORY_DIR}`);
  } else {
    console.log(`📁 Directory exists: ${PLUGIN_HISTORY_DIR}`);
  }
  
  // Initialize log file
  if (!existsSync(LOG_FILE_PATH) || force) {
    const emptyLog = createEmptyLog();
    writeFileSync(LOG_FILE_PATH, JSON.stringify(emptyLog, null, 2));
    console.log(`✅ Created log file: ${LOG_FILE_PATH}`);
  } else {
    console.log(`📄 Log file exists: ${LOG_FILE_PATH}`);
  }
  
  // Initialize config file
  if (!existsSync(CONFIG_PATH) || force) {
    const config = createDefaultConfig();
    writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    console.log(`✅ Created config file: ${CONFIG_PATH}`);
  } else {
    console.log(`⚙️  Config file exists: ${CONFIG_PATH}`);
  }
  
  // Copy schema file
  if (existsSync(SOURCE_SCHEMA_PATH)) {
    copyFileSync(SOURCE_SCHEMA_PATH, SCHEMA_PATH);
    console.log(`✅ Copied schema to: ${SCHEMA_PATH}`);
  } else {
    console.log(`⚠️  Schema source not found at: ${SOURCE_SCHEMA_PATH}`);
  }
  
  console.log("\n✨ Plugin Usage Tracker initialized successfully!");
  console.log("\n📊 Usage tracking is now active. Your activity will be logged to:");
  console.log(`   ${LOG_FILE_PATH}`);
  console.log("\n📈 Use the following commands to analyze your usage:");
  console.log("   /usage-stats    - View usage statistics");
  console.log("   /usage-logs     - Browse recent activity logs");
  console.log("   /usage-clear    - Clear tracking history");
  console.log("\n💡 You can also ask the usage-analyzer agent for insights!");
}

main().catch(console.error);
