#!/usr/bin/env bun
/**
 * article-stats.ts - Article statistics and queue operations (SQLite)
 * Replaces article-stats.sh (jq-based) with zero external dependencies.
 *
 * Usage: bun run article-stats.ts [mode] [args...]
 *
 * Read-only Modes:
 *   --summary          Full text summary (default)
 *   --json             Full JSON output for programmatic use
 *   --next             Next recommended article
 *   --next5            Next 5 recommended articles
 *   --status           Article counts by status
 *   --area             Article counts by area
 *   --difficulty       Article counts by difficulty
 *   --author           Article counts by author
 *   --effort           Article counts by estimated effort
 *   --platform         Article counts by platform
 *   --remaining        Count of remaining articles
 *   --completion       Completion statistics
 *   --stuck            Show articles stuck in_progress
 *
 * Article Query Modes:
 *   --get <id> [key]   Get article by ID, optionally extract specific key
 *   --ids              List all article IDs
 *   --pending-ids      List pending article IDs
 *
 * Write Modes:
 *   --set-status <status> <id1> [id2...]  Update status for articles
 *   --set-error <id> <message>            Set error_note
 *   --clear-error <id>                    Clear error_note
 */

import { getDb, dbExists, rowToArticle } from "./db";

function ensureDb() {
  if (!dbExists()) {
    console.error("Error: Database not found. Run /article-writer:init first.");
    process.exit(1);
  }
}

// ============================================
// Read-only modes
// ============================================

function getStatusCounts(): void {
  const db = getDb();
  const rows = db.query("SELECT status, COUNT(*) as count FROM articles GROUP BY status ORDER BY status").all() as any[];
  for (const r of rows) {
    console.log(`${r.status}: ${r.count}`);
  }
  db.close();
}

function getAreaCounts(): void {
  const db = getDb();
  const rows = db.query("SELECT area, COUNT(*) as count FROM articles GROUP BY area ORDER BY count DESC").all() as any[];
  for (const r of rows) {
    console.log(`${r.area}: ${r.count}`);
  }
  db.close();
}

function getDifficultyCounts(): void {
  const db = getDb();
  const rows = db.query("SELECT difficulty, COUNT(*) as count FROM articles GROUP BY difficulty ORDER BY difficulty").all() as any[];
  for (const r of rows) {
    console.log(`${r.difficulty}: ${r.count}`);
  }
  db.close();
}

function getAuthorCounts(): void {
  const db = getDb();
  const rows = db.query("SELECT COALESCE(author_id, '(default)') as author, COUNT(*) as count FROM articles GROUP BY author ORDER BY count DESC").all() as any[];
  for (const r of rows) {
    console.log(`${r.author}: ${r.count}`);
  }
  db.close();
}

function getEffortCounts(): void {
  const db = getDb();
  const rows = db.query("SELECT estimated_effort, COUNT(*) as count FROM articles GROUP BY estimated_effort ORDER BY estimated_effort").all() as any[];
  for (const r of rows) {
    console.log(`${r.estimated_effort}: ${r.count}`);
  }
  db.close();
}

function getRemainingCount(): void {
  const db = getDb();
  const row = db.query("SELECT COUNT(*) as count FROM articles WHERE status NOT IN ('published', 'archived')").get() as any;
  console.log(`Remaining articles: ${row.count}`);
  db.close();
}

function getCompletionStats(): void {
  const db = getDb();
  const total = (db.query("SELECT COUNT(*) as c FROM articles").get() as any).c;
  const published = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='published'").get() as any).c;
  const draft = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='draft'").get() as any).c;
  const review = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='review'").get() as any).c;
  const inProgress = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='in_progress'").get() as any).c;
  const pending = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='pending'").get() as any).c;
  const archived = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='archived'").get() as any).c;
  const remaining = (db.query("SELECT COUNT(*) as c FROM articles WHERE status NOT IN ('published','archived')").get() as any).c;
  const pct = total > 0 ? Math.floor((published / total) * 100) : 0;

  console.log(`Total: ${total}`);
  console.log(`Published: ${published}`);
  console.log(`Draft: ${draft}`);
  console.log(`Review: ${review}`);
  console.log(`In Progress: ${inProgress}`);
  console.log(`Pending: ${pending}`);
  console.log(`Archived: ${archived}`);
  console.log(`Remaining: ${remaining}`);
  console.log(`Completion: ${pct}%`);
  db.close();
}

