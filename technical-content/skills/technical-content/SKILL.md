---
name: technical-content
description: Create high-quality technical articles with full research, documentation, and quality checks. Use when the user wants to write a blog post, technical article, tutorial, guide, or any written content about software, hardware, development, management, or tech leadership topics.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/timestamp.ts:*)
  - Bash(bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts:*)
  - Bash(bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/run-checklist.ts:*)
  - Bash(mkdir:*)
  - Bash(cat:*)
  - Bash(ls:*)
  - WebSearch
  - WebFetch
  - Task
  - Skill(timestamp)
---

# Technical Content Creation

Create publication-ready technical articles following a comprehensive, documented process.

## Requirements

You must use the timestamp skill when creating folder names or timestamped files.

## Process Overview

1. **Initialize** - Create article folder, load or create voice profile
2. **Plan** - Classify article type, define audience, create outline
3. **Research** - Search web, verify facts, test code, document sources
4. **Draft** - Write following voice profile and approved outline
5. **Review** - Run all quality checklists
6. **Finalize** - Apply fixes, write final article

## Folder Structure

Create articles at `docs/articles/YYYY_MM_DD_<slug>/`:

```
docs/articles/YYYY_MM_DD_article_slug/
├── 00_context/
│   ├── voice_profile.md
│   ├── editorial_context.md
│   └── content_history.md
├── 01_planning/
│   ├── classification.md
│   ├── outline.md
│   └── decisions.md
├── 02_research/
│   ├── sources.md
│   ├── research_notes.md
│   ├── fact_verification.md
│   └── code_samples/
├── 03_drafts/
│   ├── draft_v1.md
│   └── revision_notes.md
├── 04_review/
│   ├── checklist_accuracy.md
│   ├── checklist_readability.md
│   ├── checklist_voice.md
│   ├── checklist_seo.md
│   └── final_review.md
├── 05_assets/
│   └── images/
└── <article_slug>.md          # FINAL ARTICLE
```

## Creating the Folder

Run the folder creation script:

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts docs/articles/YYYY_MM_DD_slug
```

## Phase Details

See [PROCESS.md](PROCESS.md) for detailed phase instructions.

## Examples

- [ARTICLE-TYPES.md](examples/ARTICLE-TYPES.md) - Classification guidance
- [RESEARCH-TEMPLATE.md](examples/RESEARCH-TEMPLATE.md) - Source tracking
- [CHECKLIST-TEMPLATE.md](examples/CHECKLIST-TEMPLATE.md) - Review formats
- [VOICE-PROFILE.md](examples/VOICE-PROFILE.md) - Voice documentation

## User Checkpoints

Stop and ask the user at these points:

1. After initialization: Confirm audience, type, scope
2. After planning: Approve outline before research
3. After research: Confirm findings, ask about gaps
4. After drafting: Review sections, request changes
5. After review: Confirm ready for finalization

## Writing Standards

- Maximum 3-4 sentences per paragraph
- Technical terms explained on first use
- Code blocks tested and commented
- Sources attributed with inline links
- No filler content for word count

## Running Checklists

After drafting, run quality checks:

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/run-checklist.ts docs/articles/YYYY_MM_DD_slug
```
