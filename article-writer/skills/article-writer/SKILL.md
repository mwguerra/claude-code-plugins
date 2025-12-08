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

#### Applying Author Voice

**Use ALL author profile data when writing:**

1. **Manual Profile Data**
   - `tone.formality`: 1=very casual, 10=very formal
   - `tone.opinionated`: 1=always hedge, 10=strong opinions
   - `phrases.signature`: Use naturally (don't overdo)
   - `phrases.avoid`: Never use these
   - `vocabulary.use_freely`: Assume reader knows these
   - `vocabulary.always_explain`: Explain on first use

2. **Voice Analysis Data** (if present in `voice_analysis`)
   - `sentence_structure.avg_length`: Target this sentence length
   - `sentence_structure.variety`: Match style (short/moderate/long)
   - `communication_style`: Reflect top traits in tone
   - `characteristic_expressions`: Sprinkle these naturally
   - `sentence_starters`: Use these patterns
   - `signature_vocabulary`: Prefer these words

**Example:**

For author with:
```json
{
  "tone": { "formality": 4, "opinionated": 7 },
  "voice_analysis": {
    "sentence_structure": { "avg_length": 14, "variety": "moderate" },
    "communication_style": [{ "trait": "enthusiasm", "percentage": 32 }],
    "characteristic_expressions": ["na prática", "o ponto é"],
    "sentence_starters": ["Então", "O interessante é"]
  }
}
```

Write with:
- Conversational but confident tone
- Medium sentences (~14 words)
- Enthusiastic energy
- Occasional "na prática" and "o ponto é"
- Some sentences starting with "Então" or "O interessante é"

### Phase 4: Create Example ⭐
**Use Skill(example-creator) for this phase**

> **CRITICAL: Examples must be COMPLETE, RUNNABLE, and VERIFIED.**

A Laravel example is a FULL Laravel installation. A Node example is a FULL Node project.

**The example is NOT complete until you have actually run and tested it.**

#### Step 1: Load Example Defaults from Settings

**Read `.article_writer/settings.json` first:**

```bash
# View defaults for the example type
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings code
```

**Or read JSON and extract:**
```javascript
const settings = JSON.parse(fs.readFileSync('.article_writer/settings.json'));
const codeDefaults = settings.example_defaults.code;
// codeDefaults.scaffold_command
// codeDefaults.verification.install_command
// codeDefaults.verification.run_command
// codeDefaults.verification.test_command
```

#### Step 2: Merge with Article Overrides

If article task has `example` field, those values override settings defaults.

#### Step 3: Execute Scaffold Command

```bash
# From settings.example_defaults.code.scaffold_command
composer create-project laravel/laravel code --prefer-dist
```

#### Step 4: Add Article-Specific Code

Add your custom code on top of the scaffolded project:
- Models, Controllers, Routes
- Migrations, Seeders
- Tests

**Never create partial projects with just a few files.**

#### Step 5: VERIFY (Mandatory) ⚠️

**You MUST actually run these commands and confirm they succeed:**

```bash
cd code

# 1. Install dependencies - MUST SUCCEED
composer install
# ✓ Check: No errors, vendor/ directory exists

# 2. Setup - MUST SUCCEED
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
# ✓ Check: No errors

# 3. Run application - MUST START
php artisan serve &
# ✓ Check: "Server running on http://127.0.0.1:8000"
# Stop the server after confirming

# 4. Run tests - ALL MUST PASS
php artisan test
# ✓ Check: "Tests: X passed" with 0 failures
```

**If ANY step fails:**
1. Read the error message
2. Fix the code
3. Re-run verification from step 1
4. Repeat until ALL steps pass

**DO NOT proceed to Phase 5 until verification passes.**

#### Example Types

| Article Topic | Example Type | What to Create |
|---------------|--------------|----------------|
| Laravel/PHP code | `code` | **Full Laravel project** via composer create-project |
| JavaScript/Node | `node` | **Full Node project** via npm init |
| Python | `python` | **Full Python project** with venv |
| DevOps/Docker | `config` | Complete docker-compose setup |
| Architecture | `diagram` | Complete Mermaid diagrams |
| Project management | `document` | Complete templates + filled examples |

#### Verification Checklist

Before proceeding to Phase 5:
- [ ] Scaffold command executed successfully
- [ ] All article-specific code added
- [ ] `install_command` succeeded (vendor/node_modules exists)
- [ ] `run_command` starts application without errors
- [ ] `test_command` runs with 0 failures
- [ ] README.md explains setup and usage

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
   - If voice_analysis present:
     - Sentence length matches avg_length?
     - Communication style traits reflected?
     - Characteristic expressions used (not overused)?

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
