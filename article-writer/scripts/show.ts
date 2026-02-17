#!/usr/bin/env bun
/**
 * Show - View authors, settings, and configuration (SQLite)
 *
 * Usage:
 *   bun run show.ts authors                    # List all authors
 *   bun run show.ts author <id>                # Show single author details
 *   bun run show.ts settings                   # Show all settings
 *   bun run show.ts settings <type>            # Show defaults for companion project type
 *   bun run show.ts queue                      # Show queue summary
 */

import { getDb, dbExists, rowToAuthor, getSettings } from "./db";

function printDivider(char: string = "─", length: number = 60): void {
  console.log(char.repeat(length));
}

function printHeader(title: string): void {
  console.log("");
  printDivider("═");
  console.log(`  ${title}`);
  printDivider("═");
}

function ensureDb(): void {
  if (!dbExists()) {
    console.error("❌ Database not found.");
    console.log("   Run /article-writer:init first.");
    process.exit(1);
  }
}

// ============================================
// Authors
// ============================================

function listAuthors(): void {
  ensureDb();
  const db = getDb();
  const rows = db.query("SELECT * FROM authors ORDER BY sort_order ASC").all() as any[];

  printHeader("AUTHORS");
  printDivider();

  if (rows.length === 0) {
    console.log("\n  No authors configured yet.");
    console.log("  Run /article-writer:author add to create one.\n");
    db.close();
    return;
  }

  console.log(`\n  Total: ${rows.length} author(s)\n`);

  rows.forEach((row, index) => {
    const author = rowToAuthor(row);
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
  db.close();
}

function showAuthor(authorId: string): void {
  ensureDb();
  const db = getDb();
  const row = db.query("SELECT * FROM authors WHERE id = ?").get(authorId) as any;

  if (!row) {
    console.error(`❌ Author not found: ${authorId}`);
    const all = db.query("SELECT id, name FROM authors ORDER BY sort_order").all() as any[];
    console.log(`\n   Available authors:`);
    all.forEach((a: any) => console.log(`   - ${a.id} (${a.name})`));
    db.close();
    process.exit(1);
  }

  const author = rowToAuthor(row);
  const isDefault = row.sort_order === 0;

  printHeader(`AUTHOR: ${author.name}`);
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
      const terms = Array.isArray(author.vocabulary.use_freely) ? author.vocabulary.use_freely : [author.vocabulary.use_freely];
      console.log(`  │  Use freely: ${terms.join(", ")}`);
    }
    if (author.vocabulary.always_explain) {
      const terms = Array.isArray(author.vocabulary.always_explain) ? author.vocabulary.always_explain : [author.vocabulary.always_explain];
      console.log(`  │  Always explain: ${terms.join(", ")}`);
    }
  }

  // Phrases
  if (author.phrases) {
    console.log("  │");
    console.log("  ├─ PHRASES");
    if (author.phrases.signature) {
      const phrases = Array.isArray(author.phrases.signature) ? author.phrases.signature : [author.phrases.signature];
      console.log(`  │  Signature:`);
      phrases.forEach((p: string) => console.log(`  │    • "${p}"`));
    }
    if (author.phrases.avoid) {
      const phrases = Array.isArray(author.phrases.avoid) ? author.phrases.avoid : [author.phrases.avoid];
      console.log(`  │  Avoid:`);
      phrases.forEach((p: string) => console.log(`  │    ✗ "${p}"`));
    }
  }

  // Opinions
  if (author.opinions) {
    console.log("  │");
    console.log("  ├─ OPINIONS");
    if (author.opinions.strong_positions) {
      const positions = Array.isArray(author.opinions.strong_positions) ? author.opinions.strong_positions : [author.opinions.strong_positions];
      console.log(`  │  Strong positions:`);
      positions.forEach((p: string) => console.log(`  │    • ${p}`));
    }
    if (author.opinions.stay_neutral) {
      const neutral = Array.isArray(author.opinions.stay_neutral) ? author.opinions.stay_neutral : [author.opinions.stay_neutral];
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
  db.close();
}

// ============================================
// Settings
// ============================================

function showSettings(typeOrPlatform?: string): void {
  ensureDb();

  const platformNames = ["linkedin", "instagram", "x"];
  if (typeOrPlatform && platformNames.includes(typeOrPlatform)) {
    showPlatformDefaults(typeOrPlatform);
  } else if (typeOrPlatform) {
    showCompanionProjectDefaults(typeOrPlatform);
  } else {
    showAllSettings();
  }
}

function showPlatformDefaults(platform: string): void {
  const db = getDb();
  const settings = getSettings(db);

  if (!settings) {
    console.error("❌ Settings not found in database.");
    db.close();
    process.exit(1);
  }

  const pd = settings.platform_defaults?.[platform];

  if (!pd) {
    console.error(`❌ No defaults configured for platform: ${platform}`);
    db.close();
    process.exit(1);
  }

  const labels: Record<string, string> = { linkedin: "LinkedIn", instagram: "Instagram", x: "X/Twitter" };
  printHeader(`PLATFORM DEFAULTS: ${labels[platform] || platform.toUpperCase()}`);
  printDivider();

  console.log("");

  // Tone adjustment
  if (pd.tone_adjustment) {
    console.log("  Tone Adjustment:");
    console.log(`    Formality offset: ${pd.tone_adjustment.formality_offset >= 0 ? "+" : ""}${pd.tone_adjustment.formality_offset}`);
    console.log(`    Opinionated offset: ${pd.tone_adjustment.opinionated_offset >= 0 ? "+" : ""}${pd.tone_adjustment.opinionated_offset}`);
  }

  // Length limits
  if (pd.max_words || pd.min_words || pd.hard_max_words) {
    console.log("\n  Length Limits:");
    if (pd.min_words) console.log(`    Min words: ${pd.min_words}`);
    if (pd.max_words) console.log(`    Default max words: ${pd.max_words}`);
    if (pd.hard_max_words) console.log(`    Hard max words: ${pd.hard_max_words}`);
  }

  if (pd.caption_max_chars) {
    console.log("\n  Caption Limits:");
    console.log(`    Max characters: ${pd.caption_max_chars}`);
    if (pd.caption_visible_chars) console.log(`    Visible before fold: ${pd.caption_visible_chars}`);
  }

  if (pd.tweet_max_chars) {
    console.log("\n  Tweet Limits:");
    console.log(`    Max characters per tweet: ${pd.tweet_max_chars}`);
  }

  // Structure
  if (pd.hook_lines) console.log(`\n  Hook lines: ${pd.hook_lines}`);
  if (pd.cta_required !== undefined) console.log(`  CTA required: ${pd.cta_required ? "Yes" : "No"}`);
  if (pd.emojis_encouraged !== undefined) console.log(`  Emojis encouraged: ${pd.emojis_encouraged ? "Yes" : "No"}`);

  // Hashtags
  if (pd.hashtag_count) {
    console.log(`\n  Hashtags: ${pd.hashtag_count.min}-${pd.hashtag_count.max}`);
  }

  // Carousel / Thread
  if (pd.carousel_slides) {
    console.log(`\n  Carousel Slides: ${pd.carousel_slides.min}-${pd.carousel_slides.max} (default ${pd.carousel_slides.default})`);
  }
  if (pd.thread_tweets) {
    console.log(`\n  Thread Tweets: ${pd.thread_tweets.min}-${pd.thread_tweets.max} (default ${pd.thread_tweets.default})`);
  }

  console.log("");
  console.log(`  To modify: /article-writer:settings set platform_defaults.${platform}.<key> <value>`);
  console.log(`  Example: /article-writer:settings set platform_defaults.${platform}.max_words 800`);
  printDivider();
  db.close();
}

function showAllSettings(): void {
  const db = getDb();
  const settings = getSettings(db);

  if (!settings) {
    console.error("❌ Settings not found in database.");
    db.close();
    process.exit(1);
  }

  printHeader("SETTINGS");
  printDivider();

  // Article limits
  if (settings.article_limits) {
    console.log("\n  Article Limits:");
    if (settings.article_limits.max_words) {
      console.log(`    Max words: ${settings.article_limits.max_words}`);
    }
  }

  // Metadata
  const meta = db.query("SELECT * FROM metadata WHERE id = 1").get() as any;
  if (meta) {
    console.log("\n  Metadata:");
    console.log(`    Version: ${meta.version || "unknown"}`);
    console.log(`    Last updated: ${meta.last_updated || "unknown"}`);
  }

  // Companion project defaults summary
  if (settings.companion_project_defaults) {
    console.log("\n  Companion Project Defaults:");
    console.log("  ┌────────────┬─────────────────────────────────┬───────────┐");
    console.log("  │ Type       │ Technologies                    │ Has Tests │");
    console.log("  ├────────────┼─────────────────────────────────┼───────────┤");

    const types = ["code", "node", "python", "document", "diagram", "template", "dataset", "config", "script", "spreadsheet", "other"];

    for (const type of types) {
      const defaults = settings.companion_project_defaults[type];
      if (defaults) {
        const tech = defaults.technologies?.slice(0, 3).join(", ") || "-";
        const techDisplay = tech.length > 30 ? tech.substring(0, 27) + "..." : tech.padEnd(30);
        const hasTests = defaults.has_tests ? "Yes" : "No";
        console.log(`  │ ${type.padEnd(10)} │ ${techDisplay} │ ${hasTests.padEnd(9)} │`);
      }
    }

    console.log("  └────────────┴─────────────────────────────────┴───────────┘");
  }

  // Platform defaults summary
  if (settings.platform_defaults && Object.keys(settings.platform_defaults).length > 0) {
    console.log("\n  Platform Defaults (Social Media):");
    console.log("  ┌────────────┬─────────────┬────────────────────────────────────┐");
    console.log("  │ Platform   │ Tone Adjust │ Key Limits                         │");
    console.log("  ├────────────┼─────────────┼────────────────────────────────────┤");

    const platformLabels: Record<string, string> = { linkedin: "LinkedIn", instagram: "Instagram", x: "X/Twitter" };

    for (const [key, label] of Object.entries(platformLabels)) {
      const pd = settings.platform_defaults[key];
      if (pd) {
        const toneAdj = pd.tone_adjustment
          ? `F${pd.tone_adjustment.formality_offset >= 0 ? "+" : ""}${pd.tone_adjustment.formality_offset}, O${pd.tone_adjustment.opinionated_offset >= 0 ? "+" : ""}${pd.tone_adjustment.opinionated_offset}`
          : "none";
        let limits = "";
        if (pd.max_words) limits += `${pd.max_words}w`;
        if (pd.caption_max_chars) limits += `${pd.caption_max_chars}ch`;
        if (pd.tweet_max_chars) limits += `${pd.tweet_max_chars}ch/tweet`;
        if (pd.hashtag_count) limits += ` #${pd.hashtag_count.min}-${pd.hashtag_count.max}`;
        const limitsDisplay = limits.padEnd(35);
        console.log(`  │ ${label.padEnd(10)} │ ${toneAdj.padEnd(11)} │ ${limitsDisplay}│`);
      }
    }

    console.log("  └────────────┴─────────────┴────────────────────────────────────┘");
    console.log("\n  To see platform details: /article-writer:settings show linkedin");
  }

  console.log("\n  To see type details: /article-writer:settings show <type>");
  console.log("  Example: /article-writer:settings show code");
  printDivider();
  db.close();
}

function showCompanionProjectDefaults(type: string): void {
  const validTypes = ["code", "node", "python", "document", "diagram", "template", "dataset", "config", "script", "spreadsheet", "other"];

  if (!validTypes.includes(type)) {
    console.error(`❌ Unknown companion project type: ${type}`);
    console.log(`\n   Valid types: ${validTypes.join(", ")}`);
    process.exit(1);
  }

  const db = getDb();
  const settings = getSettings(db);

  if (!settings) {
    console.error("❌ Settings not found in database.");
    db.close();
    process.exit(1);
  }

  const defaults = settings.companion_project_defaults?.[type];

  if (!defaults) {
    console.error(`❌ No defaults configured for type: ${type}`);
    db.close();
    process.exit(1);
  }

  printHeader(`COMPANION PROJECT DEFAULTS: ${type.toUpperCase()}`);
  printDivider();

  console.log("");

  if (defaults.technologies) {
    console.log("  Technologies:");
    defaults.technologies.forEach((t: string) => console.log(`    • ${t}`));
  }

  console.log(`\n  Has Tests: ${defaults.has_tests ? "Yes ✓" : "No ✗"}`);
  if (defaults.test_command) {
    console.log(`  Test Command: ${defaults.test_command}`);
  }

  if (defaults.path) {
    console.log(`\n  Default Path: ${defaults.path}`);
  }

  if (defaults.scaffold_command) {
    console.log(`\n  Scaffold Command:`);
    console.log(`    ${defaults.scaffold_command}`);
  }

  if (defaults.post_scaffold && defaults.post_scaffold.length > 0) {
    console.log(`\n  Post-Scaffold Commands:`);
    defaults.post_scaffold.forEach((cmd: string, i: number) => {
      console.log(`    ${i + 1}. ${cmd}`);
    });
  }

  if (defaults.verification) {
    const v = defaults.verification;
    if (v.install_command) console.log(`\n  Install Command: ${v.install_command}`);
    if (v.setup_commands && v.setup_commands.length > 0) {
      console.log(`\n  Setup Commands (for users):`);
      v.setup_commands.forEach((cmd: string, i: number) => {
        console.log(`    ${i + 1}. ${cmd}`);
      });
    }
    if (v.run_command) console.log(`\n  Run Command: ${v.run_command}`);
    if (v.test_command) console.log(`  Test Command: ${v.test_command}`);
  }

  if (defaults.env_setup) {
    console.log(`\n  Environment Setup:`);
    for (const [key, value] of Object.entries(defaults.env_setup)) {
      console.log(`    ${key}=${value}`);
    }
  }

  if (defaults.required_structure && defaults.required_structure.length > 0) {
    console.log(`\n  Required Structure:`);
    defaults.required_structure.forEach((f: string) => console.log(`    ${f}`));
  }

  if (defaults.notes) {
    console.log(`\n  Notes:`);
    console.log(`    ${defaults.notes}`);
  }

  console.log("");
  console.log("  To modify: /article-writer:settings set <key> <value>");
  console.log(`  Example: /article-writer:settings set ${type}.technologies '["Laravel 11", "Pest 3"]'`);
  printDivider();
  db.close();
}

// ============================================
// Queue Summary
// ============================================

function showQueueSummary(): void {
  ensureDb();
  const db = getDb();

  const total = (db.query("SELECT COUNT(*) as c FROM articles").get() as any).c;

  printHeader("ARTICLE QUEUE");
  printDivider();

  if (total === 0) {
    console.log("\n  No articles in queue.");
    console.log("  Run /article-writer:article <topic> to add one.\n");
    db.close();
    return;
  }

  console.log(`\n  Total: ${total} articles\n`);

  // By status
  console.log("  By Status:");
  const statusRows = db.query("SELECT status, COUNT(*) as count FROM articles GROUP BY status ORDER BY count DESC").all() as any[];
  for (const r of statusRows) {
    const emoji = r.status === "pending" ? "⏳" :
                  r.status === "in_progress" ? "🔄" :
                  r.status === "draft" ? "📝" :
                  r.status === "review" ? "👀" :
                  r.status === "published" ? "✅" :
                  r.status === "archived" ? "📦" : "❓";
    console.log(`    ${emoji} ${r.status}: ${r.count}`);
  }

  // By author
  const authorRows = db.query("SELECT COALESCE(author_id, 'unassigned') as author, COUNT(*) as count FROM articles GROUP BY author ORDER BY count DESC").all() as any[];
  if (authorRows.length > 1 || (authorRows.length === 1 && authorRows[0].author !== "unassigned")) {
    console.log("\n  By Author:");
    for (const r of authorRows) {
      console.log(`    • ${r.author}: ${r.count}`);
    }
  }

  // By platform
  const platformRows = db.query("SELECT platform, COUNT(*) as count FROM articles GROUP BY platform ORDER BY count DESC").all() as any[];
  if (platformRows.length > 1 || (platformRows.length === 1 && platformRows[0].platform !== "blog")) {
    const platformLabels: Record<string, string> = { blog: "Blog", linkedin: "LinkedIn", instagram: "Instagram", x: "X/Twitter" };
    console.log("\n  By Platform:");
    for (const r of platformRows) {
      console.log(`    • ${platformLabels[r.platform] || r.platform}: ${r.count}`);
    }
  }

  // Derived posts
  const derivedCount = (db.query("SELECT COUNT(*) as c FROM articles WHERE derived_from IS NOT NULL").get() as any).c;
  if (derivedCount > 0) {
    console.log(`\n  Derived from blog posts: ${derivedCount}`);
  }

  // Top areas
  console.log("\n  Top Areas:");
  const areaRows = db.query("SELECT area, COUNT(*) as count FROM articles GROUP BY area ORDER BY count DESC LIMIT 5").all() as any[];
  for (const r of areaRows) {
    console.log(`    • ${r.area}: ${r.count}`);
  }

  console.log("\n  For full list: /article-writer:queue list");
  printDivider();
  db.close();
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
      listAuthors();
      break;
    case "author":
      if (!subArg) {
        console.error("❌ Please specify an author ID");
        console.log("   Usage: bun run show.ts author <id>");
        process.exit(1);
      }
      showAuthor(subArg);
      break;
    case "settings":
      showSettings(subArg);
      break;
    case "queue":
      showQueueSummary();
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
