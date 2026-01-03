#!/usr/bin/env bun
/**
 * Doctor - Validate and fix JSON files against schemas
 * Usage: bun run doctor.ts [--check | --fix | --interactive]
 * 
 * Modes:
 *   --check        Only report issues, don't fix
 *   --fix          Auto-fix with defaults (non-interactive)
 *   --interactive  Ask for each issue (default)
 */

import { readFile, writeFile, stat } from "fs/promises";
import { join } from "path";
import * as readline from "readline";

const CONFIG_DIR = ".article_writer";
const SCHEMAS_DIR = join(CONFIG_DIR, "schemas");

// File paths
const FILES = {
  tasksSchema: join(SCHEMAS_DIR, "article-tasks.schema.json"),
  authorsSchema: join(SCHEMAS_DIR, "authors.schema.json"),
  settingsSchema: join(SCHEMAS_DIR, "settings.schema.json"),
  tasks: join(CONFIG_DIR, "article_tasks.json"),
  authors: join(CONFIG_DIR, "authors.json"),
  settings: join(CONFIG_DIR, "settings.json"),
};

// Valid enum values from schema
const ENUMS = {
  status: ["pending", "in_progress", "draft", "review", "published", "archived"],
  difficulty: ["Beginner", "Intermediate", "Advanced", "All Levels"],
  area: [
    "Architecture", "Backend", "Business", "Database", "DevOps",
    "Files", "Frontend", "Full-stack", "JavaScript", "Laravel",
    "Native Apps", "Notifications", "Performance", "PHP", "Quality",
    "Security", "Soft Skills", "Testing", "Tools", "AI/ML"
  ],
  content_type: [
    "Deep-dive Tutorial", "Tutorial with Examples", "Tutorial",
    "Deep-dive", "Comprehensive Guide", "Comprehensive Tutorial",
    "Quick Tutorial", "Quick Tip", "Quick Setup", "Project Tutorial",
    "Project Series", "Tips & Tricks", "Case Study", "Pattern Guide",
    "Feature Overview", "Reference Guide", "Comparison", "Collection",
    "Checklist", "Setup Guide", "Guide", "Tool Introduction",
    "Tool Tutorial", "Tool Review", "Opinion", "Opinion + Tutorial",
    "Opinion/Experience", "Experience Sharing", "Strategic Guide",
    "Practical Guide", "Framework Guide", "Idea Collection + Guide",
    "Comparison Guide", "Step-by-step Tutorial"
  ],
  estimated_effort: ["Short", "Medium", "Long", "Long (Series)"],
  source_type: ["documentation", "tutorial", "news", "blog", "repository", "specification", "other"],
  companion_project_type: ["code", "document", "diagram", "template", "dataset", "config", "other"],
};

// Required fields for articles
const ARTICLE_REQUIRED = [
  "id", "title", "subject", "area", "tags", "difficulty",
  "relevance", "content_type", "estimated_effort", "versions",
  "series_potential", "prerequisites", "reference_urls", "status"
];

// Required fields for authors
const AUTHOR_REQUIRED = ["id", "name", "languages"];

interface Issue {
  type: "missing" | "invalid_type" | "invalid_enum" | "invalid_format" | "unknown";
  item: string;
  field: string;
  message: string;
  currentValue?: any;
  suggestedFix?: any;
  enumOptions?: string[];
}

interface FixResult {
  fixed: boolean;
  value?: any;
  skipped?: boolean;
}

let mode: "check" | "fix" | "interactive" = "interactive";
let rl: readline.Interface | null = null;

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

function prompt(question: string): Promise<string> {
  if (!rl) {
    rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
  }
  return new Promise((resolve) => {
    rl!.question(question, resolve);
  });
}

function closePrompt(): void {
  if (rl) {
    rl.close();
    rl = null;
  }
}

// ============================================
// Validation Functions
// ============================================

