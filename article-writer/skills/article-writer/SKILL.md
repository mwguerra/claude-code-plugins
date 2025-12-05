---
name: article-writer
description: Create publication-ready technical articles with web research, practical examples, and multi-language support. Each article includes a functional example (code project, document, etc.) that demonstrates the topic.
---

# Article Writer

Create technical articles with practical examples and multi-language support.

## Quick Start

1. Determine author (from task or first in authors.json)
2. Create folder structure (including `code/` folder)
3. Load author profile
4. Follow phases: Initialize → Plan → Research → **Draft → Example → Integrate → Review** → Translate → Finalize

## Workflow Overview

```
Plan → Research → Draft (initial) → Create Example → Update Draft → Review → Translate → Finalize
                         ↑                              ↓
                         └──────── Iterate ─────────────┘
```

## Folder Structure

```
content/articles/YYYY_MM_DD_slug/
├── 00_context/              # author_profile.json
├── 01_planning/             # classification.md, outline.md
├── 02_research/
│   ├── sources.json         # All researched sources
│   └── research_notes.md
├── 03_drafts/
│   ├── draft_v1.{lang}.md   # Initial draft
│   └── draft_v2.{lang}.md   # After example integration
├── 04_review/               # checklists
├── 05_assets/images/
├── code/                    # PRACTICAL EXAMPLE
│   ├── README.md            # How to run the example
│   ├── src/                 # Example source code/files
│   └── tests/               # Tests (if applicable)
├── {slug}.{primary_lang}.md # Primary article
└── {slug}.{other_lang}.md   # Translations
```

## Phases

### Phase 0: Initialize
- Get author, generate slug, create folder
- Create `code/` directory for example
- Copy author profile to `00_context/`

### Phase 1: Plan
- Classify article type
- Create outline
- **Plan example type and scope**
- **CHECKPOINT:** Get approval

### Phase 2: Research (Web Search)
- Search official documentation
- Find recent news (< 1 year for technical)
- Record all sources

### Phase 3: Draft (Initial)
- Write initial draft in primary language
- Mark places where example code will go: `<!-- EXAMPLE: description -->`
- Save as `03_drafts/draft_v1.{lang}.md`

### Phase 4: Create Example ⭐
**Critical phase - create the practical example**

#### Global Example Defaults

Example settings are defined in `.article_writer/settings.json` per example type.
Article-specific values **override** global defaults.

```
Global defaults (settings.json)     Article example (article_tasks.json)
─────────────────────────────────   ─────────────────────────────────────
code:                               example:
  technologies: [Laravel 12, ...]     type: code
  has_tests: true                     technologies: [Laravel 11, MySQL]  ← overrides
  run_instructions: "..."             has_tests: true                    ← from defaults
                                      description: "Rate limiting demo"  ← article-specific
```

**Merge logic:**
1. Get example type from article (e.g., `code`)
2. Load defaults for that type from `settings.json`
3. Merge with article's example object
4. Article values take precedence

#### Example Requirements

1. **Minimal but complete** - Smallest possible while fully functional
2. **Self-contained** - Can run independently
3. **Well-commented** - Comments reference article sections
4. **Tested** - Include tests when applicable (default: true for code)

#### Example Types

| Article Topic | Example Type | What to Create |
|---------------|--------------|----------------|
| Laravel/PHP code | `code` | Minimal Laravel project with SQLite + Pest tests |
| JavaScript/Node | `code` | Minimal Node project with tests |
| DevOps/Docker | `config` | Docker Compose setup, scripts |
| Architecture | `diagram` + `code` | Mermaid diagrams + sample structure |
| Project management | `document` | Mini project plan, template |
| Database | `code` | Migrations, seeders, queries |
| API design | `code` | OpenAPI spec + minimal implementation |
| Testing | `code` | Test suite demonstrating concepts |
| Soft skills | `document` | Templates, checklists, examples |

#### For Code Examples (Laravel)

```
code/
├── README.md              # Setup and run instructions
├── app/
│   └── ...                # Minimal app code
├── database/
│   ├── migrations/
│   └── seeders/
├── tests/
│   └── Feature/           # Pest tests for main features
├── composer.json
└── .env.example           # SQLite by default
```

