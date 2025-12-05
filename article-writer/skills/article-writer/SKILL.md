---
name: article-writer
description: Create publication-ready technical articles with web research, planning, drafting, review, and translation phases. Searches for documentation, news, and related content. Supports multiple languages per author.
---

# Article Writer

Create technical articles with web research and multi-language support.

## Quick Start

1. Determine author (from task or first in authors.json)
2. Create folder structure
3. Load author profile
4. Follow phases: Initialize → Plan → **Research (web)** → Draft → Review → Translate → Finalize

## Phases Overview

### Phase 0: Initialize
- Get author, generate slug, create folder
- Copy author profile to `00_context/`

### Phase 1: Plan
- Classify article type
- Create outline
- **CHECKPOINT:** Get approval before research

### Phase 2: Research (Web Search)
**Critical phase - search the web for current information**

1. **Official Documentation**
   - Search for official docs related to the topic
   - Prioritize primary sources (laravel.com, php.net, etc.)

2. **Recent News & Updates** (within 1 year for technical subjects)
   - Search for recent changes, updates, deprecations
   - Look for version-specific information
   - Find announcements about the technology

3. **Related Content**
   - Tutorials and guides from reputable sources
   - GitHub repositories and packages
   - Community discussions and best practices

4. **Track All Sources**
   - Record every URL used in `02_research/sources.json`
   - Include summary and how it was used
   - Save to article_tasks.json after completion

### Phase 3: Draft
- Write in primary language following research
- Cite sources inline when using specific information
- Test all code blocks

### Phase 4: Review
- Run checklists
- Verify source attributions
- **CHECKPOINT:** Confirm ready

### Phase 5: Translate
- Create versions for other languages
- Keep source citations unchanged

### Phase 6: Finalize
- Update article_tasks.json with sources_used
- Record all output files

## Web Research Guidelines

### What to Search For

```
1. "[technology] official documentation [topic]"
2. "[technology] [topic] tutorial 2024" or "2025"
3. "[technology] [topic] best practices"
4. "[technology] [version] changes [topic]"
5. "[topic] common issues solutions"
6. "github [technology] [topic] package"
```

### Source Priority

1. **Official documentation** - Always search first
2. **Official blogs** - Laravel News, PHP.net, etc.
3. **Reputable tech blogs** - Dev.to, Medium (verified authors)
4. **GitHub repositories** - Popular, maintained packages
5. **Stack Overflow** - Highly voted answers only
6. **Community tutorials** - With caution, verify accuracy

### Recency Requirements

- **Technical subjects**: Prefer sources < 1 year old
- **Breaking changes**: Must use latest documentation
- **Stable concepts**: Older sources acceptable if still valid
- **Always verify**: Check if information is still current

### Recording Sources

Save to `02_research/sources.json`:

```json
{
  "researched_at": "2025-01-15T10:00:00Z",
  "topic": "Rate Limiting in Laravel",
  "sources": [
    {
      "url": "https://laravel.com/docs/11.x/rate-limiting",
      "title": "Rate Limiting - Laravel Documentation",
      "summary": "Official docs covering RateLimiter facade, defining limiters, and middleware",
      "usage": "Primary reference for syntax and configuration options",
      "accessed_at": "2025-01-15T10:15:00Z",
      "type": "documentation"
    }
  ]
}
```

### Source Types

- `documentation` - Official docs
- `tutorial` - How-to guides
- `news` - Announcements, updates
- `blog` - Blog posts, articles
- `repository` - GitHub, GitLab repos
- `specification` - RFCs, specs
- `other` - Everything else

## Updating article_tasks.json

After research phase, update the task:

```javascript
task.sources_used = [
  {
    url: "https://...",
    title: "Page Title",
    summary: "What the page covers",
    usage: "How it was used in the article",
    accessed_at: "2025-01-15T10:00:00Z",
    type: "documentation"
  }
];
```

## Folder Structure

```
content/articles/YYYY_MM_DD_slug/
├── 00_context/              # author_profile.json
├── 01_planning/             # classification.md, outline.md
├── 02_research/
│   ├── sources.json         # All researched sources
│   ├── research_notes.md    # Key findings
│   └── code_samples/        # Tested code
├── 03_drafts/               # draft_v1.{lang}.md
├── 04_review/               # checklists
├── 05_assets/images/
├── {slug}.{primary_lang}.md # Primary article
└── {slug}.{other_lang}.md   # Translations
```

## File Naming

All files include language code:
- `rate-limiting.pt_BR.md` (primary)
- `rate-limiting.en_US.md` (translation)

## Writing with Sources

When using researched information:

1. **Direct reference**: "According to the [Laravel documentation](url)..."
2. **Inline citation**: "Rate limiting uses a token bucket algorithm [1]"
3. **Code attribution**: "// Based on example from Laravel docs"

Include a Sources section at article end:

```markdown
## Sources

- [Laravel Rate Limiting Documentation](https://...)
- [What's New in Laravel 11](https://...)
```

## Scripts

```bash
# Create folder
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts <path>

# Run checklists
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/run-checklist.ts <folder>
```

## References

- [references/article-types.md](references/article-types.md)
- [references/checklists.md](references/checklists.md)
- [references/frontmatter.md](references/frontmatter.md)
- [references/research-templates.md](references/research-templates.md)

## Templates

In `assets/templates/`:
- `tutorial.md`
- `deep-dive.md`
- `comparison.md`
