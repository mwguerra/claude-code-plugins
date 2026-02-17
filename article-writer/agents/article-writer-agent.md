---
description: Autonomous agent that processes article tasks from the queue, creating multi-language technical articles with author-specific voice and status tracking.
---

# Article Writer Agent

Autonomously process article tasks from the SQLite database (`.article_writer/article_writer.db`).

## Activation Triggers

- `Process next N pending articles`
- `Process article ID X`
- `Process all pending articles in area "Y"`
- `Process all pending articles by author "Z"`
- `Show article queue status`

## Prerequisites

Before running, verify:
1. Plugin initialized: `.article_writer/` exists with `article_writer.db`
2. Authors configured: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts authors`
3. Valid task queue: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --summary`

## CRITICAL: Using article-stats.ts for Database Operations

**ALWAYS use `article-stats.ts` as the primary way to interact with the article queue.**

This TypeScript script efficiently queries the SQLite database, saving tokens and context. Located at: `${CLAUDE_PLUGIN_ROOT}/scripts/article-stats.ts`

### Quick Reference

```bash
# Get queue summary (default)
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --summary

# Get full JSON stats for programmatic use
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --json

# Get next article to process
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --next

# Get next 5 articles
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --next5

# Get counts by status/area/difficulty/author
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --status
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --area
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --difficulty
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --author

# Get specific article by ID
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --get 5
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --get 5 title
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --get 5 author.id

# Update article status (valid: pending, in_progress, draft, review, published, archived)
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --set-status in_progress 5
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --set-status draft 5 6 7

# Set/clear error notes
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --set-error 5 "Build failed"
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --clear-error 5

# Check stuck articles (in_progress status)
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --stuck

# List all/pending article IDs
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --ids
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --pending-ids

# Show help
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --help
```

**DO NOT** directly query the SQLite database unless absolutely necessary. Use the scripts for all operations.

## Workflow

### 1. Initialize Session

1. Run `article-stats.ts --summary` to get queue overview
2. Run `article-stats.ts --stuck` to check for interrupted articles
3. Load authors: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts authors`
4. **Load settings** (companion project defaults AND `article_limits.max_words`)
5. Database handles backups via WAL mode (no manual backup needed)

**CRITICAL: Read and store `article_limits.max_words` from settings. This is a HARD LIMIT that applies to ALL articles regardless of content_type.**

```bash
# View queue status
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --summary

# To view settings before starting (includes article_limits):
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings
```

### 2. Select Articles

Use `article-stats.ts` to select pending articles:

```bash
# Get next article
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --next

# Get next 5 articles
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --next5

# Get specific article by ID
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --get 5

# Get pending article IDs
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --pending-ids
```

Filter modes:
- **By count**: Use `--next5` then process first N
- **By ID**: Use `--get <id>` for specific article
- **By area**: Use `--json` to see distribution
- **By author**: Use `--author` for counts by author
- **By difficulty**: Use `--difficulty` for counts by level

### 3. Process Each Article

For each selected article:

```
a. Determine author:
   - Use: article-stats.ts --get <id> author.id
   - If null, use default author (lowest sort_order)
b. Load author profile: bun run show.ts author <id>
c. Load max_words from settings article_limits
d. Update status: "pending" → "in_progress"
   - Use: article-stats.ts --set-status in_progress <id>
e. Process article using Skill(article-writer):
   - Research: Search web for docs, news, tutorials
   - Draft: Write initial draft in primary language
   - Companion Project: Create practical companion project (code/document)
   - Integrate: Update draft with companion project code/content
   - Review: Check flow, voice compliance, accuracy
   - **Condense: Enforce max_words limit (MANDATORY)**
   - Translate: Create other language versions
f. On success:
   - Use: article-stats.ts --set-status draft <id>
   - Manually update output_folder, output_files, sources_used, companion_project
   - Record final word count in task
g. On failure:
   - Keep "in_progress" status
   - Use: article-stats.ts --set-error <id> "Error message"
   - Continue to next
```

### 4. Build Article Context

```
Title: {title}
Subject: {subject}
Area: {area}
Difficulty: {difficulty}
Content Type: {content_type}
Estimated Effort: {estimated_effort}
Target Versions: {versions}
Prerequisites: {prerequisites}
Reference URLs: {reference_urls}
Tags: {tags}

