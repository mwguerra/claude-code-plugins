---
description: Create a new technical article with research, documentation, and multi-language support
allowed-tools: Skill(article-writer), Skill(author-profile), Skill(example-creator), Skill(article-queue), Bash(bun:*)
argument-hint: <topic | from-queue ID> [--author ID]
---

# Create Article

Create a single technical article interactively with multi-language support.

**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writerarticle) | [docs/PROCESS.md](../docs/PROCESS.md)

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
2. **Load example defaults from `.article_writer/settings.json`**
3. Initialize folder: `content/articles/{date}_{slug}/` (including `code/`)
4. Guide through: Planning → **Web Research** → Drafting → **Example Creation** → Review
5. Search web for documentation, news, and related content
6. Write initial draft in author's primary language
7. Create practical example using settings defaults (scaffold_command, post_scaffold, etc.)
8. Update draft with example code/content
9. Review article for flow and voice compliance
10. Translate to other languages
11. Update article_tasks.json with output paths, sources, and example info

## Web Research

During research phase, searches for:
- Official documentation for the technology
- Recent news and updates (within 1 year)
- Tutorials and best practices
- Related GitHub repositories

All sources are recorded in `sources_used` array.

## Practical Examples

Every article includes a practical example. Example defaults come from `.article_writer/settings.json`:

```bash
# View defaults before creating
/article-writer:settings show code
```

Example workflow:
1. **Load settings** - Get scaffold_command, post_scaffold, test_command
2. Write initial draft with `<!-- EXAMPLE: ... -->` markers
3. **Execute scaffold_command** from settings
4. **Execute post_scaffold** commands from settings
5. Add article-specific code
6. **Verify with test_command** from settings
7. Update draft with actual code from example
8. Review integrated article as a whole

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