function validateArticle(article: any, index: number, authors: any[]): Issue[] {
  const issues: Issue[] = [];
  const itemName = `Article #${article.id || index + 1}`;

  // Check required fields
  for (const field of ARTICLE_REQUIRED) {
    if (article[field] === undefined || article[field] === null) {
      const suggestedFix = getDefaultValue(field);
      issues.push({
        type: "missing",
        item: itemName,
        field,
        message: `Missing required field '${field}'`,
        suggestedFix,
      });
    }
  }

  // Check enum fields
  if (article.status && !ENUMS.status.includes(article.status)) {
    issues.push({
      type: "invalid_enum",
      item: itemName,
      field: "status",
      message: `Invalid status '${article.status}'`,
      currentValue: article.status,
      enumOptions: ENUMS.status,
      suggestedFix: findClosestEnum(article.status, ENUMS.status) || "pending",
    });
  }

  if (article.difficulty && !ENUMS.difficulty.includes(article.difficulty)) {
    issues.push({
      type: "invalid_enum",
      item: itemName,
      field: "difficulty",
      message: `Invalid difficulty '${article.difficulty}'`,
      currentValue: article.difficulty,
      enumOptions: ENUMS.difficulty,
      suggestedFix: findClosestEnum(article.difficulty, ENUMS.difficulty) || "Intermediate",
    });
  }

  if (article.area && !ENUMS.area.includes(article.area)) {
    issues.push({
      type: "invalid_enum",
      item: itemName,
      field: "area",
      message: `Invalid area '${article.area}'`,
      currentValue: article.area,
      enumOptions: ENUMS.area,
      suggestedFix: findClosestEnum(article.area, ENUMS.area),
    });
  }

  if (article.content_type && !ENUMS.content_type.includes(article.content_type)) {
    issues.push({
      type: "invalid_enum",
      item: itemName,
      field: "content_type",
      message: `Invalid content_type '${article.content_type}'`,
      currentValue: article.content_type,
      enumOptions: ENUMS.content_type,
      suggestedFix: findClosestEnum(article.content_type, ENUMS.content_type) || "Tutorial",
    });
  }

  if (article.estimated_effort && !ENUMS.estimated_effort.includes(article.estimated_effort)) {
    issues.push({
      type: "invalid_enum",
      item: itemName,
      field: "estimated_effort",
      message: `Invalid estimated_effort '${article.estimated_effort}'`,
      currentValue: article.estimated_effort,
      enumOptions: ENUMS.estimated_effort,
      suggestedFix: findClosestEnum(article.estimated_effort, ENUMS.estimated_effort) || "Medium",
    });
  }

  // Check types
  if (article.id !== undefined && typeof article.id !== "number") {
    issues.push({
      type: "invalid_type",
      item: itemName,
      field: "id",
      message: `'id' should be a number, got ${typeof article.id}`,
      currentValue: article.id,
      suggestedFix: parseInt(article.id, 10) || index + 1,
    });
  }

  // Check author reference structure
  if (article.author) {
    if (typeof article.author === "string") {
      // Old format - just author ID string
      const authorObj = authors.find(a => a.id === article.author);
      issues.push({
        type: "invalid_format",
        item: itemName,
        field: "author",
        message: `'author' should be an object with {id, name, languages}, found string`,
        currentValue: article.author,
        suggestedFix: authorObj ? {
          id: authorObj.id,
          name: authorObj.name,
          languages: authorObj.languages,
        } : { id: article.author, name: "", languages: [] },
      });
    } else if (typeof article.author === "object") {
      if (!article.author.id) {
        issues.push({
          type: "missing",
          item: itemName,
          field: "author.id",
          message: `'author.id' is required`,
          suggestedFix: authors[0]?.id || "",
        });
      }
    }
  }

  // Check output_files structure
  if (article.output_files && Array.isArray(article.output_files)) {
    article.output_files.forEach((file: any, i: number) => {
      if (!file.language) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `output_files[${i}].language`,
          message: `Missing 'language' in output_files[${i}]`,
          suggestedFix: "en_US",
        });
      }
      if (!file.path) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `output_files[${i}].path`,
          message: `Missing 'path' in output_files[${i}]`,
          suggestedFix: "",
        });
      }
    });
  }

  // Check sources_used structure
  if (article.sources_used && Array.isArray(article.sources_used)) {
    article.sources_used.forEach((source: any, i: number) => {
      if (!source.url) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `sources_used[${i}].url`,
          message: `Missing 'url' in sources_used[${i}]`,
          suggestedFix: "",
        });
      }
      if (!source.summary) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `sources_used[${i}].summary`,
          message: `Missing 'summary' in sources_used[${i}]`,
          suggestedFix: "",
        });
      }
      if (!source.usage) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `sources_used[${i}].usage`,
          message: `Missing 'usage' in sources_used[${i}]`,
          suggestedFix: "",
        });
      }
      if (source.type && !ENUMS.source_type.includes(source.type)) {
        issues.push({
          type: "invalid_enum",
          item: itemName,
          field: `sources_used[${i}].type`,
          message: `Invalid source type '${source.type}'`,
          currentValue: source.type,
          enumOptions: ENUMS.source_type,
          suggestedFix: "other",
        });
      }
    });
  }

  // Check companion project structure
  if (article.companion_project && typeof article.companion_project === "object") {
    if (article.companion_project.type && !ENUMS.companion_project_type.includes(article.companion_project.type)) {
      issues.push({
        type: "invalid_enum",
        item: itemName,
        field: "companion_project.type",
        message: `Invalid companion project type '${article.companion_project.type}'`,
        currentValue: article.companion_project.type,
        enumOptions: ENUMS.companion_project_type,
        suggestedFix: "code",
      });
    }
  }

  return issues;
}

