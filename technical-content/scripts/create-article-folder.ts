/**
 * Create article folder structure
 */

import { mkdir, writeFile } from "fs/promises";
import { join } from "path";

const folderPath = process.argv[2];

if (!folderPath) {
  console.error("Usage: bun run create-article-folder.ts <folder-path>");
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
  "00_context/voice_profile.md": "# Voice Profile\n\n*Copy from docs/voice_profile.md*\n",
  "00_context/editorial_context.md": "# Editorial Context\n\n*Article:* [TITLE]\n",
  "00_context/content_history.md": "# Content History\n\n*Article:* [TITLE]\n",
  "01_planning/classification.md": "# Classification\n\n## Type\n- [ ] Tutorial\n- [ ] Deep-Dive\n- [ ] Problem/Solution\n- [ ] Opinion\n- [ ] Comparison\n",
  "01_planning/outline.md": "# Outline\n\n## Title Options\n1. \n\n## Sections\n",
  "01_planning/decisions.md": "# Decisions\n\n## Decision #1\n**Question:**\n**Decision:**\n",
  "02_research/sources.md": "# Sources\n\n| ID | Title | URL |\n|----|-------|-----|\n",
  "02_research/research_notes.md": "# Research Notes\n",
  "02_research/fact_verification.md": "# Fact Verification\n\n| Claim | Verified |\n|-------|----------|\n",
  "03_drafts/revision_notes.md": "# Revision Notes\n",
  "04_review/checklist_accuracy.md": "# Accuracy\n\n- [ ] Code tested\n- [ ] Facts verified\n",
  "04_review/checklist_readability.md": "# Readability\n\n- [ ] Hook in 150 words\n- [ ] Paragraphs ≤4 sentences\n",
  "04_review/checklist_voice.md": "# Voice\n\n- [ ] Tone matches profile\n",
  "04_review/checklist_seo.md": "# SEO\n\n- [ ] Title <60 chars\n- [ ] Meta <160 chars\n",
  "04_review/final_review.md": "# Final Review\n\n| Category | Status |\n|----------|--------|\n| Accuracy | [ ] |\n| Readability | [ ] |\n| Voice | [ ] |\n| SEO | [ ] |\n",
};

async function create() {
  try {
    for (const dir of dirs) {
      await mkdir(join(folderPath, dir), { recursive: true });
    }
    for (const [file, content] of Object.entries(files)) {
      await writeFile(join(folderPath, file), content);
    }
    console.log(`✅ Created: ${folderPath}`);
  } catch (e) {
    console.error("Error:", e);
    process.exit(1);
  }
}

create();
