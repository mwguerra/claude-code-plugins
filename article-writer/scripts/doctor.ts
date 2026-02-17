#!/usr/bin/env bun
/**
 * Doctor - Validate and fix database records against schemas
 * Usage: bun run doctor.ts [--check | --fix | --interactive]
 *
 * Modes:
 *   --check        Only report issues, don't fix
 *   --fix          Auto-fix with defaults (non-interactive)
 *   --interactive  Ask for each issue (default)
 */

import * as readline from "readline";
import {
  getDb, dbExists, getSettings, touchMetadata,
  rowToAuthor, rowToArticle, CONFIG_DIR,
} from "./db";

// Valid enum values from schema
const ENUMS = {
  platform: ["blog", "linkedin", "instagram", "x"],
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
  companion_project_type: [
    "code", "node", "python", "document", "diagram", "template",
    "dataset", "config", "script", "spreadsheet", "other"
  ],
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
  type: "missing" | "invalid_type" | "invalid_enum" | "invalid_format" | "unknown" | "integrity";
  item: string;
  field: string;
  message: string;
  currentValue?: any;
  suggestedFix?: any;
  enumOptions?: string[];
  // For DB updates
  table?: string;
  rowId?: any;
  column?: string;
  isJsonColumn?: boolean;
  jsonPath?: string;
}

interface FixResult {
  fixed: boolean;
  value?: any;
  skipped?: boolean;
}

let mode: "check" | "fix" | "interactive" = "interactive";
let rl: readline.Interface | null = null;

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