**Standards for Laravel examples:**
- Use SQLite (no external DB needed)
- Use Pest for tests
- Include at least 2-3 tests for main features
- Add comments referencing article: `// See article section: "Rate Limiting Basics"`
- Keep dependencies minimal
- Include setup script if complex

#### For Document Examples

```
code/
├── README.md              # What the documents demonstrate
├── templates/
│   └── ...                # Reusable templates
└── examples/
    └── ...                # Filled-in examples
```

### Phase 5: Integrate Example into Draft
- Replace `<!-- EXAMPLE: -->` markers with actual code snippets
- Add file references: "See `code/app/Models/Post.php`"
- Add run instructions in appropriate sections
- Save as `03_drafts/draft_v2.{lang}.md`

### Phase 6: Review (Comprehensive)
**Review the article as a whole:**

1. **Explanation Flow**
   - Does the narrative flow logically?
   - Are concepts introduced before being used?
   - Does the example appear at the right time?

2. **Example Integration**
   - Do code snippets match the full example?
   - Are file paths correct?
   - Can readers follow along?

3. **Voice Compliance**
   - Matches author's formality level?
   - Uses signature phrases appropriately?
   - Avoids forbidden phrases?
   - Opinions expressed match author's positions?

4. **Technical Accuracy**
   - Code snippets are correct?
   - Example actually runs?
   - Tests pass?

5. **Completeness**
   - All outline points covered?
   - Sources properly cited?
   - Example fully demonstrates topic?

**CHECKPOINT:** Confirm article + example are ready

### Phase 7: Translate
- Create versions for other languages
- Keep code snippets unchanged
- Translate comments in code if needed

### Phase 8: Finalize
- Write final article with frontmatter
- Update article_tasks.json with:
  - output_files
  - sources_used
  - example info
- Verify example README is complete

## When to Skip Examples

Only skip if example makes **absolutely no sense**:
- Pure opinion pieces with no actionable content
- News/announcement summaries
- Historical retrospectives
- Philosophical discussions

If skipping, document in task:
```json
{
  "example": {
    "skipped": true,
    "skip_reason": "Opinion piece with no actionable code or templates"
  }
}
```

## Example README Template

```markdown
# Example: [Topic]

Demonstrates [what this example shows] from the article "[Article Title]".

## Requirements

- PHP 8.2+
- Composer
- (any other requirements)

## Setup

\`\`\`bash
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
\`\`\`

## Run Tests

\`\`\`bash
php artisan test
\`\`\`

## Key Files

| File | Description |
|------|-------------|
| `app/Models/Post.php` | Demonstrates eager loading |
| `tests/Feature/QueryTest.php` | Tests N+1 detection |

## Article Reference

This example accompanies the article:
- **Title**: [Article Title]
- **Section**: See "Implementing Eager Loading" section
```

## Example Comments Style

```php
<?php
// ===========================================
// ARTICLE: Rate Limiting in Laravel 11
// SECTION: Creating Custom Rate Limiters
// ===========================================

namespace App\Providers;

use Illuminate\Support\Facades\RateLimiter;

class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // Custom rate limiter for API endpoints
        // See article section: "Dynamic Rate Limits"
        RateLimiter::for('api', function (Request $request) {
            return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
        });
    }
}
```

## Recording Example in Task

```json
{
  "example": {
    "type": "code",
    "path": "code/",
    "description": "Minimal Laravel app demonstrating rate limiting",
    "technologies": ["Laravel 11", "SQLite", "Pest 3"],
    "has_tests": true,
    "files": [
      "app/Providers/AppServiceProvider.php",
      "routes/api.php",
      "tests/Feature/RateLimitTest.php"
    ],
    "run_instructions": "composer install && php artisan test"
  }
}
```

## References

- [references/article-types.md](references/article-types.md)
- [references/example-templates.md](references/example-templates.md)
- [references/checklists.md](references/checklists.md)
- [references/frontmatter.md](references/frontmatter.md)
- [references/research-templates.md](references/research-templates.md)
