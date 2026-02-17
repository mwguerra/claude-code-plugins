#!/usr/bin/env bun
/**
 * Create article folder structure
 * Usage: bun run create-article-folder.ts <folder-path> [--from-queue <id>]
 */

import { mkdir, writeFile, stat } from "fs/promises";
import { join, basename } from "path";
import { getDb, dbExists, getDefaultAuthor, rowToArticle } from "./db";

const args = process.argv.slice(2);
const fromQueueIdx = args.indexOf("--from-queue");
let folderPath = args[0];
let articleId: number | null = null;

if (fromQueueIdx !== -1 && args[fromQueueIdx + 1]) {
  articleId = parseInt(args[fromQueueIdx + 1], 10);
  folderPath = args.filter((_, i) => i !== fromQueueIdx && i !== fromQueueIdx + 1)[0];
}

if (!folderPath) {
  console.error("Usage: bun run create-article-folder.ts <folder-path> [--from-queue <id>]");
  process.exit(1);
}

const dirs = [
  "00_context",
  "01_planning",
  "02_research",
  "02_research/code_samples",
  "03_drafts",
  "04_review",
  "05_assets/images",
  "code",
];

const files: Record<string, string> = {
  "00_context/editorial_context.md": `# Editorial Context

**Article:** ${basename(folderPath)}
**Created:** ${new Date().toISOString()}

## Purpose

## Target Audience

## Key Messages

`,
  "00_context/content_history.md": `# Content History

**Article:** ${basename(folderPath)}

## Related Previous Articles

## Established Positions

`,
  "01_planning/classification.md": `# Article Classification

## Type
- [ ] Tutorial
- [ ] Deep-Dive
- [ ] Problem/Solution
- [ ] Opinion/Strategy
- [ ] Comparison
- [ ] Quick Tip

## Difficulty
- [ ] Beginner
- [ ] Intermediate
- [ ] Advanced
- [ ] All Levels

## Estimated Length
- [ ] Short (< 1000 words)
- [ ] Medium (1000-2000 words)
- [ ] Long (2000+ words)

`,
  "01_planning/outline.md": `# Article Outline

## Working Title Options
1.
2.
3.

## Hook (first 150 words)


## Sections

### Introduction

### Section 1:

### Section 2:

### Section 3:

### Conclusion

## Key Takeaways
1.
2.
3.

`,
  "01_planning/decisions.md": `# Editorial Decisions

## Decision Log

### Decision #1
**Question:**
**Options:**
**Decision:**
**Reasoning:**

`,
  "02_research/sources.md": `# Sources

## Primary Sources (Credibility 5/5)
| ID | Title | URL | Key Info | Accessed |
|----|-------|-----|----------|----------|
| P1 | | | | |

## Secondary Sources (Credibility 3-4/5)
| ID | Title | URL | Key Info | Accessed |
|----|-------|-----|----------|----------|
| S1 | | | | |

`,
  "02_research/research_notes.md": `# Research Notes

## Session 1: ${new Date().toISOString().split("T")[0]}

**Focus:**

**Searches:**

**Key Findings:**

**Sources Added:**

`,
  "02_research/fact_verification.md": `# Fact Verification

| Claim | Source | Verified | Notes |
|-------|--------|----------|-------|
| | | [ ] | |

## Code Tested
- [ ] Example 1:
- [ ] Example 2:

`,
  "03_drafts/revision_notes.md": `# Revision Notes

## Draft v1 → v2

### Feedback Received


### Changes Made


`,
  "04_review/checklist_accuracy.md": `# Accuracy Checklist

## Code
- [ ] All code blocks tested
- [ ] Output matches comments
- [ ] Versions specified and current
- [ ] No deprecated methods

## Facts
- [ ] All claims sourced
- [ ] Links working
- [ ] Statistics current

`,
  "04_review/checklist_readability.md": `# Readability Checklist

## Structure
- [ ] Hook within 150 words
- [ ] Clear H2 sections
- [ ] Logical flow

## Paragraphs
- [ ] Max 4 sentences each
- [ ] One idea per paragraph

## Language
- [ ] Terms explained on first use
- [ ] Active voice preferred

`,
  "04_review/checklist_voice.md": `# Voice Checklist

## Tone
- [ ] Matches profile formality
- [ ] Opinion strength appropriate

## Vocabulary
- [ ] Uses allowed terms freely
- [ ] Explains required terms

## Style
- [ ] No forbidden phrases
- [ ] Signature phrases natural

`,
  "04_review/checklist_seo.md": `# SEO Checklist

## Title
- [ ] Under 60 characters
- [ ] Keyword included

## Meta
- [ ] Description 150-160 chars
- [ ] Value proposition clear

## Content
- [ ] Keyword in first paragraph
- [ ] Keyword in H2
- [ ] Alt text on images

`,
  "04_review/final_review.md": `# Final Review

| Category | Status | Notes |
|----------|--------|-------|
| Accuracy | [ ] | |
| Readability | [ ] | |
| Voice | [ ] | |
| Example | [ ] | |
| SEO | [ ] | |

## Flow Review
- [ ] Narrative flows logically
- [ ] Example appears at right time
- [ ] Transitions are smooth

## Example Integration
- [ ] Code snippets match example files
- [ ] Example tests pass
- [ ] Run instructions work

## Pre-Publication
- [ ] Spell check
- [ ] Grammar check
- [ ] Read aloud
- [ ] Mobile preview

## Ready for Publication
- [ ] All checks passed
- [ ] Example runs correctly
- [ ] Author approved

`,
  "04_review/checklist_example.md": `# Example Checklist

## Completeness
- [ ] Example is functional (runs without errors)
- [ ] Example is minimal (no unnecessary code)
- [ ] README.md explains how to run
- [ ] All dependencies listed

## Quality
- [ ] Well-commented (references article sections)
- [ ] Uses SQLite for database (no external DB)
- [ ] Tests included (Pest for PHP)
- [ ] Tests pass

## Integration
- [ ] Code snippets in article match example
- [ ] File paths in article are correct
- [ ] Run instructions are accurate

`,
  "code/README.md": `# Example: ${basename(folderPath)}

> Practical example demonstrating concepts from the article.

## Requirements

- PHP 8.2+
- Composer

## Setup

\`\`\`bash
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
\`\`\`

## Run Tests

\`\`\`bash
php artisan test
\`\`\`

## Key Files

| File | Description |
|------|-------------|
| \`app/...\` | [Description] |
| \`tests/...\` | [Description] |

## Article Reference

This example accompanies the article.
See article sections for detailed explanation.

`,
};

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function create() {
  try {
    // Create directories
    for (const dir of dirs) {
      await mkdir(join(folderPath, dir), { recursive: true });
    }

    // Create template files
    for (const [file, content] of Object.entries(files)) {
      await writeFile(join(folderPath, file), content);
    }

    // Copy author profile from database
    if (dbExists()) {
      try {
        const db = getDb();
        const author = getDefaultAuthor(db);
        if (author) {
          await writeFile(
            join(folderPath, "00_context/author_profile.json"),
            JSON.stringify(author, null, 2)
          );
          console.log(`📋 Copied author profile: ${author.name}`);
        }
        db.close();
      } catch (e) {
        console.warn("⚠️ Could not load author:", e);
      }
    } else {
      await writeFile(
        join(folderPath, "00_context/author_profile.json"),
        JSON.stringify({ note: "Run /article-writer:author add to create an author" }, null, 2)
      );
    }

    // If from queue, load article metadata from database
    if (articleId !== null && dbExists()) {
      try {
        const db = getDb();
        const row = db.query("SELECT * FROM articles WHERE id = ?").get(articleId) as any;

        if (row) {
          const article = rowToArticle(row);
          const authorInfo = article.author
            ? `- **Author:** ${article.author.name} (${article.author.id})\n- **Languages:** ${article.author.languages?.join(", ") || "default"}`
            : "- **Author:** (using default)";

          const context = `# Editorial Context

**Article:** ${article.title}
**ID:** ${article.id}
**Created:** ${new Date().toISOString()}

## From Queue

${authorInfo}
- **Subject:** ${article.subject}
- **Area:** ${article.area}
- **Difficulty:** ${article.difficulty}
- **Content Type:** ${article.content_type}
- **Effort:** ${article.estimated_effort}
- **Versions:** ${article.versions}

## Prerequisites
${article.prerequisites}

## References
${article.reference_urls}

## Tags
${article.tags}

## Series Potential
${article.series_potential}

## Relevance
${article.relevance}
`;
          await writeFile(join(folderPath, "00_context/editorial_context.md"), context);
          console.log(`📝 Loaded context for article #${articleId}`);
        }
        db.close();
      } catch (e) {
        console.warn("⚠️ Could not load queue data:", e);
      }
    }

    console.log(`✅ Created: ${folderPath}`);
    console.log(JSON.stringify({ success: true, path: folderPath, articleId }));
  } catch (e) {
    console.error("❌ Error:", e);
    process.exit(1);
  }
}

create();