function validateArticle(article: any, authors: any[], articles?: any[]): Issue[] {
  const issues: Issue[] = [];
  const itemName = `Article #${article.id}`;

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
        table: "articles",
        rowId: article.id,
        column: field,
      });
    }
  }

  // Check enum fields
  const enumChecks: { field: string; options: string[]; fallback: string }[] = [
    { field: "status", options: ENUMS.status, fallback: "pending" },
    { field: "difficulty", options: ENUMS.difficulty, fallback: "Intermediate" },
    { field: "area", options: ENUMS.area, fallback: "Backend" },
    { field: "content_type", options: ENUMS.content_type, fallback: "Tutorial" },
    { field: "estimated_effort", options: ENUMS.estimated_effort, fallback: "Medium" },
  ];

  for (const { field, options, fallback } of enumChecks) {
    if (article[field] && !options.includes(article[field])) {
      issues.push({
        type: "invalid_enum",
        item: itemName,
        field,
        message: `Invalid ${field} '${article[field]}'`,
        currentValue: article[field],
        enumOptions: options,
        suggestedFix: findClosestEnum(article[field], options) || fallback,
        table: "articles",
        rowId: article.id,
        column: field,
      });
    }
  }

  // Check id type
  if (article.id !== undefined && typeof article.id !== "number") {
    issues.push({
      type: "invalid_type",
      item: itemName,
      field: "id",
      message: `'id' should be a number, got ${typeof article.id}`,
      currentValue: article.id,
      suggestedFix: parseInt(article.id, 10) || 1,
      table: "articles",
      rowId: article.id,
      column: "id",
    });
  }

  // Check author reference
  if (article.author) {
    if (typeof article.author === "string") {
      const authorObj = authors.find((a: any) => a.id === article.author);
      issues.push({
        type: "invalid_format",
        item: itemName,
        field: "author",
        message: `'author' reference should be an object with {id, name, languages}, found string`,
        currentValue: article.author,
        suggestedFix: authorObj
          ? { id: authorObj.id, name: authorObj.name, languages: authorObj.languages }
          : { id: article.author, name: "", languages: [] },
        table: "articles",
        rowId: article.id,
        column: "author_id",
      });
    } else if (typeof article.author === "object" && !article.author.id) {
      issues.push({
        type: "missing",
        item: itemName,
        field: "author.id",
        message: `'author.id' is required when author is set`,
        suggestedFix: authors[0]?.id || "",
        table: "articles",
        rowId: article.id,
        column: "author_id",
      });
    }
  }

  // Check output_files structure (JSON column)
  if (article.output_files && Array.isArray(article.output_files)) {
    article.output_files.forEach((file: any, i: number) => {
      if (!file.language) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `output_files[${i}].language`,
          message: `Missing 'language' in output_files[${i}]`,
          suggestedFix: "en_US",
          table: "articles",
          rowId: article.id,
          column: "output_files",
          isJsonColumn: true,
          jsonPath: `[${i}].language`,
        });
      }
      if (!file.path) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `output_files[${i}].path`,
          message: `Missing 'path' in output_files[${i}]`,
          suggestedFix: "",
          table: "articles",
          rowId: article.id,
          column: "output_files",
          isJsonColumn: true,
          jsonPath: `[${i}].path`,
        });
      }
    });
  }

  // Check sources_used structure (JSON column)
  if (article.sources_used && Array.isArray(article.sources_used)) {
    article.sources_used.forEach((source: any, i: number) => {
      if (!source.url) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `sources_used[${i}].url`,
          message: `Missing 'url' in sources_used[${i}]`,
          suggestedFix: "",
          table: "articles",
          rowId: article.id,
          column: "sources_used",
          isJsonColumn: true,
          jsonPath: `[${i}].url`,
        });
      }
      if (!source.summary) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `sources_used[${i}].summary`,
          message: `Missing 'summary' in sources_used[${i}]`,
          suggestedFix: "",
          table: "articles",
          rowId: article.id,
          column: "sources_used",
          isJsonColumn: true,
          jsonPath: `[${i}].summary`,
        });
      }
      if (!source.usage) {
        issues.push({
          type: "missing",
          item: itemName,
          field: `sources_used[${i}].usage`,
          message: `Missing 'usage' in sources_used[${i}]`,
          suggestedFix: "",
          table: "articles",
          rowId: article.id,
          column: "sources_used",
          isJsonColumn: true,
          jsonPath: `[${i}].usage`,
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
          table: "articles",
          rowId: article.id,
          column: "sources_used",
          isJsonColumn: true,
          jsonPath: `[${i}].type`,
        });
      }
    });
  }

  // Check platform enum
  if (article.platform && !ENUMS.platform.includes(article.platform)) {
    issues.push({
      type: "invalid_enum",
      item: itemName,
      field: "platform",
      message: `Invalid platform '${article.platform}'`,
      currentValue: article.platform,
      enumOptions: ENUMS.platform,
      suggestedFix: "blog",
      table: "articles",
      rowId: article.id,
      column: "platform",
    });
  }

  // Check derived_from FK: if set, referenced article must exist and be a blog article
  if (article.derived_from) {
    const sourceArticle = articles ? articles.find((a: any) => a.id === article.derived_from) : null;
    if (!sourceArticle) {
      issues.push({
        type: "invalid_format",
        item: itemName,
        field: "derived_from",
        message: `derived_from references non-existent article #${article.derived_from}`,
        currentValue: article.derived_from,
        suggestedFix: null,
        table: "articles",
        rowId: article.id,
        column: "derived_from",
      });
    } else if (sourceArticle.platform && sourceArticle.platform !== "blog") {
      issues.push({
        type: "invalid_format",
        item: itemName,
        field: "derived_from",
        message: `derived_from should reference a blog article, but #${article.derived_from} is platform '${sourceArticle.platform}'`,
        currentValue: article.derived_from,
        table: "articles",
        rowId: article.id,
        column: "derived_from",
      });
    }
  }

  // Check platform_data JSON structure matches platform
  if (article.platform_data && typeof article.platform_data === "object") {
    if (article.platform === "instagram") {
      if (!article.platform_data.caption) {
        issues.push({
          type: "missing",
          item: itemName,
          field: "platform_data.caption",
          message: `Instagram platform_data should have 'caption' field`,
          table: "articles",
          rowId: article.id,
          column: "platform_data",
          isJsonColumn: true,
          jsonPath: "caption",
        });
      }
    }
    if (article.platform === "x") {
      if (!article.platform_data.tweet) {
        issues.push({
          type: "missing",
          item: itemName,
          field: "platform_data.tweet",
          message: `X/Twitter platform_data should have 'tweet' field`,
          table: "articles",
          rowId: article.id,
          column: "platform_data",
          isJsonColumn: true,
          jsonPath: "tweet",
        });
      }
    }
    if (article.platform === "linkedin") {
      if (!article.platform_data.hook && !article.platform_data.body) {
        issues.push({
          type: "missing",
          item: itemName,
          field: "platform_data.hook",
          message: `LinkedIn platform_data should have 'hook' or 'body' field`,
          table: "articles",
          rowId: article.id,
          column: "platform_data",
          isJsonColumn: true,
          jsonPath: "hook",
        });
      }
    }
  }

  // Check companion_project structure (JSON column)
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
        table: "articles",
        rowId: article.id,
        column: "companion_project",
        isJsonColumn: true,
        jsonPath: "type",
      });
    }
  }

  return issues;
}