function validateAuthor(author: any, index: number): Issue[] {
  const issues: Issue[] = [];
  const itemName = `Author #${index + 1} (${author.id || author.name || "unknown"})`;

  // Check required fields
  for (const field of AUTHOR_REQUIRED) {
    if (author[field] === undefined || author[field] === null) {
      issues.push({
        type: "missing",
        item: itemName,
        field,
        message: `Missing required field '${field}'`,
        suggestedFix: field === "languages" ? ["en_US"] : "",
      });
    }
  }

  // Check id format (slug-like)
  if (author.id && !/^[a-z0-9-]+$/.test(author.id)) {
    issues.push({
      type: "invalid_format",
      item: itemName,
      field: "id",
      message: `'id' should be slug-like (lowercase, numbers, hyphens only)`,
      currentValue: author.id,
      suggestedFix: author.id.toLowerCase().replace(/[^a-z0-9-]/g, "-").replace(/-+/g, "-"),
    });
  }

  // Check languages is array
  if (author.languages && !Array.isArray(author.languages)) {
    issues.push({
      type: "invalid_type",
      item: itemName,
      field: "languages",
      message: `'languages' should be an array`,
      currentValue: author.languages,
      suggestedFix: typeof author.languages === "string" ? [author.languages] : ["en_US"],
    });
  }

  // Check languages is not empty
  if (Array.isArray(author.languages) && author.languages.length === 0) {
    issues.push({
      type: "invalid_format",
      item: itemName,
      field: "languages",
      message: `'languages' cannot be empty`,
      currentValue: author.languages,
      suggestedFix: ["en_US"],
    });
  }

  // Check tone values
  if (author.tone) {
    if (author.tone.formality !== undefined) {
      const val = author.tone.formality;
      if (typeof val !== "number" || val < 1 || val > 10) {
        issues.push({
          type: "invalid_format",
          item: itemName,
          field: "tone.formality",
          message: `'tone.formality' should be a number between 1-10`,
          currentValue: val,
          suggestedFix: Math.max(1, Math.min(10, parseInt(val) || 5)),
        });
      }
    }
    if (author.tone.opinionated !== undefined) {
      const val = author.tone.opinionated;
      if (typeof val !== "number" || val < 1 || val > 10) {
        issues.push({
          type: "invalid_format",
          item: itemName,
          field: "tone.opinionated",
          message: `'tone.opinionated' should be a number between 1-10`,
          currentValue: val,
          suggestedFix: Math.max(1, Math.min(10, parseInt(val) || 5)),
        });
      }
    }
  }

  return issues;
}

