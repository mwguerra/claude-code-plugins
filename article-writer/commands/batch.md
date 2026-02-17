---
description: Process multiple articles from the queue autonomously with filtering by count, area, author, or difficulty
allowed-tools: Skill(article-writer), Skill(author-profile), Skill(companion-project-creator), Skill(article-queue), Bash(bun:*)
argument-hint: <count | all | area:NAME | author:ID | difficulty:LEVEL>
---

# Batch Article Processing

Process multiple articles from the task queue autonomously.

**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writerbatch) | [docs/PROCESS.md](../docs/PROCESS.md)

## Usage

**By count:**
```
/article-writer:batch 5
/article-writer:batch 10
```

**All pending:**
```
/article-writer:batch all
```

**By area:**
```
/article-writer:batch area:Laravel
```

**By author:**
```
/article-writer:batch author:mwguerra
```

**By difficulty:**
```
/article-writer:batch difficulty:Beginner
```

## Prerequisites

1. Plugin initialized: `/article-writer:init`
2. Authors configured in database
3. Tasks in queue: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --summary`

## Process

1. Load and validate task queue from database
2. **Load settings** (companion project defaults + `article_limits.max_words`)
3. Filter articles matching criteria
4. For each article:
   - Get author (from task or default)
   - Update status to `in_progress`
   - **Search web** for docs, news, tutorials
   - Write in author's primary language
   - **Create companion project using settings** (scaffold_command, etc.)
   - Review article for flow and voice
   - **Condense if over max_words** (preserving quality and voice)
   - Translate to other languages
   - Update status to `draft`
   - Record output_files, sources_used, companion project info
   - Set written_at timestamp
5. Report summary (including word count compliance)

## Author Handling

- Each task can specify its own author
- If not specified, uses default author (lowest sort_order)
- Article follows that author's tone and languages

## Word Limit Enforcement

All articles processed in batch mode are subject to the `max_words` limit from settings:

```bash
# Check current limit before batch
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings
```

Articles exceeding the limit are automatically condensed while preserving quality and author voice.

## Controls During Processing

- `pause` - Finish current, then stop
- `skip` - Skip current article
- `status` - Show progress

## Output

Articles saved as: `content/articles/{folder}/{slug}.{lang}.md`

Database updated with:
- output_folder
- output_files (per language)
- sources_used (researched URLs)
- written_at timestamp
- status = "draft"