function validateAuthor(author: any): Issue[] {
  const issues: Issue[] = [];
  const itemName = `Author (${author.id || author.name || "unknown"})`;

  // Check required fields
  for (const field of AUTHOR_REQUIRED) {
    if (author[field] === undefined || author[field] === null) {
      issues.push({
        type: "missing",
        item: itemName,
        field,
        message: `Missing required field '${field}'`,
        suggestedFix: field === "languages" ? ["en_US"] : "",
        table: "authors",
        rowId: author.id,
        column: field === "languages" ? "languages" : field,
        isJsonColumn: field === "languages",
      });
    }
  }

  // Check id format
  if (author.id && !/^[a-z0-9-]+$/.test(author.id)) {
    issues.push({
      type: "invalid_format",
      item: itemName,
      field: "id",
      message: `'id' should be slug-like (lowercase, numbers, hyphens only)`,
      currentValue: author.id,
      suggestedFix: author.id.toLowerCase().replace(/[^a-z0-9-]/g, "-").replace(/-+/g, "-"),
      table: "authors",
      rowId: author.id,
      column: "id",
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
      table: "authors",
      rowId: author.id,
      column: "languages",
      isJsonColumn: true,
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
      table: "authors",
      rowId: author.id,
      column: "languages",
      isJsonColumn: true,
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
          table: "authors",
          rowId: author.id,
          column: "tone_formality",
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
          table: "authors",
          rowId: author.id,
          column: "tone_opinionated",
        });
      }
    }
  }

  return issues;
}

function validateSettings(settings: any): Issue[] {
  const issues: Issue[] = [];
  const itemName = "Settings";

  // Check companion_project_defaults exists
  if (!settings.companion_project_defaults) {
    issues.push({
      type: "missing",
      item: itemName,
      field: "companion_project_defaults",
      message: `Missing 'companion_project_defaults' object`,
      suggestedFix: {},
      table: "settings",
      rowId: 1,
      column: "companion_project_defaults",
      isJsonColumn: true,
    });
    return issues;
  }

  // Check each companion project type
  for (const [type, defaults] of Object.entries(settings.companion_project_defaults)) {
    if (!ENUMS.companion_project_type.includes(type)) {
      issues.push({
        type: "invalid_enum",
        item: itemName,
        field: `companion_project_defaults.${type}`,
        message: `Unknown companion project type '${type}'`,
        currentValue: type,
        enumOptions: ENUMS.companion_project_type,
        table: "settings",
        rowId: 1,
        column: "companion_project_defaults",
        isJsonColumn: true,
        jsonPath: type,
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
        table: "settings",
        rowId: 1,
        column: "companion_project_defaults",
        isJsonColumn: true,
        jsonPath: `${type}.technologies`,
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
        table: "settings",
        rowId: 1,
        column: "companion_project_defaults",
        isJsonColumn: true,
        jsonPath: `${type}.has_tests`,
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
        table: "settings",
        rowId: 1,
        column: "companion_project_defaults",
        isJsonColumn: true,
        jsonPath: `${type}.setup_commands`,
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
        table: "settings",
        rowId: 1,
        column: "companion_project_defaults",
        isJsonColumn: true,
        jsonPath: `${type}.file_structure`,
      });
    }
  }

  // Validate platform_defaults
  if (settings.platform_defaults && typeof settings.platform_defaults === "object") {
    const validPlatforms = ["linkedin", "instagram", "x"];
    for (const [platform, defaults] of Object.entries(settings.platform_defaults)) {
      if (!validPlatforms.includes(platform)) {
        issues.push({
          type: "invalid_enum",
          item: itemName,
          field: `platform_defaults.${platform}`,
          message: `Unknown platform '${platform}' in platform_defaults`,
          currentValue: platform,
          enumOptions: validPlatforms,
          table: "settings",
          rowId: 1,
          column: "platform_defaults",
          isJsonColumn: true,
          jsonPath: platform,
        });
        continue;
      }

      const pd = defaults as any;
      if (pd.tone_adjustment) {
        if (pd.tone_adjustment.formality_offset !== undefined) {
          const v = pd.tone_adjustment.formality_offset;
          if (typeof v !== "number" || v < -5 || v > 5) {
            issues.push({
              type: "invalid_format",
              item: itemName,
              field: `platform_defaults.${platform}.tone_adjustment.formality_offset`,
              message: `formality_offset should be a number between -5 and 5`,
              currentValue: v,
              suggestedFix: Math.max(-5, Math.min(5, Number(v) || 0)),
              table: "settings",
              rowId: 1,
              column: "platform_defaults",
              isJsonColumn: true,
              jsonPath: `${platform}.tone_adjustment.formality_offset`,
            });
          }
        }
      }
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
    if (issue.suggestedFix !== undefined) {
      return { fixed: true, value: issue.suggestedFix };
    }
    return { fixed: false, skipped: true };
  }

  // Interactive mode
  console.log(`\n  ${issue.item}: ${issue.message}`);

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
    const parsed = JSON.parse(response);
    return { fixed: true, value: parsed };
  } catch {
    return { fixed: true, value: response };
  }
}