function validateSettings(settings: any): Issue[] {
  const issues: Issue[] = [];
  const itemName = "Settings";
  const validCompanionProjectTypes = ["code", "document", "diagram", "template", "dataset", "config", "other"];

  // Check companion_project_defaults exists
  if (!settings.companion_project_defaults) {
    issues.push({
      type: "missing",
      item: itemName,
      field: "companion_project_defaults",
      message: `Missing 'companion_project_defaults' object`,
      suggestedFix: {},
    });
    return issues;
  }

  // Check each companion project type
  for (const [type, defaults] of Object.entries(settings.companion_project_defaults)) {
    if (!validCompanionProjectTypes.includes(type)) {
      issues.push({
        type: "invalid_enum",
        item: itemName,
        field: `companion_project_defaults.${type}`,
        message: `Unknown companion project type '${type}'`,
        currentValue: type,
        enumOptions: validCompanionProjectTypes,
      });
      continue;
    }

    const typeDefaults = defaults as any;

    // Check technologies is array
    if (typeDefaults.technologies && !Array.isArray(typeDefaults.technologies)) {
      issues.push({
        type: "invalid_type",
        item: itemName,
        field: `companion_project_defaults.${type}.technologies`,
        message: `'technologies' should be an array`,
        currentValue: typeDefaults.technologies,
        suggestedFix: typeof typeDefaults.technologies === "string"
          ? [typeDefaults.technologies]
          : [],
      });
    }

    // Check has_tests is boolean
    if (typeDefaults.has_tests !== undefined && typeof typeDefaults.has_tests !== "boolean") {
      issues.push({
        type: "invalid_type",
        item: itemName,
        field: `companion_project_defaults.${type}.has_tests`,
        message: `'has_tests' should be a boolean`,
        currentValue: typeDefaults.has_tests,
        suggestedFix: Boolean(typeDefaults.has_tests),
      });
    }

    // Check setup_commands is array
    if (typeDefaults.setup_commands && !Array.isArray(typeDefaults.setup_commands)) {
      issues.push({
        type: "invalid_type",
        item: itemName,
        field: `companion_project_defaults.${type}.setup_commands`,
        message: `'setup_commands' should be an array`,
        currentValue: typeDefaults.setup_commands,
        suggestedFix: typeof typeDefaults.setup_commands === "string"
          ? [typeDefaults.setup_commands]
          : [],
      });
    }

    // Check file_structure is array
    if (typeDefaults.file_structure && !Array.isArray(typeDefaults.file_structure)) {
      issues.push({
        type: "invalid_type",
        item: itemName,
        field: `companion_project_defaults.${type}.file_structure`,
        message: `'file_structure' should be an array`,
        currentValue: typeDefaults.file_structure,
        suggestedFix: typeof typeDefaults.file_structure === "string"
          ? [typeDefaults.file_structure]
          : [],
      });
    }
  }

  return issues;
}

// ============================================
// Helper Functions
// ============================================

function getDefaultValue(field: string): any {
  const defaults: Record<string, any> = {
    id: 1,
    title: "",
    subject: "",
    area: "Backend",
    tags: "",
    difficulty: "Intermediate",
    relevance: "",
    content_type: "Tutorial",
    estimated_effort: "Medium",
    versions: "",
    series_potential: "No",
    prerequisites: "None",
    reference_urls: "",
    status: "pending",
    created_at: new Date().toISOString(),
    languages: ["en_US"],
  };
  return defaults[field] ?? "";
}

function findClosestEnum(value: string, options: string[]): string | null {
  if (!value) return null;
  
  const lower = value.toLowerCase();
  
  // Exact match (case-insensitive)
  const exact = options.find(o => o.toLowerCase() === lower);
  if (exact) return exact;
  
  // Partial match
  const partial = options.find(o => o.toLowerCase().includes(lower) || lower.includes(o.toLowerCase()));
  if (partial) return partial;
  
  // Common mappings
  const mappings: Record<string, string> = {
    "wip": "in_progress",
    "work in progress": "in_progress",
    "in progress": "in_progress",
    "inprogress": "in_progress",
    "done": "published",
    "complete": "published",
    "completed": "published",
    "todo": "pending",
    "new": "pending",
    "skip": "archived",
    "skipped": "archived",
    "beginner": "Beginner",
    "intermediate": "Intermediate",
    "advanced": "Advanced",
    "all": "All Levels",
  };
  
  return mappings[lower] || null;
}

function setNestedValue(obj: any, path: string, value: any): void {
  const parts = path.replace(/\[(\d+)\]/g, ".$1").split(".");
  let current = obj;
  
  for (let i = 0; i < parts.length - 1; i++) {
    const part = parts[i];
    if (current[part] === undefined) {
      current[part] = /^\d+$/.test(parts[i + 1]) ? [] : {};
    }
    current = current[part];
  }
  
  current[parts[parts.length - 1]] = value;
}

// ============================================
// Fix Functions
// ============================================

