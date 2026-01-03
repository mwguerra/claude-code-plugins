---
description: Create a new technical article with web research, practical companion projects, and multi-language output
allowed-tools: Skill(article-writer), Skill(author-profile), Skill(companion-project-creator), Skill(article-queue), Bash(bun:*)
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
2. **Load settings from `.article_writer/settings.json`** (companion project defaults + `article_limits.max_words`)
3. Initialize folder: `content/articles/{date}_{slug}/` (including `code/`)
4. Guide through: Planning → **Web Research** → Drafting → **Companion Project Creation** → Review → **Condense**
5. Search web for documentation, news, and related content
6. Write initial draft in author's primary language
7. Create practical companion project using settings defaults (scaffold_command, post_scaffold, etc.)
8. Update draft with companion project code/content
9. Review article for flow and voice compliance
10. **Condense if over max_words** (preserving quality and voice)
11. Translate to other languages
12. Update article_tasks.json with output paths, sources, and companion project info

## Web Research

During research phase, searches for:
- Official documentation for the technology
- Recent news and updates (within 1 year)
- Tutorials and best practices
- Related GitHub repositories

All sources are recorded in `sources_used` array.

## Practical Companion Projects

Every article includes a practical companion project. Companion project defaults come from `.article_writer/settings.json`:

```bash
# View defaults before creating
/article-writer:settings show code
```

Companion project workflow:
1. **Load settings** - Get scaffold_command, verification commands
2. Write initial draft with `<!-- EXAMPLE: ... -->` markers
3. **Execute scaffold_command** from settings
4. **Execute post_scaffold** commands from settings
5. Add article-specific code (models, controllers, tests)
6. **⚠️ VERIFY - Actually run the code:**
   - `install_command` - Must succeed (vendor/ exists)
   - `run_command` - App must start without errors
   - `test_command` - All tests must pass
7. **If verification fails → Fix code → Re-verify**
8. Update draft with actual code from companion project
9. Review integrated article as a whole

**The companion project is NOT complete until verification passes.**

## Multi-Language Output

For author with `languages: ["pt_BR", "en_US"]`:

```
content/articles/2025_01_15_rate-limiting/
├── rate-limiting.pt_BR.md    # Primary (written first)
└── rate-limiting.en_US.md    # Translation
```

## Word Limit Enforcement

Articles are subject to a **hard word limit** defined in settings:

```bash
# Check current limit
jq '.article_limits.max_words' .article_writer/settings.json
```

**Default:** 3000 words (prose only, excludes frontmatter and code blocks)

If the draft exceeds `max_words`, the Condense phase:
1. Identifies and removes redundancy
2. Tightens verbose passages
3. Preserves author voice and technical accuracy
4. Maintains narrative flow and quality

## Checkpoints

Confirm at:
- Author and language selection
- Audience and article type
- Outline before research
- Research findings summary
- Draft review (primary language)
- **Word count compliance** (after condensation)
- Translation review
- Ready for finalization

## Output

- Primary article: `{slug}.{primary_lang}.md`
- Translations: `{slug}.{lang}.md` for each additional language
- Supporting files in dated folder subfolders