function getStuckArticles(): void {
  const db = getDb();
  const rows = db.query("SELECT id, title, area, author_id, error_note FROM articles WHERE status='in_progress'").all() as any[];
  if (rows.length === 0) {
    console.log("No articles stuck in_progress");
  } else {
    for (const r of rows) {
      console.log(`ID: ${r.id}`);
      console.log(`Title: ${r.title}`);
      console.log(`Area: ${r.area}`);
      console.log(`Author: ${r.author_id || "(default)"}`);
      console.log(`Error: ${r.error_note || "none"}`);
      console.log("---");
    }
  }
  db.close();
}

function getNextArticle(): void {
  const db = getDb();
  const row = db.query("SELECT * FROM articles WHERE status='pending' ORDER BY id ASC LIMIT 1").get() as any;
  if (!row) {
    console.log("No pending articles found");
  } else {
    const langs = row.author_languages ? JSON.parse(row.author_languages) : ["default"];
    console.log(`ID: ${row.id}`);
    console.log(`Title: ${row.title}`);
    console.log(`Area: ${row.area}`);
    console.log(`Difficulty: ${row.difficulty}`);
    console.log(`Content Type: ${row.content_type}`);
    console.log(`Effort: ${row.estimated_effort}`);
    console.log(`Author: ${row.author_name || row.author_id || "(default)"}`);
    console.log(`Languages: ${langs.join(", ")}`);
  }
  db.close();
}

function getNext5Articles(): void {
  const db = getDb();
  const rows = db.query("SELECT id, title, area, difficulty FROM articles WHERE status='pending' ORDER BY id ASC LIMIT 5").all() as any[];
  if (rows.length === 0) {
    console.log("No pending articles found");
  } else {
    rows.forEach((r, i) => {
      console.log(`${i + 1}. [ID ${r.id}] ${r.title} (${r.area}, ${r.difficulty})`);
    });
  }
  db.close();
}

function getPlatformCounts(): void {
  const db = getDb();
  const rows = db.query("SELECT platform, COUNT(*) as count FROM articles GROUP BY platform ORDER BY count DESC").all() as any[];
  for (const r of rows) {
    console.log(`${r.platform}: ${r.count}`);
  }
  db.close();
}

function getSummary(): void {
  console.log("=== Article Queue Statistics ===");
  console.log("");
  getCompletionStats();
  console.log("");
  console.log("--- By Status ---");
  getStatusCounts();
  console.log("");
  console.log("--- By Area ---");
  getAreaCounts();
  console.log("");
  console.log("--- By Difficulty ---");
  getDifficultyCounts();
  console.log("");
  console.log("--- By Author ---");
  getAuthorCounts();
  console.log("");
  console.log("--- By Platform ---");
  getPlatformCounts();
}

function getJsonStats(): void {
  const db = getDb();

  const total = (db.query("SELECT COUNT(*) as c FROM articles").get() as any).c;
  const published = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='published'").get() as any).c;
  const draft = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='draft'").get() as any).c;
  const review = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='review'").get() as any).c;
  const inProgress = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='in_progress'").get() as any).c;
  const pending = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='pending'").get() as any).c;
  const archived = (db.query("SELECT COUNT(*) as c FROM articles WHERE status='archived'").get() as any).c;
  const remaining = (db.query("SELECT COUNT(*) as c FROM articles WHERE status NOT IN ('published','archived')").get() as any).c;
  const pct = total > 0 ? Math.floor((published / total) * 100) : 0;

  const byStatus: any = {};
  (db.query("SELECT status, COUNT(*) as c FROM articles GROUP BY status").all() as any[]).forEach(r => byStatus[r.status] = r.c);

  const byArea: any = {};
  (db.query("SELECT area, COUNT(*) as c FROM articles GROUP BY area ORDER BY c DESC").all() as any[]).forEach(r => byArea[r.area] = r.c);

  const byDifficulty: any = {};
  (db.query("SELECT difficulty, COUNT(*) as c FROM articles GROUP BY difficulty").all() as any[]).forEach(r => byDifficulty[r.difficulty] = r.c);

  const byAuthor: any = {};
  (db.query("SELECT COALESCE(author_id,'(default)') as a, COUNT(*) as c FROM articles GROUP BY a").all() as any[]).forEach(r => byAuthor[r.a] = r.c);

  const byEffort: any = {};
  (db.query("SELECT estimated_effort, COUNT(*) as c FROM articles GROUP BY estimated_effort").all() as any[]).forEach(r => byEffort[r.estimated_effort] = r.c);

  const byPlatform: any = {};
  (db.query("SELECT platform, COUNT(*) as c FROM articles GROUP BY platform ORDER BY c DESC").all() as any[]).forEach(r => byPlatform[r.platform] = r.c);

  const stuckRows = db.query("SELECT id, title, error_note FROM articles WHERE status='in_progress'").all() as any[];
  const stuckArticles = stuckRows.map(r => ({ id: r.id, title: r.title, error: r.error_note }));

  const nextRow = db.query("SELECT id, title, area, difficulty, author_id FROM articles WHERE status='pending' ORDER BY id LIMIT 1").get() as any;
  const nextArticle = nextRow ? { id: nextRow.id, title: nextRow.title, area: nextRow.area, difficulty: nextRow.difficulty, author: nextRow.author_id || "(default)" } : null;

  const next5Rows = db.query("SELECT id, title, area, difficulty FROM articles WHERE status='pending' ORDER BY id LIMIT 5").all() as any[];
  const next5 = next5Rows.map(r => ({ id: r.id, title: r.title, area: r.area, difficulty: r.difficulty }));

  const result = {
    summary: { total, published, draft, review, in_progress: inProgress, pending, archived, remaining, completion_percent: pct },
    by_status: byStatus,
    by_area: byArea,
    by_difficulty: byDifficulty,
    by_author: byAuthor,
    by_effort: byEffort,
    by_platform: byPlatform,
    stuck_articles: stuckArticles,
    next_article: nextArticle,
    next_5_articles: next5,
  };

  console.log(JSON.stringify(result, null, 2));
  db.close();
}