function applyFix(db: any, issue: Issue, value: any): void {
  if (!issue.table || issue.rowId === undefined || !issue.column) return;

  const idColumn = issue.table === "settings" ? "id" : "id";

  if (issue.isJsonColumn && issue.jsonPath) {
    // Read current JSON column, modify, write back
    const row = db.query(`SELECT ${issue.column} FROM ${issue.table} WHERE ${idColumn} = ?`).get(issue.rowId) as any;
    if (!row) return;

    let jsonData;
    try {
      jsonData = JSON.parse(row[issue.column] || "{}");
    } catch {
      jsonData = {};
    }

    setNestedValue(jsonData, issue.jsonPath, value);
    db.run(
      `UPDATE ${issue.table} SET ${issue.column} = ?, updated_at = datetime('now') WHERE ${idColumn} = ?`,
      [JSON.stringify(jsonData), issue.rowId]
    );
  } else if (issue.isJsonColumn && !issue.jsonPath) {
    // Replace entire JSON column
    const serialized = typeof value === "string" ? value : JSON.stringify(value);
    db.run(
      `UPDATE ${issue.table} SET ${issue.column} = ?, updated_at = datetime('now') WHERE ${idColumn} = ?`,
      [serialized, issue.rowId]
    );
  } else if (issue.column === "author_id" && issue.field === "author") {
    // Special handling for author reference fix
    const authorFix = typeof value === "object" ? value : { id: value };
    db.run(
      `UPDATE articles SET author_id = ?, author_name = ?, author_languages = ?, updated_at = datetime('now') WHERE id = ?`,
      [authorFix.id, authorFix.name || null, authorFix.languages ? JSON.stringify(authorFix.languages) : null, issue.rowId]
    );
  } else {
    // Scalar column update
    db.run(
      `UPDATE ${issue.table} SET ${issue.column} = ?, updated_at = datetime('now') WHERE ${idColumn} = ?`,
      [value, issue.rowId]
    );
  }
}

// ============================================
// Main Function
// ============================================