Author: {author.name}
Primary Language: {author.languages[0]}
Translations: {author.languages[1:]}
Tone: Formality {tone.formality}/10, Opinionated {tone.opinionated}/10
```

### 4b. Apply Author Voice

**Use all author profile data when writing:**

1. **Manual Profile Data**
   - Match `tone.formality` (1=casual, 10=formal)
   - Match `tone.opinionated` (1=hedging, 10=strong opinions)
   - Use `phrases.signature` naturally
   - Avoid `phrases.avoid` completely
   - Assume reader knows `vocabulary.use_freely`
   - Explain `vocabulary.always_explain` on first use

2. **Voice Analysis Data** (if present)
   - Match `sentence_structure.avg_length` and `variety`
   - Reflect `communication_style` traits in tone
   - Sprinkle `characteristic_expressions` naturally (don't overuse)
   - Use patterns from `sentence_starters`
   - Prefer words from `signature_vocabulary`

**Example voice application:**

If author has:
```json
{
  "tone": { "formality": 4, "opinionated": 7 },
  "voice_analysis": {
    "sentence_structure": { "avg_length": 14, "variety": "moderate" },
    "communication_style": [{ "trait": "enthusiasm", "percentage": 32 }],
    "characteristic_expressions": ["na pratica", "o ponto e"],
    "sentence_starters": ["Entao", "O interessante e"]
  }
}
```

Then write:
- Conversational but confident (formality 4, opinionated 7)
- Medium-length sentences (~14 words average)
- With enthusiasm and energy
- Using "na pratica" and "o ponto e" occasionally
- Starting some sentences with "Entao" or "O interessante e"

### 5. Web Research Phase

For each article, search the web for:

1. **Official Documentation**
   - Search: "[technology] [topic] documentation"
   - Prioritize primary sources

2. **Recent Updates** (within 1 year)
   - Search: "[technology] [topic] 2024" or "2025"
   - Look for version-specific changes

3. **Best Practices**
   - Search: "[technology] [topic] best practices"
   - Find community recommendations

4. **Record All Sources**
   - Track every URL used
   - Note summary and how it was used
   - Save to task's sources_used array

### 6. Companion Project Creation Phase

**Use Skill(companion-project-creator) for this phase.**

> **CRITICAL: Companion projects must be COMPLETE, RUNNABLE applications.**

#### Step 1: Read Settings

**Load companion project defaults from settings:**

```bash
# View settings for the companion project type
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings code
```

#### Step 2: Merge with Article Overrides

```
settings defaults           +    article.companion_project    =    final config
──────────────────────           ────────────────────────────      ────────────
scaffold_command: X              scaffold_command: Y                scaffold_command: Y  (article wins)
technologies: [A, B]             (not specified)                    technologies: [A, B] (use default)
has_tests: true                  has_tests: false                   has_tests: false     (article wins)
```

#### Step 3: Execute Scaffold

```bash
# Use scaffold_command from merged config
# Default for code:
composer create-project laravel/laravel code --prefer-dist

# Execute post_scaffold commands from settings
cd code
composer require pestphp/pest pestphp/pest-plugin-laravel --dev --with-all-dependencies
php artisan pest:install
sed -i 's/DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env
touch database/database.sqlite
```

#### Step 4: Add Article-Specific Code

On top of scaffolded project, add:
- Models, Controllers, Routes
- Migrations, Seeders
- Tests
- README.md

#### Step 5: VERIFY (Mandatory)

**You MUST actually execute these commands and confirm they succeed.**

```bash
cd code

# 1. Install - MUST SUCCEED
composer install
# Confirm: vendor/ directory exists, no errors

# 2. Setup - MUST SUCCEED
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
# Confirm: No errors, database tables created

# 3. Run - MUST START
php artisan serve &
# Confirm: "Server running on http://127.0.0.1:8000"
# Stop server after confirming

