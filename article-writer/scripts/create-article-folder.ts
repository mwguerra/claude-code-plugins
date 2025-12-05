#!/usr/bin/env bun
/**
 * Create article folder structure
 * Usage: bun run create-article-folder.ts <folder-path> [--from-queue <id>]
 */

import { mkdir, writeFile, readFile, copyFile, stat } from "fs/promises";
import { join, basename } from "path";

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
| SEO | [ ] | |

## Pre-Publication
- [ ] Spell check
- [ ] Grammar check
- [ ] Read aloud
- [ ] Mobile preview

## Ready for Publication
- [ ] All checks passed
- [ ] Author approved

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

    // Copy voice profile if exists
    const voiceProfilePath = "docs/voice_profile.md";
    if (await exists(voiceProfilePath)) {
      await copyFile(
        voiceProfilePath,
        join(folderPath, "00_context/voice_profile.md")
      );
      console.log("📋 Copied voice profile");
    } else {
      await writeFile(
        join(folderPath, "00_context/voice_profile.md"),
        "# Voice Profile\n\n*Create profile with /technical-content:voice setup*\n"
      );
    }

    // If from queue, load article metadata
    if (articleId !== null) {
      try {
        const queueContent = await readFile("article_ideas.json", "utf-8");
        const queue = JSON.parse(queueContent);
        const articles = queue.articles || queue;
        const article = articles.find((a: any) => a.id === articleId);
        
        if (article) {
          // Write context from queue
          const context = `# Editorial Context

**Article:** ${article.title}
**ID:** ${article.id}
**Created:** ${new Date().toISOString()}

## From Queue

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