// ============================================
// Query modes
// ============================================

function getArticleById(idStr: string, key?: string): void {
  if (!idStr) {
    console.error("Error: Article ID required");
    process.exit(1);
  }

  const id = parseInt(idStr, 10);
  const db = getDb();
  const row = db.query("SELECT * FROM articles WHERE id = ?").get(id) as any;

  if (!row) {
    console.error(`Error: Article '${id}' not found`);
    db.close();
    process.exit(1);
  }

  const article = rowToArticle(row);

  if (!key) {
    console.log(JSON.stringify(article, null, 2));
  } else {
    // Handle dot-path extraction
    const parts = key.split(".");
    let value: any = article;
    for (const part of parts) {
      if (value === undefined || value === null) break;
      value = value[part];
    }
    if (value === undefined || value === null) {
      console.log("null");
    } else if (typeof value === "object") {
      console.log(JSON.stringify(value));
    } else {
      console.log(String(value));
    }
  }
  db.close();
}

function getAllIds(): void {
  const db = getDb();
  const rows = db.query("SELECT id FROM articles ORDER BY id").all() as any[];
  for (const r of rows) {
    console.log(r.id);
  }
  db.close();
}

function getPendingIds(): void {
  const db = getDb();
  const rows = db.query("SELECT id FROM articles WHERE status='pending' ORDER BY id").all() as any[];
  for (const r of rows) {
    console.log(r.id);
  }
  db.close();
}

// ============================================
// Write modes
// ============================================

function setArticleStatus(newStatus: string, ids: string[]): void {
  const validStatuses = ["pending", "in_progress", "draft", "review", "published", "archived"];
  if (!validStatuses.includes(newStatus)) {
    console.error(`Error: Invalid status '${newStatus}'`);
    console.error(`Valid statuses: ${validStatuses.join(", ")}`);
    process.exit(1);
  }

  if (ids.length === 0) {
    console.error("Error: At least one article ID required");
    process.exit(1);
  }

  const db = getDb();
  const now = new Date().toISOString();
  let updated = 0;

  const updateStmt = db.prepare(`
    UPDATE articles SET
      status = ?,
      updated_at = ?,
      published_at = CASE WHEN ? = 'published' THEN ? ELSE published_at END,
      written_at = CASE WHEN ? = 'draft' THEN COALESCE(written_at, ?) ELSE written_at END
    WHERE id = ?
  `);

  const transaction = db.transaction(() => {
    for (const idStr of ids) {
      const id = parseInt(idStr, 10);
      const result = updateStmt.run(newStatus, now, newStatus, now, newStatus, now, id);
      if (result.changes > 0) updated++;
    }
  });

  transaction();

  if (updated === ids.length) {
    console.log(`Successfully updated ${updated} article(s) to status '${newStatus}':`);
    for (const id of ids) {
      console.log(`  - ID ${id}`);
    }
  } else {
    console.error(`Warning: Requested ${ids.length} article(s), but only ${updated} were updated`);
    console.error("Some article IDs may not exist.");
  }

  db.close();
}

