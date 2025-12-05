---
description: Create a new technical article with research, documentation, and multi-language support
allowed-tools: Skill(article-writer), Skill(author-profile), Skill(article-queue), Bash(bun:*)
argument-hint: <topic | from-queue ID> [--author ID]
---

# Create Article

Create a single technical article interactively with multi-language support.

## Usage

**From topic (uses default author):**
```
/article-writer:article implementing rate limiting in Laravel
```

**From topic with specific author:**
```
/article-writer:article implementing rate limiting --author mwguerra
```

**From queue:**
```
/article-writer:article from-queue 42
```

## Prerequisites

1. Plugin initialized: `/article-writer:init`
2. At least one author configured in `.article_writer/authors.json`

## Author Selection

1. If `--author ID` specified, use that author
2. If from queue and task has author, use task's author
3. Otherwise, use first author in authors.json

## Process

1. Select author and load profile from `.article_writer/authors.json`
2. Initialize folder: `content/articles/{date}_{slug}/`
3. Guide through: Planning → **Web Research** → Drafting → Review
4. Search web for documentation, news, and related content
5. Write article in author's primary language
6. Translate to other languages in author's profile
7. Update article_tasks.json with output paths and sources used

## Web Research

During research phase, searches for:
- Official documentation for the technology
- Recent news and updates (within 1 year)
- Tutorials and best practices
- Related GitHub repositories

All sources are recorded in `sources_used` array.

## Multi-Language Output

For author with `languages: ["pt_BR", "en_US"]`:

```
content/articles/2025_01_15_rate-limiting/
├── rate-limiting.pt_BR.md    # Primary (written first)
└── rate-limiting.en_US.md    # Translation
```

## Checkpoints

Confirm at:
- Author and language selection
- Audience and article type
- Outline before research
- Research findings summary
- Draft review (primary language)
- Translation review
- Ready for finalization

## Output

- Primary article: `{slug}.{primary_lang}.md`
- Translations: `{slug}.{lang}.md` for each additional language
- Supporting files in dated folder subfolders
