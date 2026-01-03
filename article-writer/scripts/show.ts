#!/usr/bin/env bun
/**
 * Show - View authors, settings, and configuration
 *
 * Usage:
 *   bun run show.ts authors                    # List all authors
 *   bun run show.ts author <id>                # Show single author details
 *   bun run show.ts settings                   # Show all settings
 *   bun run show.ts settings <type>            # Show defaults for companion project type
 *   bun run show.ts queue                      # Show queue summary
 */

import { readFile, stat } from "fs/promises";
import { join } from "path";

// Project root - use CLAUDE_PROJECT_DIR when available, fall back to process.cwd()
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();

const CONFIG_DIR = join(PROJECT_ROOT, ".article_writer");
const FILES = {
  authors: join(CONFIG_DIR, "authors.json"),
  settings: join(CONFIG_DIR, "settings.json"),
  tasks: join(CONFIG_DIR, "article_tasks.json"),
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

function printDivider(char: string = "─", length: number = 60): void {
  console.log(char.repeat(length));
}

function printHeader(title: string): void {
  console.log("");
  printDivider("═");
  console.log(`  ${title}`);
  printDivider("═");
}

// ============================================
// Authors
// ============================================

async function listAuthors(): Promise<void> {
  if (!(await exists(FILES.authors))) {
    console.error(`❌ File not found: ${FILES.authors}`);
    console.log(`   Run /article-writer:init first.`);
    process.exit(1);
  }

  const data = await loadJson(FILES.authors);
  const authors = data.authors || [];

  printHeader("AUTHORS");
  console.log(`  File: ${FILES.authors}`);
  printDivider();

  if (authors.length === 0) {
    console.log("\n  No authors configured yet.");
    console.log("  Run /article-writer:author add to create one.\n");
    return;
  }

  console.log(`\n  Total: ${authors.length} author(s)\n`);

  authors.forEach((author: any, index: number) => {
    const isDefault = index === 0 ? " [DEFAULT]" : "";
    const hasVoice = author.voice_analysis ? "✓" : "✗";
    
    console.log(`  ${index + 1}. ${author.name} (${author.id})${isDefault}`);
    console.log(`     Languages: ${author.languages?.join(", ") || "none"}`);
    if (author.role) {
      console.log(`     Role: ${Array.isArray(author.role) ? author.role.join(", ") : author.role}`);
    }
    if (author.expertise) {
      const exp = Array.isArray(author.expertise) ? author.expertise.join(", ") : author.expertise;
      console.log(`     Expertise: ${exp}`);
    }
    if (author.tone) {
      console.log(`     Tone: Formality ${author.tone.formality || "?"}/10, Opinionated ${author.tone.opinionated || "?"}/10`);
    }
    console.log(`     Voice Analysis: ${hasVoice}${author.voice_analysis ? ` (${author.voice_analysis.sample_count} samples)` : ""}`);
    console.log("");
  });

  console.log(`  To see full details: /article-writer:author show <id>`);
  printDivider();
}

async function showAuthor(authorId: string): Promise<void> {
  if (!(await exists(FILES.authors))) {
    console.error(`❌ File not found: ${FILES.authors}`);
    process.exit(1);
  }

  const data = await loadJson(FILES.authors);
  const authors = data.authors || [];
  const author = authors.find((a: any) => a.id === authorId);

  if (!author) {
    console.error(`❌ Author not found: ${authorId}`);
    console.log(`\n   Available authors:`);
    authors.forEach((a: any) => console.log(`   - ${a.id} (${a.name})`));
    process.exit(1);
  }

  const isDefault = authors[0]?.id === authorId;

  printHeader(`AUTHOR: ${author.name}`);
  console.log(`  File: ${FILES.authors}`);
  printDivider();

  // Identity
  console.log("\n  ┌─ IDENTITY");
  console.log(`  │  ID: ${author.id}${isDefault ? " [DEFAULT]" : ""}`);
  console.log(`  │  Name: ${author.name}`);
  if (author.role) {
    console.log(`  │  Role: ${Array.isArray(author.role) ? author.role.join(", ") : author.role}`);
  }
  if (author.experience) {
    console.log(`  │  Experience: ${Array.isArray(author.experience) ? author.experience.join(", ") : author.experience}`);
  }
  if (author.expertise) {
    const exp = Array.isArray(author.expertise) ? author.expertise : [author.expertise];
    console.log(`  │  Expertise: ${exp.join(", ")}`);
  }

  // Languages
  console.log("  │");
  console.log("  ├─ LANGUAGES");
  if (author.languages && author.languages.length > 0) {
    console.log(`  │  Primary: ${author.languages[0]}`);
    if (author.languages.length > 1) {
      console.log(`  │  Translations: ${author.languages.slice(1).join(", ")}`);
    }
  }

  // Tone
  if (author.tone) {
    console.log("  │");
    console.log("  ├─ TONE");
    if (author.tone.formality !== undefined) {
      const formalityBar = "█".repeat(author.tone.formality) + "░".repeat(10 - author.tone.formality);
      console.log(`  │  Formality:  [${formalityBar}] ${author.tone.formality}/10`);
      console.log(`  │              (1=casual ← → formal=10)`);
    }
    if (author.tone.opinionated !== undefined) {
      const opinionBar = "█".repeat(author.tone.opinionated) + "░".repeat(10 - author.tone.opinionated);
      console.log(`  │  Opinionated: [${opinionBar}] ${author.tone.opinionated}/10`);
      console.log(`  │              (1=neutral ← → opinionated=10)`);
    }
  }

  // Vocabulary
  if (author.vocabulary) {
    console.log("  │");
    console.log("  ├─ VOCABULARY");
    if (author.vocabulary.use_freely) {
      const terms = Array.isArray(author.vocabulary.use_freely) 
        ? author.vocabulary.use_freely 
        : [author.vocabulary.use_freely];
      console.log(`  │  Use freely: ${terms.join(", ")}`);
    }
    if (author.vocabulary.always_explain) {
      const terms = Array.isArray(author.vocabulary.always_explain)
        ? author.vocabulary.always_explain
        : [author.vocabulary.always_explain];
      console.log(`  │  Always explain: ${terms.join(", ")}`);
    }
  }

  // Phrases
  if (author.phrases) {
    console.log("  │");
    console.log("  ├─ PHRASES");
    if (author.phrases.signature) {
      const phrases = Array.isArray(author.phrases.signature)
        ? author.phrases.signature
        : [author.phrases.signature];
      console.log(`  │  Signature:`);
      phrases.forEach((p: string) => console.log(`  │    • "${p}"`));
    }
    if (author.phrases.avoid) {
      const phrases = Array.isArray(author.phrases.avoid)
        ? author.phrases.avoid
        : [author.phrases.avoid];
      console.log(`  │  Avoid:`);
      phrases.forEach((p: string) => console.log(`  │    ✗ "${p}"`));
    }
  }

  // Opinions
  if (author.opinions) {
    console.log("  │");
    console.log("  ├─ OPINIONS");
    if (author.opinions.strong_positions) {
      const positions = Array.isArray(author.opinions.strong_positions)
        ? author.opinions.strong_positions
        : [author.opinions.strong_positions];
      console.log(`  │  Strong positions:`);
      positions.forEach((p: string) => console.log(`  │    • ${p}`));
    }
    if (author.opinions.stay_neutral) {
      const neutral = Array.isArray(author.opinions.stay_neutral)
        ? author.opinions.stay_neutral
        : [author.opinions.stay_neutral];
      console.log(`  │  Stay neutral on:`);
      neutral.forEach((p: string) => console.log(`  │    ○ ${p}`));
    }
  }

  // Voice Analysis
  if (author.voice_analysis) {
    const va = author.voice_analysis;
    console.log("  │");
    console.log("  ├─ VOICE ANALYSIS (from transcripts)");
    console.log(`  │  Extracted from: ${va.extracted_from?.join(", ") || "unknown"}`);
    console.log(`  │  Samples: ${va.sample_count || 0} turns, ${va.total_words || 0} words`);
    
    if (va.sentence_structure) {
      console.log(`  │  Sentence style: ${va.sentence_structure.variety || "unknown"} (~${va.sentence_structure.avg_length || "?"} words)`);
      console.log(`  │  Question ratio: ${va.sentence_structure.question_ratio || 0}%`);
    }
    
    if (va.communication_style && va.communication_style.length > 0) {
      console.log(`  │  Communication style:`);
      va.communication_style.slice(0, 3).forEach((s: any) => {
        console.log(`  │    • ${s.trait}: ${s.percentage}%`);
      });
    }
    
    if (va.characteristic_expressions && va.characteristic_expressions.length > 0) {
      console.log(`  │  Characteristic expressions: "${va.characteristic_expressions.slice(0, 5).join('", "')}"`);
    }
    
    if (va.signature_vocabulary && va.signature_vocabulary.length > 0) {
      console.log(`  │  Signature vocabulary: ${va.signature_vocabulary.slice(0, 8).join(", ")}`);
    }
    
    if (va.analyzed_at) {
      console.log(`  │  Analyzed at: ${va.analyzed_at}`);
    }
  }

  // Example voice
  if (author.example_voice) {
    console.log("  │");
    console.log("  ├─ EXAMPLE VOICE");
    console.log(`  │  "${author.example_voice.substring(0, 200)}${author.example_voice.length > 200 ? "..." : ""}"`);
  }

  // Notes
  if (author.notes) {
    console.log("  │");
    console.log("  └─ NOTES");
    const notes = Array.isArray(author.notes) ? author.notes : [author.notes];
    notes.forEach((n: string) => console.log(`     ${n}`));
  } else {
    console.log("  └─────────────────────────────");
  }

  console.log("");
  printDivider();
}

// ============================================
// Settings
// ============================================

async function showSettings(companionProjectType?: string): Promise<void> {
  if (!(await exists(FILES.settings))) {
    console.error(`❌ File not found: ${FILES.settings}`);
    console.log(`   Run /article-writer:init first.`);
    process.exit(1);
  }

  const data = await loadJson(FILES.settings);

  if (companionProjectType) {
    // Show specific companion project type
    await showCompanionProjectDefaults(data, companionProjectType);
  } else {
    // Show all settings
    await showAllSettings(data);
  }
}

async function showAllSettings(data: any): Promise<void> {
  printHeader("SETTINGS");
  console.log(`  File: ${FILES.settings}`);
  printDivider();

  // Metadata
  if (data.metadata) {
    console.log("\n  Metadata:");
    console.log(`    Version: ${data.metadata.version || "unknown"}`);
    console.log(`    Last updated: ${data.metadata.last_updated || "unknown"}`);
  }

  // Companion project defaults summary
  if (data.companion_project_defaults) {
    console.log("\n  Companion Project Defaults:");
    console.log("  ┌────────────┬─────────────────────────────────┬───────────┐");
    console.log("  │ Type       │ Technologies                    │ Has Tests │");
    console.log("  ├────────────┼─────────────────────────────────┼───────────┤");

    const types = ["code", "document", "diagram", "template", "dataset", "config", "script", "spreadsheet", "other"];
    
    for (const type of types) {
      const defaults = data.companion_project_defaults[type];
      if (defaults) {
        const tech = defaults.technologies?.slice(0, 3).join(", ") || "-";
        const techDisplay = tech.length > 30 ? tech.substring(0, 27) + "..." : tech.padEnd(30);
        const hasTests = defaults.has_tests ? "Yes" : "No";
        console.log(`  │ ${type.padEnd(10)} │ ${techDisplay} │ ${hasTests.padEnd(9)} │`);
      }
    }
    
    console.log("  └────────────┴─────────────────────────────────┴───────────┘");
  }

  console.log("\n  To see type details: /article-writer:settings show <type>");
  console.log("  Example: /article-writer:settings show code");
  printDivider();
}

async function showCompanionProjectDefaults(data: any, type: string): Promise<void> {
  const validTypes = ["code", "document", "diagram", "template", "dataset", "config", "script", "spreadsheet", "other"];

  if (!validTypes.includes(type)) {
    console.error(`❌ Unknown companion project type: ${type}`);
    console.log(`\n   Valid types: ${validTypes.join(", ")}`);
    process.exit(1);
  }

  const defaults = data.companion_project_defaults?.[type];

  if (!defaults) {
    console.error(`❌ No defaults configured for type: ${type}`);
    process.exit(1);
  }

  printHeader(`COMPANION PROJECT DEFAULTS: ${type.toUpperCase()}`);
  console.log(`  File: ${FILES.settings}`);
  printDivider();

  console.log("");
  
  // Technologies
  if (defaults.technologies) {
    console.log("  Technologies:");
    defaults.technologies.forEach((t: string) => console.log(`    • ${t}`));
  }

  // Testing
  console.log(`\n  Has Tests: ${defaults.has_tests ? "Yes ✓" : "No ✗"}`);
  if (defaults.test_command) {
    console.log(`  Test Command: ${defaults.test_command}`);
  }

  // Path
  if (defaults.path) {
    console.log(`\n  Default Path: ${defaults.path}`);
  }

  // Scaffold command
  if (defaults.scaffold_command) {
    console.log(`\n  Scaffold Command:`);
    console.log(`    ${defaults.scaffold_command}`);
  }

  // Post scaffold
  if (defaults.post_scaffold && defaults.post_scaffold.length > 0) {
    console.log(`\n  Post-Scaffold Commands:`);
    defaults.post_scaffold.forEach((cmd: string, i: number) => {
      console.log(`    ${i + 1}. ${cmd}`);
    });
  }

  // Setup commands
  if (defaults.setup_commands && defaults.setup_commands.length > 0) {
    console.log(`\n  Setup Commands (for users):`);
    defaults.setup_commands.forEach((cmd: string, i: number) => {
      console.log(`    ${i + 1}. ${cmd}`);
    });
  }

  // Run command/instructions
  if (defaults.run_command) {
    console.log(`\n  Run Command: ${defaults.run_command}`);
  }
  if (defaults.run_instructions) {
    console.log(`\n  Run Instructions:`);
    console.log(`    ${defaults.run_instructions}`);
  }

  // File structure
  if (defaults.file_structure && defaults.file_structure.length > 0) {
    console.log(`\n  Expected File Structure:`);
    defaults.file_structure.forEach((f: string) => console.log(`    ${f}`));
  }

  // Env setup
  if (defaults.env_setup) {
    console.log(`\n  Environment Setup:`);
    for (const [key, value] of Object.entries(defaults.env_setup)) {
      console.log(`    ${key}=${value}`);
    }
  }

  // Notes
  if (defaults.notes) {
    console.log(`\n  Notes:`);
    console.log(`    ${defaults.notes}`);
  }

  console.log("");
  console.log("  To modify: /article-writer:settings set <key> <value>");
  console.log(`  Example: /article-writer:settings set ${type}.technologies '["Laravel 11", "Pest 3"]'`);
  printDivider();
}

// ============================================
// Queue Summary
// ============================================

async function showQueueSummary(): Promise<void> {
  if (!(await exists(FILES.tasks))) {
    console.error(`❌ File not found: ${FILES.tasks}`);
    console.log(`   Run /article-writer:init first.`);
    process.exit(1);
  }

  const data = await loadJson(FILES.tasks);
  const articles = data.articles || [];

  printHeader("ARTICLE QUEUE");
  console.log(`  File: ${FILES.tasks}`);
  printDivider();

  if (articles.length === 0) {
    console.log("\n  No articles in queue.");
    console.log("  Run /article-writer:article <topic> to add one.\n");
    return;
  }

  // Count by status
  const byStatus: Record<string, number> = {};
  const byAuthor: Record<string, number> = {};
  const byArea: Record<string, number> = {};

  articles.forEach((a: any) => {
    const status = a.status || "unknown";
    const author = a.author?.id || a.author || "unassigned";
    const area = a.area || "unknown";

    byStatus[status] = (byStatus[status] || 0) + 1;
    byAuthor[author] = (byAuthor[author] || 0) + 1;
    byArea[area] = (byArea[area] || 0) + 1;
  });

  console.log(`\n  Total: ${articles.length} articles\n`);

  // By status
  console.log("  By Status:");
  for (const [status, count] of Object.entries(byStatus).sort((a, b) => b[1] - a[1])) {
    const emoji = status === "pending" ? "⏳" : 
                  status === "in_progress" ? "🔄" :
                  status === "draft" ? "📝" :
                  status === "review" ? "👀" :
                  status === "published" ? "✅" :
                  status === "archived" ? "📦" : "❓";
    console.log(`    ${emoji} ${status}: ${count}`);
  }

  // By author
  if (Object.keys(byAuthor).length > 1 || !byAuthor["unassigned"]) {
    console.log("\n  By Author:");
    for (const [author, count] of Object.entries(byAuthor).sort((a, b) => b[1] - a[1])) {
      console.log(`    • ${author}: ${count}`);
    }
  }

  // Top areas
  console.log("\n  Top Areas:");
  const topAreas = Object.entries(byArea).sort((a, b) => b[1] - a[1]).slice(0, 5);
  for (const [area, count] of topAreas) {
    console.log(`    • ${area}: ${count}`);
  }

  console.log("\n  For full list: /article-writer:queue list");
  printDivider();
}

// ============================================
// Main
// ============================================

const args = process.argv.slice(2);
const command = args[0];
const subArg = args[1];

async function main(): Promise<void> {
  if (!command) {
    console.log(`
Usage: bun run show.ts <command> [options]

Commands:
  authors              List all authors
  author <id>          Show single author details
  settings             Show all settings
  settings <type>      Show companion project defaults for type
  queue                Show queue summary

Examples:
  bun run show.ts authors
  bun run show.ts author mwguerra
  bun run show.ts settings
  bun run show.ts settings code
  bun run show.ts queue
`);
    process.exit(0);
  }

  switch (command) {
    case "authors":
      await listAuthors();
      break;
    case "author":
      if (!subArg) {
        console.error("❌ Please specify an author ID");
        console.log("   Usage: bun run show.ts author <id>");
        process.exit(1);
      }
      await showAuthor(subArg);
      break;
    case "settings":
      await showSettings(subArg);
      break;
    case "queue":
      await showQueueSummary();
      break;
    default:
      console.error(`❌ Unknown command: ${command}`);
      console.log("   Run without arguments to see usage.");
      process.exit(1);
  }
}

main().catch((e) => {
  console.error("Error:", e.message);
  process.exit(1);
});