async function doctor(): Promise<void> {
  console.log("\n🔍 Article Writer Doctor");
  console.log("========================\n");

  // Check if database exists
  if (!dbExists()) {
    console.error(`❌ Database not found. Run /article-writer:init first.`);
    process.exit(1);
  }

  const db = getDb();

  // SQLite integrity checks
  console.log("Checking database integrity...");

  const integrityResult = db.query("PRAGMA integrity_check").get() as any;
  if (integrityResult?.integrity_check === "ok") {
    console.log("✓ Database integrity: OK");
  } else {
    console.error(`❌ Database integrity check failed: ${JSON.stringify(integrityResult)}`);
    db.close();
    process.exit(1);
  }

  const fkResults = db.query("PRAGMA foreign_key_check").all() as any[];
  if (fkResults.length === 0) {
    console.log("✓ Foreign key constraints: OK");
  } else {
    console.error(`❌ Foreign key violations found: ${fkResults.length}`);
    for (const fk of fkResults) {
      console.error(`   Table: ${fk.table}, Row: ${fk.rowid}, Parent: ${fk.parent}`);
    }
  }

  // Check schema files exist in .article_writer/schemas/
  const schemaFiles = ["article-tasks.schema.json", "authors.schema.json", "settings.schema.json"];
  for (const f of schemaFiles) {
    const { existsSync } = await import("fs");
    const schemaPath = `${CONFIG_DIR}/schemas/${f}`;
    if (existsSync(schemaPath)) {
      console.log(`✓ ${f} found`);
    } else {
      console.warn(`⚠️  ${f} not found (optional, for documentation)`);
    }
  }

  // Load data from database
  const authorRows = db.query("SELECT * FROM authors ORDER BY sort_order ASC").all() as any[];
  const articleRows = db.query("SELECT * FROM articles ORDER BY id ASC").all() as any[];
  const settings = getSettings(db);

  const authors = authorRows.map(rowToAuthor);
  const articles = articleRows.map(rowToArticle);

  console.log(`\nLoaded: ${authors.length} authors, ${articles.length} articles, ${settings ? "settings" : "no settings"}`);

  const allIssues: Issue[] = [];
  let fixCount = 0;

  // Validate authors
  console.log("\nValidating authors...");

  for (const author of authors) {
    const issues = validateAuthor(author);

    for (const issue of issues) {
      allIssues.push(issue);
      const result = await handleIssue(issue);

      if (result.fixed) {
        applyFix(db, issue, result.value);
        fixCount++;
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
  if (settings) {
    console.log("\nValidating settings...");
    const settingsIssues = validateSettings(settings);

    for (const issue of settingsIssues) {
      allIssues.push(issue);
      const result = await handleIssue(issue);

      if (result.fixed) {
        applyFix(db, issue, result.value);
        fixCount++;
        console.log(`   ✓ Fixed: ${issue.field} = ${JSON.stringify(result.value)}`);
      } else if (result.skipped) {
        console.log(`   ⏭️  Skipped: ${issue.field}`);
      }
    }

    if (settingsIssues.length === 0) {
      console.log(`   ✓ Settings valid`);
    }
  } else {
    console.log("\n⚠️  No settings found in database");
  }

  // Validate articles
  console.log("\nValidating articles...");

  for (const article of articles) {
    const issues = validateArticle(article, authors, articles);

    for (const issue of issues) {
      allIssues.push(issue);
      const result = await handleIssue(issue);

      if (result.fixed) {
        applyFix(db, issue, result.value);
        fixCount++;
        console.log(`   ✓ Fixed: ${issue.field} = ${JSON.stringify(result.value)}`);
      } else if (result.skipped) {
        console.log(`   ⏭️  Skipped: ${issue.field}`);
      }
    }
  }

  if (articles.length === 0) {
    console.log("   No articles to validate");
  } else if (allIssues.filter(i => i.item.startsWith("Article")).length === 0) {
    console.log(`   ✓ All ${articles.length} articles valid`);
  }

  // Update metadata if fixes were applied
  if (fixCount > 0 && mode !== "check") {
    touchMetadata(db);
  }

  db.close();

  // Summary
  const totalIssues = allIssues.length;

  console.log("\n" + "─".repeat(40));
  console.log("Summary:");
  console.log(`  Checked: ${articles.length} articles, ${authors.length} authors, ${settings ? "settings" : "no settings"}`);
  console.log(`  Issues found: ${totalIssues}`);

  if (mode === "check") {
    console.log(`  Mode: check-only (no fixes applied)`);
    if (totalIssues > 0) {
      console.log(`\n⚠️  Run with --fix or --interactive to repair issues`);
    }
  } else {
    console.log(`  Fixed: ${fixCount}`);
  }

  if (totalIssues === 0) {
    console.log(`\n✅ Database is fully valid!`);
  } else if (mode !== "check" && fixCount > 0) {
    console.log(`\n✅ Database has been repaired`);
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