async function handleIssue(issue: Issue): Promise<FixResult> {
  if (mode === "check") {
    return { fixed: false };
  }

  if (mode === "fix") {
    // Auto-fix with suggested value
    if (issue.suggestedFix !== undefined) {
      return { fixed: true, value: issue.suggestedFix };
    }
    return { fixed: false, skipped: true };
  }

  // Interactive mode
  console.log(`\n⚠️  ${issue.item}: ${issue.message}`);
  
  if (issue.currentValue !== undefined) {
    console.log(`   Current value: ${JSON.stringify(issue.currentValue)}`);
  }
  
  if (issue.enumOptions) {
    console.log(`   Valid options:`);
    issue.enumOptions.forEach((opt, i) => {
      console.log(`     ${i + 1}. ${opt}`);
    });
  }
  
  if (issue.suggestedFix !== undefined) {
    console.log(`   Suggested fix: ${JSON.stringify(issue.suggestedFix)}`);
  }

  const response = await prompt(`   Apply fix? [Y/n/custom]: `);
  
  if (response.toLowerCase() === "n" || response.toLowerCase() === "no") {
    return { fixed: false, skipped: true };
  }
  
  if (response.toLowerCase() === "y" || response.toLowerCase() === "yes" || response === "") {
    return { fixed: true, value: issue.suggestedFix };
  }
  
  // Check if it's a number selection for enums
  if (issue.enumOptions && /^\d+$/.test(response)) {
    const idx = parseInt(response) - 1;
    if (idx >= 0 && idx < issue.enumOptions.length) {
      return { fixed: true, value: issue.enumOptions[idx] };
    }
  }
  
  // Custom value
  try {
    // Try to parse as JSON first
    const parsed = JSON.parse(response);
    return { fixed: true, value: parsed };
  } catch {
    // Use as string
    return { fixed: true, value: response };
  }
}

// ============================================
// Main Function
// ============================================

