#!/usr/bin/env bun
/**
 * Article queue management with author support
 * Usage: bun run queue.ts <command> [args]
 * 
 * Commands:
 *   status              Show queue summary
 *   list [filter]       List articles (pending, area:X, author:X, lang:X)
 *   show <id>           Show article details
 *   update <id> <f:v>   Update article field
 *   next [n]            Get next n pending articles
 *   backup              Create backup
 */

import { readFile, writeFile, copyFile, stat } from "fs/promises";
import { join } from "path";

const CONFIG_DIR = ".article_writer";
const QUEUE_FILE = join(CONFIG_DIR, "article_tasks.json");
const AUTHORS_FILE = join(CONFIG_DIR, "authors.json");
const BACKUP_FILE = join(CONFIG_DIR, "article_tasks.backup.json");

interface Author {
  id: string;
  name: string;
  languages: string[];
}

interface OutputFile {
  language: string;
  path: string;
  translated_at?: string;
}

interface Article {
  id: number;
  title: string;
  subject: string;
  area: string;
  tags: string;
  difficulty: string;
  relevance: string;
  content_type: string;
  estimated_effort: string;
  versions: string;
  series_potential: string;
  prerequisites: string;
  reference_urls: string;
  author?: {
    id: string;
    name?: string;
    languages?: string[];
  };
  status: string;
  output_folder?: string;
  output_files?: OutputFile[];
  created_at?: string;
  written_at?: string;
  published_at?: string;
  updated_at?: string;
  error_note?: string;
}

interface Queue {
  $schema?: string;
  metadata?: {
    version: string;
    last_updated: string;
    total_count: number;
  };
  articles: Article[];
}

interface Authors {
  authors: Author[];
}

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function loadQueue(): Promise<Queue> {
  if (!(await exists(QUEUE_FILE))) {
    console.error(`Queue file not found: ${QUEUE_FILE}`);
    console.error("Run /article-writer:init first.");
    process.exit(1);
  }

  const content = await readFile(QUEUE_FILE, "utf-8");
  const data = JSON.parse(content);
  return Array.isArray(data) ? { articles: data } : data;
}

async function loadAuthors(): Promise<Authors> {
  try {
    const content = await readFile(AUTHORS_FILE, "utf-8");
    return JSON.parse(content);
  } catch {
    return { authors: [] };
  }
}

async function saveQueue(queue: Queue): Promise<void> {
  if (queue.metadata) {
    queue.metadata.last_updated = new Date().toISOString();
    queue.metadata.total_count = queue.articles.length;
  }
  await writeFile(QUEUE_FILE, JSON.stringify(queue, null, 2));
}

async function backup(): Promise<void> {
  await copyFile(QUEUE_FILE, BACKUP_FILE);
  console.log(`✅ Backup created: ${BACKUP_FILE}`);
}

function showStatus(queue: Queue, authors: Authors): void {
  const articles = queue.articles;
  const byStatus: Record<string, number> = {};
  const byArea: Record<string, number> = {};
  const byAuthor: Record<string, number> = {};

  for (const a of articles) {
    byStatus[a.status] = (byStatus[a.status] || 0) + 1;
    if (a.status === "pending") {
      byArea[a.area] = (byArea[a.area] || 0) + 1;
      const authorId = a.author?.id || "(default)";
      byAuthor[authorId] = (byAuthor[authorId] || 0) + 1;
    }
  }

  console.log("\n📊 Article Queue Status");
  console.log("========================");
  console.log(`Total: ${articles.length}`);
  console.log("");
  
  const statusIcons: Record<string, string> = {
    pending: "⏳", in_progress: "🔄", draft: "📝",
    review: "👀", published: "✅", archived: "📦"
  };

  for (const [status, icon] of Object.entries(statusIcons)) {
    if (byStatus[status]) {
      console.log(`${icon} ${status}: ${byStatus[status]}`);
    }
  }

  const nextPending = articles.find(a => a.status === "pending");
  if (nextPending) {
    const authorName = nextPending.author?.name || authors.authors[0]?.name || "Default";
    console.log(`\n📌 Next pending: ID ${nextPending.id}`);
    console.log(`   "${nextPending.title}"`);
    console.log(`   Author: ${authorName}`);
  }

  const stuck = articles.filter(a => a.status === "in_progress");
  if (stuck.length > 0) {
    console.log(`\n⚠️  In progress (may be stuck):`);
    for (const a of stuck) {
      console.log(`   ID ${a.id} - "${a.title}"`);
    }
  }

  if (Object.keys(byArea).length > 0) {
    console.log("\n📂 Pending by Area:");
    const sorted = Object.entries(byArea).sort((a, b) => b[1] - a[1]);
    for (const [area, count] of sorted.slice(0, 5)) {
      console.log(`   ${area}: ${count}`);
    }
  }

  if (Object.keys(byAuthor).length > 1) {
    console.log("\n✍️  Pending by Author:");
    for (const [author, count] of Object.entries(byAuthor)) {
      console.log(`   ${author}: ${count}`);
    }
  }

  console.log("");
}