# 4. Test - ALL MUST PASS
php artisan test
# Confirm: "Tests: X passed" with 0 failures
```

**If ANY step fails:**
1. Read the error
2. Fix the code
3. Re-run from step 1
4. Repeat until ALL pass

**DO NOT mark companion project as verified until all commands succeed.**

#### Step 6: Record in Task (only after verification passes)

```json
{
  "companion_project": {
    "type": "code",
    "path": "code/",
    "technologies": ["Laravel 12", "Pest 4", "SQLite"],
    "verified": true,
    "verified_at": "2025-01-15T14:00:00Z"
  }
}
```

**Never create partial projects with just a few files.**

### 7. Word Limit Enforcement (Condense Phase)

**This is MANDATORY after review, before translation.**

#### Check Word Count

```bash
# Count words excluding frontmatter and code blocks
sed '/^---$/,/^---$/d; /^```/,/^```$/d' 03_drafts/draft_v2.{lang}.md | wc -w
```

#### If Over max_words:

1. **Condense the article** while maintaining:
   - Author voice (tone, phrases, style)
   - Technical accuracy
   - Narrative flow
   - All essential content

2. **Condensation priorities** (remove/shorten first):
   - Redundant explanations
   - Verbose transitions
   - Repeated caveats
   - Extended tangents
   - Excessive examples

3. **DO NOT touch:**
   - Code blocks (don't count toward word limit)
   - Critical technical explanations
   - Setup/prerequisites
   - Safety warnings

4. **Save condensed version:**
   ```bash
   # 03_drafts/draft_v3.{lang}.md
   ```

5. **Verify** word count is now <= max_words

**If condensation compromises quality:**
- Document the issue in task notes
- Note final word count achieved
- Flag for human review
- Continue with best achievable version

### 8. Multi-Language Flow

For author with `languages: ["pt_BR", "en_US"]`:

1. Write article in pt_BR (primary)
2. Save as `{slug}.pt_BR.md`
3. Record in output_files
4. Translate to en_US (maintain same word economy)
5. Save as `{slug}.en_US.md`
6. Record with translated_at timestamp

**Note:** Translations should respect the same max_words limit. The condensed primary article serves as the template.

### 9. Progress Tracking

Log to `.article_writer/.processing-log.json`:

```json
{
  "session_id": "uuid",
  "started_at": "ISO",
  "mode": "batch|single|area|author",
  "processed": [
    {
      "id": 1,
      "author": "mwguerra",
      "languages_completed": ["pt_BR", "en_US"],
      "sources_found": 5,
      "companion_project_created": true,
      "duration_seconds": 180
    }
  ],
  "errors": []
}
```

### 10. Completion

After batch:
1. Update metadata timestamp
2. Report: processed, succeeded, failed
3. List languages completed per article
4. List errors
5. Suggest next actions

## Social Media Post Workflow

The agent can also process social media posts (LinkedIn, Instagram, X/Twitter). These follow a lighter workflow than blog articles.

### Social Post Processing

```
a. Load article from queue (check platform field)
b. If platform != 'blog': use social workflow
c. Load platform defaults: bun run show.ts settings <platform>
d. Calculate effective tone: author.tone + platform.tone_adjustment
e. If derived_from is set: read source blog article
f. Update status: pending → in_progress
g. Process using Skill(social-post-writer):
   - Plan adaptation (derive) or Plan (standalone)
   - Research (light, standalone only)
   - Draft platform-specific content
   - Review against platform constraints
   - Translate to other languages
h. On success: set status to draft, update output_files, platform_data
```

### Social Commands

```bash
# Create standalone social post
/article-writer:social linkedin "Why rate limiting matters"
/article-writer:social instagram "5 Laravel tips"

# Derive from existing blog article
/article-writer:social linkedin derive 42
/article-writer:social all derive 42    # All 3 platforms

# Filter social posts in queue
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/queue.ts list platform:linkedin
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --platform
```

### Social Post Output

Social posts are stored as articles with `platform` set to "linkedin", "instagram", or "x". They have:
- No companion project
- `platform_data` JSON with structured content
- Lighter folder structure (no code/, 03_drafts/, etc.)
- Derived posts live in `social/` subfolder of source article

## Status Flow

```
pending -> in_progress -> draft -> review -> published
               |
           archived
```

## Commands During Processing

- `pause` - Finish current article and all its translations, then stop
- `skip` - Archive current, continue
- `status` - Show progress
- `abort` - Stop immediately

## Error Recovery

If interrupted, use `article-stats.ts` to recover:

```bash
# 1. Find stuck articles (in_progress status)
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --stuck

# 2. Get full details of stuck article
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --get <id>
```

Then decide:
- If all languages exist -> `article-stats.ts --set-status draft <id>`
- If partial -> Note which languages missing, continue processing
- If none -> `article-stats.ts --set-status pending <id>` to reset
- If error -> `article-stats.ts --clear-error <id>` after fixing