async function doctor(): Promise<void> {
  console.log("\n🔍 Article Writer Doctor");
  console.log("========================\n");

  // Check if initialized
  if (!(await exists(CONFIG_DIR))) {
    console.error(`❌ ${CONFIG_DIR}/ not found. Run /article-writer:init first.`);
    process.exit(1);
  }

  // Check schema files
  console.log("Checking schema files...");
  
  if (!(await exists(FILES.tasksSchema))) {
    console.error(`❌ ${FILES.tasksSchema} not found`);
    process.exit(1);
  }
  console.log(`✓ article-tasks.schema.json found`);
  
  if (!(await exists(FILES.authorsSchema))) {
    console.error(`❌ ${FILES.authorsSchema} not found`);
    process.exit(1);
  }
  console.log(`✓ authors.schema.json found`);

  if (!(await exists(FILES.settingsSchema))) {
    console.warn(`⚠️ ${FILES.settingsSchema} not found (optional)`);
  } else {
    console.log(`✓ settings.schema.json found`);
  }

  // Load data files
  let authorsData: any = { authors: [] };
  let tasksData: any = { articles: [] };
  let settingsData: any = null;

  if (await exists(FILES.authors)) {
    try {
      authorsData = await loadJson(FILES.authors);
      console.log(`✓ authors.json loaded (${authorsData.authors?.length || 0} authors)`);
    } catch (e) {
      console.error(`❌ Failed to parse authors.json: ${e}`);
      process.exit(1);
    }
  } else {
    console.log(`⚠️  authors.json not found (will be skipped)`);
  }

  if (await exists(FILES.tasks)) {
    try {
      tasksData = await loadJson(FILES.tasks);
      const articles = tasksData.articles || tasksData;
      console.log(`✓ article_tasks.json loaded (${Array.isArray(articles) ? articles.length : 0} articles)`);
    } catch (e) {
      console.error(`❌ Failed to parse article_tasks.json: ${e}`);
      process.exit(1);
    }
  } else {
    console.log(`⚠️  article_tasks.json not found (will be skipped)`);
  }

  if (await exists(FILES.settings)) {
    try {
      settingsData = await loadJson(FILES.settings);
      console.log(`✓ settings.json loaded`);
    } catch (e) {
      console.error(`❌ Failed to parse settings.json: ${e}`);
      process.exit(1);
    }
  } else {
    console.log(`⚠️  settings.json not found (will be skipped)`);
  }

  const allIssues: Issue[] = [];
  let authorsModified = false;
  let tasksModified = false;
  let settingsModified = false;

  // Validate authors
  console.log("\nValidating authors.json...");
  const authors = authorsData.authors || [];
  
  for (let i = 0; i < authors.length; i++) {
    const issues = validateAuthor(authors[i], i);
    
    for (const issue of issues) {
      allIssues.push(issue);
      const result = await handleIssue(issue);
      
      if (result.fixed) {
        setNestedValue(authors[i], issue.field, result.value);
        authorsModified = true;
        console.log(`   ✓ Fixed: ${issue.field} = ${JSON.stringify(result.value)}`);
      } else if (result.skipped) {
        console.log(`   ⏭️  Skipped: ${issue.field}`);
      }
    }
  }

  if (authors.length === 0) {
    console.log("   No authors to validate");
  } else if (allIssues.filter(i => i.item.startsWith("Author")).length === 0) {
    console.log(`   ✓ All ${authors.length} authors valid`);
  }

  // Validate settings
  if (settingsData) {
    console.log("\nValidating settings.json...");
    const settingsIssues = validateSettings(settingsData);
    
    for (const issue of settingsIssues) {
      allIssues.push(issue);
      const result = await handleIssue(issue);
      
      if (result.fixed) {
        setNestedValue(settingsData, issue.field, result.value);
        settingsModified = true;
        console.log(`   ✓ Fixed: ${issue.field} = ${JSON.stringify(result.value)}`);
      } else if (result.skipped) {
        console.log(`   ⏭️  Skipped: ${issue.field}`);
      }
    }
    
    if (settingsIssues.length === 0) {
      console.log(`   ✓ Settings valid`);
    }
  }

  // Validate articles
  console.log("\nValidating article_tasks.json...");
  const articles = tasksData.articles || (Array.isArray(tasksData) ? tasksData : []);
  const articlesArray = Array.isArray(articles) ? articles : [];
  
  for (let i = 0; i < articlesArray.length; i++) {
    const issues = validateArticle(articlesArray[i], i, authors);
    
    for (const issue of issues) {
      allIssues.push(issue);
      const result = await handleIssue(issue);
      
      if (result.fixed) {
        setNestedValue(articlesArray[i], issue.field, result.value);
        tasksModified = true;
        console.log(`   ✓ Fixed: ${issue.field} = ${JSON.stringify(result.value)}`);
      } else if (result.skipped) {
        console.log(`   ⏭️  Skipped: ${issue.field}`);
      }
    }
  }

  if (articlesArray.length === 0) {
    console.log("   No articles to validate");
  } else if (allIssues.filter(i => i.item.startsWith("Article")).length === 0) {
    console.log(`   ✓ All ${articlesArray.length} articles valid`);
  }

  // Save modified files
  if (authorsModified && mode !== "check") {
    authorsData.authors = authors;
    if (authorsData.metadata) {
      authorsData.metadata.last_updated = new Date().toISOString();
    }
    await saveJson(FILES.authors, authorsData);
    console.log(`\n💾 Saved authors.json`);
  }

  if (settingsModified && mode !== "check") {
    if (settingsData.metadata) {
      settingsData.metadata.last_updated = new Date().toISOString();
    }
    await saveJson(FILES.settings, settingsData);
    console.log(`💾 Saved settings.json`);
  }

  if (tasksModified && mode !== "check") {
    if (Array.isArray(tasksData)) {
      tasksData = { articles: articlesArray };
    } else {
      tasksData.articles = articlesArray;
    }
    if (tasksData.metadata) {
      tasksData.metadata.last_updated = new Date().toISOString();
      tasksData.metadata.total_count = articlesArray.length;
    }
    await saveJson(FILES.tasks, tasksData);
    console.log(`💾 Saved article_tasks.json`);
  }

  // Summary
  const totalIssues = allIssues.length;
  const fixedIssues = allIssues.filter((_, i) => authorsModified || tasksModified || settingsModified).length;
  
  console.log("\n" + "─".repeat(40));
  console.log("Summary:");
  console.log(`  Checked: ${articlesArray.length} articles, ${authors.length} authors, ${settingsData ? "settings" : "no settings"}`);
  console.log(`  Issues found: ${totalIssues}`);
  
  if (mode === "check") {
    console.log(`  Mode: check-only (no fixes applied)`);
    if (totalIssues > 0) {
      console.log(`\n⚠️  Run with --fix or --interactive to repair issues`);
    }
  } else {
    console.log(`  Fixed: ${authorsModified || tasksModified || settingsModified ? "yes" : "no"}`);
  }

  if (totalIssues === 0) {
    console.log(`\n✅ All files are schema-compliant!`);
  } else if (mode !== "check" && (authorsModified || tasksModified || settingsModified)) {
    console.log(`\n✅ Files have been repaired`);
  }

  closePrompt();
}

// Parse arguments
const args = process.argv.slice(2);

if (args.includes("--check")) {
  mode = "check";
} else if (args.includes("--fix")) {
  mode = "fix";
} else if (args.includes("--interactive") || args.length === 0) {
  mode = "interactive";
}

console.log(`Mode: ${mode}`);

doctor().catch((e) => {
  console.error("Error:", e);
  closePrompt();
  process.exit(1);
});