function listArticles(queue: Queue, filter?: string): void {
  let articles = queue.articles;

  if (filter) {
    const statusFilters = ["pending", "draft", "review", "published", "in_progress", "archived"];
    if (statusFilters.includes(filter)) {
      articles = articles.filter(a => a.status === filter);
    } else if (filter.startsWith("area:")) {
      const area = filter.slice(5);
      articles = articles.filter(a => a.area.toLowerCase() === area.toLowerCase());
    } else if (filter.startsWith("difficulty:")) {
      const diff = filter.slice(11);
      articles = articles.filter(a => a.difficulty.toLowerCase() === diff.toLowerCase());
    } else if (filter.startsWith("author:")) {
      const authorId = filter.slice(7);
      articles = articles.filter(a => a.author?.id === authorId);
    } else if (filter.startsWith("lang:")) {
      const lang = filter.slice(5);
      articles = articles.filter(a => a.author?.languages?.includes(lang));
    }
  } else {
    articles = articles.filter(a => a.status === "pending");
  }

  console.log(`\n📋 Articles (${articles.length} found)\n`);
  
  const icons: Record<string, string> = {
    pending: "⏳", in_progress: "🔄", draft: "📝",
    review: "👀", published: "✅", archived: "📦"
  };

  for (const a of articles.slice(0, 20)) {
    const icon = icons[a.status] || "📄";
    const langs = a.author?.languages?.join(", ") || "default";
    console.log(`${icon} [${a.id}] ${a.title}`);
    console.log(`   ${a.area} | ${a.difficulty} | ${a.content_type}`);
    console.log(`   Author: ${a.author?.name || "(default)"} | Languages: ${langs}`);
  }

  if (articles.length > 20) {
    console.log(`\n... and ${articles.length - 20} more`);
  }
}

function showArticle(queue: Queue, id: number): void {
  const article = queue.articles.find(a => a.id === id);
  
  if (!article) {
    console.error(`Article ID ${id} not found`);
    return;
  }

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
}

async function updateArticle(queue: Queue, id: number, update: string): Promise<void> {
  const article = queue.articles.find(a => a.id === id);
  
  if (!article) {
    console.error(`Article ID ${id} not found`);
    return;
  }

  const colonIndex = update.indexOf(":");
  if (colonIndex === -1) {
    console.error("Update format: field:value");
    return;
  }

  const field = update.slice(0, colonIndex);
  const value = update.slice(colonIndex + 1);

  const validFields = [
    "status", "output_folder", "error_note",
    "created_at", "written_at", "published_at"
  ];
  
  if (!validFields.includes(field)) {
    console.error(`Invalid field. Valid: ${validFields.join(", ")}`);
    return;
  }

  (article as any)[field] = value;
  article.updated_at = new Date().toISOString();
  
  await saveQueue(queue);
  console.log(`✅ Updated article ${id}: ${field} = ${value}`);
}

function getNext(queue: Queue, n: number = 1): void {
  const pending = queue.articles.filter(a => a.status === "pending").slice(0, n);
  
  if (pending.length === 0) {
    console.log("No pending articles");
    return;
  }

  console.log(JSON.stringify(pending, null, 2));
}

// Main
const args = process.argv.slice(2);
const command = args[0];

const queue = await loadQueue();
const authors = await loadAuthors();

switch (command) {
  case "status":
    showStatus(queue, authors);
    break;
  case "list":
    listArticles(queue, args[1]);
    break;
  case "show":
    showArticle(queue, parseInt(args[1], 10));
    break;
  case "update":
    await updateArticle(queue, parseInt(args[1], 10), args[2]);
    break;
  case "next":
    getNext(queue, parseInt(args[1], 10) || 1);
    break;
  case "backup":
    await backup();
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