function setArticleError(idStr: string, message: string): void {
  if (!idStr || !message) {
    console.error("Error: Article ID and error message required");
    process.exit(1);
  }

  const db = getDb();
  const id = parseInt(idStr, 10);
  db.run("UPDATE articles SET error_note = ?, updated_at = datetime('now') WHERE id = ?", [message, id]);
  console.log(`Set error_note for article ID ${id}`);
  db.close();
}

function clearArticleError(idStr: string): void {
  if (!idStr) {
    console.error("Error: Article ID required");
    process.exit(1);
  }

  const db = getDb();
  const id = parseInt(idStr, 10);
  db.run("UPDATE articles SET error_note = NULL, updated_at = datetime('now') WHERE id = ?", [id]);
  console.log(`Cleared error_note for article ID ${id}`);
  db.close();
}

// ============================================
// Help
// ============================================

function showHelp(): void {
  console.log(`Usage: bun run article-stats.ts [mode] [args...]

Read-only Modes:
  --summary          Full text summary (default)
  --json             Full JSON output for programmatic use
  --next             Next recommended article
  --next5            Next 5 recommended articles
  --status           Article counts by status
  --area             Article counts by area
  --difficulty       Article counts by difficulty
  --author           Article counts by author
  --effort           Article counts by estimated effort
  --platform         Article counts by platform
  --remaining        Count of remaining articles
  --completion       Completion statistics
  --stuck            Show articles stuck in_progress

Article Query Modes:
  --get <id> [key]   Get article by ID, optionally extract specific key
                     Examples: --get 5
                               --get 5 title
                               --get 5 status
                               --get 5 author.id
  --ids              List all article IDs
  --pending-ids      List pending article IDs

Write Modes (modify database):
  --set-status <status> <id1> [id2...]  Update status for one or more articles
                     Valid statuses: pending, in_progress, draft, review,
                                     published, archived
  --set-error <id> <message>  Set error_note for an article
  --clear-error <id>          Clear error_note for an article

  --help, -h         Show this help`);
}

// ============================================
// Main
// ============================================

const args = process.argv.slice(2);

// Handle --help as first argument (before db check)
if (args[0] === "--help" || args[0] === "-h") {
  showHelp();
  process.exit(0);
}

// Detect if first arg is a file path (legacy compatibility)
// Old usage: article-stats.sh <path> --mode
// New usage: article-stats.ts --mode
let modeIndex = 0;
if (args[0] && !args[0].startsWith("--")) {
  // First arg looks like a file path (legacy usage) — skip it
  modeIndex = 1;
}

const mode = args[modeIndex] || "--summary";

ensureDb();

switch (mode) {
  case "--summary":
    getSummary();
    break;
  case "--json":
    getJsonStats();
    break;
  case "--next":
    console.log("=== Next Recommended Article ===");
    getNextArticle();
    break;
  case "--next5":
    console.log("=== Next 5 Recommended Articles ===");
    getNext5Articles();
    break;
  case "--status":
    getStatusCounts();
    break;
  case "--area":
    getAreaCounts();
    break;
  case "--difficulty":
    getDifficultyCounts();
    break;
  case "--author":
    getAuthorCounts();
    break;
  case "--effort":
    getEffortCounts();
    break;
  case "--platform":
    getPlatformCounts();
    break;
  case "--remaining":
    getRemainingCount();
    break;
  case "--completion":
    getCompletionStats();
    break;
  case "--stuck":
    console.log("=== Articles Stuck in Progress ===");
    getStuckArticles();
    break;
  case "--ids":
    getAllIds();
    break;
  case "--pending-ids":
    getPendingIds();
    break;
  case "--get":
    getArticleById(args[modeIndex + 1], args[modeIndex + 2]);
    break;
  case "--set-status": {
    const newStatus = args[modeIndex + 1];
    const ids = args.slice(modeIndex + 2);
    setArticleStatus(newStatus, ids);
    break;
  }
  case "--set-error":
    setArticleError(args[modeIndex + 1], args[modeIndex + 2]);
    break;
  case "--clear-error":
    clearArticleError(args[modeIndex + 1]);
    break;
  case "--help":
  case "-h":
    showHelp();
    break;
  default:
    console.error(`Unknown mode: ${mode}`);
    console.error("Use --help for usage information");
    process.exit(1);
}
