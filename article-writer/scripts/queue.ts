#!/usr/bin/env bun
/**
 * Article queue management (SQLite)
 * Usage: bun run queue.ts <command> [args]
 *
 * Commands:
 *   status              Show queue summary
 *   list [filter]       List articles (pending, area:X, author:X, lang:X, difficulty:X)
 *   show <id>           Show article details
 *   update <id> <f:v>   Update article field
 *   next [n]            Get next n pending articles
 *   backup              Create backup
 */

import { copyFileSync, existsSync } from "fs";
import { join } from "path";
import { getDb, dbExists, DB_PATH, rowToArticle, rowToAuthor } from "./db";

function ensureDb(): void {
  if (!dbExists()) {
    console.error("Database not found. Run /article-writer:init first.");
    process.exit(1);
  }
}

function showStatus(): void {
  ensureDb();
  const db = getDb();

  const total = (db.query("SELECT COUNT(*) as c FROM articles").get() as any).c;

  console.log("\n📊 Article Queue Status");
  console.log("========================");
  console.log(`Total: ${total}`);
  console.log("");

  const statusIcons: Record<string, string> = {
    pending: "⏳", in_progress: "🔄", draft: "📝",
    review: "👀", published: "✅", archived: "📦",
  };

  const statusRows = db.query("SELECT status, COUNT(*) as count FROM articles GROUP BY status").all() as any[];
  for (const r of statusRows) {
    const icon = statusIcons[r.status] || "❓";
    console.log(`${icon} ${r.status}: ${r.count}`);
  }

  // Next pending
  const nextRow = db.query("SELECT id, title, author_id, author_name FROM articles WHERE status='pending' ORDER BY id LIMIT 1").get() as any;
  if (nextRow) {
    const authorName = nextRow.author_name || nextRow.author_id || "(default)";
    console.log(`\n📌 Next pending: ID ${nextRow.id}`);
    console.log(`   "${nextRow.title}"`);
    console.log(`   Author: ${authorName}`);
  }

  // Stuck articles
  const stuckRows = db.query("SELECT id, title FROM articles WHERE status='in_progress'").all() as any[];
  if (stuckRows.length > 0) {
    console.log(`\n⚠️  In progress (may be stuck):`);
    for (const r of stuckRows) {
      console.log(`   ID ${r.id} - "${r.title}"`);
    }
  }

  // By area (pending only)
  const areaRows = db.query("SELECT area, COUNT(*) as count FROM articles WHERE status='pending' GROUP BY area ORDER BY count DESC LIMIT 5").all() as any[];
  if (areaRows.length > 0) {
    console.log("\n📂 Pending by Area:");
    for (const r of areaRows) {
      console.log(`   ${r.area}: ${r.count}`);
    }
  }

  // By author (pending only)
  const authorRows = db.query("SELECT COALESCE(author_id, '(default)') as author, COUNT(*) as count FROM articles WHERE status='pending' GROUP BY author").all() as any[];
  if (authorRows.length > 1) {
    console.log("\n✍️  Pending by Author:");
    for (const r of authorRows) {
      console.log(`   ${r.author}: ${r.count}`);
    }
  }

  console.log("");
  db.close();
}

function listArticles(filter?: string): void {
  ensureDb();
  const db = getDb();

  let query = "SELECT * FROM articles";
  const params: any[] = [];
  const conditions: string[] = [];

  if (filter) {
    const statusFilters = ["pending", "draft", "review", "published", "in_progress", "archived"];
    if (statusFilters.includes(filter)) {
      conditions.push("status = ?");
      params.push(filter);
    } else if (filter.startsWith("area:")) {
      conditions.push("LOWER(area) = LOWER(?)");
      params.push(filter.slice(5));
    } else if (filter.startsWith("difficulty:")) {
      conditions.push("LOWER(difficulty) = LOWER(?)");
      params.push(filter.slice(11));
    } else if (filter.startsWith("author:")) {
      conditions.push("author_id = ?");
      params.push(filter.slice(7));
    } else if (filter.startsWith("lang:")) {
      conditions.push("author_languages LIKE ?");
      params.push(`%${filter.slice(5)}%`);
    }
  } else {
    conditions.push("status = 'pending'");
  }

  if (conditions.length > 0) {
    query += " WHERE " + conditions.join(" AND ");
  }
  query += " ORDER BY id ASC";

  const rows = db.query(query).all(...params) as any[];

  console.log(`\n📋 Articles (${rows.length} found)\n`);

  const icons: Record<string, string> = {
    pending: "⏳", in_progress: "🔄", draft: "📝",
    review: "👀", published: "✅", archived: "📦",
  };

  for (const row of rows.slice(0, 20)) {
    const icon = icons[row.status] || "📄";
    const langs = row.author_languages ? JSON.parse(row.author_languages).join(", ") : "default";
    console.log(`${icon} [${row.id}] ${row.title}`);
    console.log(`   ${row.area} | ${row.difficulty} | ${row.content_type}`);
    console.log(`   Author: ${row.author_name || row.author_id || "(default)"} | Languages: ${langs}`);
  }

  if (rows.length > 20) {
    console.log(`\n... and ${rows.length - 20} more`);
  }

  db.close();
}

