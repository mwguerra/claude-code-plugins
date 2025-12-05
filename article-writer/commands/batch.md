---
description: Process multiple articles from the queue autonomously with multi-language support
allowed-tools: Skill(article-writer), Skill(author-profile), Skill(article-queue), Bash(bun:*)
argument-hint: <count | all | area:NAME | author:ID | difficulty:LEVEL>
---

# Batch Article Processing

Process multiple articles from the task queue autonomously.

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
2. Authors configured: `.article_writer/authors.json`
3. Tasks in queue: `.article_writer/article_tasks.json`

## Process

1. Load and validate task queue
2. Filter articles matching criteria
3. For each article:
   - Get author (from task or default)
   - Update status to `in_progress`
   - **Search web** for docs, news, tutorials
   - Write in author's primary language
   - Translate to other languages
   - Update status to `draft`
   - Record output_files and sources_used
   - Set written_at timestamp
4. Report summary

## Author Handling

- Each task can specify its own author
- If not specified, uses first author in authors.json
- Article follows that author's tone and languages

## Controls During Processing

- `pause` - Finish current, then stop
- `skip` - Skip current article
- `status` - Show progress

## Output

Articles saved as: `content/articles/{folder}/{slug}.{lang}.md`

Task JSON updated with:
- output_folder
- output_files (per language)
- sources_used (researched URLs)
- written_at timestamp
- status = "draft"