function showArticle(id: number): void {
  ensureDb();
  const db = getDb();
  const row = db.query("SELECT * FROM articles WHERE id = ?").get(id) as any;

  if (!row) {
    console.error(`Article ID ${id} not found`);
    db.close();
    return;
  }

  const article = rowToArticle(row);

  console.log(`\n📄 Article #${article.id}`);
  console.log("─".repeat(50));
  console.log(`Title: ${article.title}`);
  console.log(`Status: ${article.status}`);
  console.log(`Subject: ${article.subject}`);
  console.log(`Area: ${article.area}`);
  console.log(`Difficulty: ${article.difficulty}`);
  console.log(`Type: ${article.content_type}`);
  console.log(`Effort: ${article.estimated_effort}`);
  console.log(`Versions: ${article.versions}`);
  console.log(`Series: ${article.series_potential}`);

  console.log(`\n✍️  Author:`);
  if (article.author) {
    console.log(`   ID: ${article.author.id}`);
    console.log(`   Name: ${article.author.name || "(not set)"}`);
    console.log(`   Languages: ${article.author.languages?.join(", ") || "(not set)"}`);
  } else {
    console.log("   (using default author)");
  }

  console.log(`\nPrerequisites: ${article.prerequisites}`);
  console.log(`References: ${article.reference_urls}`);
  console.log(`Tags: ${article.tags}`);
  console.log(`Relevance: ${article.relevance}`);

  if (article.output_folder) {
    console.log(`\n📁 Output Folder: ${article.output_folder}`);
  }

  if (article.output_files && article.output_files.length > 0) {
    console.log("\n📄 Output Files:");
    for (const f of article.output_files) {
      console.log(`   ${f.language}: ${f.path}`);
      if (f.translated_at) {
        console.log(`            Completed: ${f.translated_at}`);
      }
    }
  }

  console.log("\n📅 Dates:");
  if (article.created_at) console.log(`   Created: ${article.created_at}`);
  if (article.written_at) console.log(`   Written: ${article.written_at}`);
  if (article.published_at) console.log(`   Published: ${article.published_at}`);
  if (article.updated_at) console.log(`   Updated: ${article.updated_at}`);

  if (article.error_note) {
    console.log(`\n⚠️  Error: ${article.error_note}`);
  }

  db.close();
}

function updateArticle(id: number, update: string): void {
  ensureDb();
  const db = getDb();

  const existing = db.query("SELECT id FROM articles WHERE id = ?").get(id) as any;
  if (!existing) {
    console.error(`Article ID ${id} not found`);
    db.close();
    return;
  }

  const colonIndex = update.indexOf(":");
  if (colonIndex === -1) {
    console.error("Update format: field:value");
    db.close();
    return;
  }

  const field = update.slice(0, colonIndex);
  const value = update.slice(colonIndex + 1);

  const validFields = [
    "status", "output_folder", "error_note",
    "created_at", "written_at", "published_at",
  ];

  if (!validFields.includes(field)) {
    console.error(`Invalid field. Valid: ${validFields.join(", ")}`);
    db.close();
    return;
  }

  db.run(
    `UPDATE articles SET ${field} = ?, updated_at = datetime('now') WHERE id = ?`,
    [value, id]
  );
  console.log(`✅ Updated article ${id}: ${field} = ${value}`);
  db.close();
}

function getNext(n: number = 1): void {
  ensureDb();
  const db = getDb();

  const rows = db.query("SELECT * FROM articles WHERE status='pending' ORDER BY id ASC LIMIT ?").all(n) as any[];

  if (rows.length === 0) {
    console.log("No pending articles");
    db.close();
    return;
  }

  const articles = rows.map(rowToArticle);
  console.log(JSON.stringify(articles, null, 2));
  db.close();
}

function backup(): void {
  ensureDb();
  const backupPath = DB_PATH + ".backup";
  copyFileSync(DB_PATH, backupPath);
  console.log(`✅ Backup created: ${backupPath}`);
}

// Main
const args = process.argv.slice(2);
const command = args[0];

switch (command) {
  case "status":
    showStatus();
    break;
  case "list":
    listArticles(args[1]);
    break;
  case "show":
    showArticle(parseInt(args[1], 10));
    break;
  case "update":
    updateArticle(parseInt(args[1], 10), args[2]);
    break;
  case "next":
    getNext(parseInt(args[1], 10) || 1);
    break;
  case "backup":
    backup();
    break;
  default:
    console.log(`
Article Queue Management

Usage: bun run queue.ts <command> [args]

Commands:
  status              Show queue summary
  list [filter]       List articles
                      Filters: pending, draft, area:X, author:X, lang:X
  show <id>           Show article details
  update <id> <f:v>   Update field
  next [n]            Get next n pending as JSON
  backup              Create backup
`);
}
