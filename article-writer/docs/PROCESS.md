# Article Writer Process

Complete workflow guide for creating articles with the article-writer plugin.

---

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ARTICLE WRITER WORKFLOW                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. SETUP (once)           2. CREATE AUTHOR         3. WRITE ARTICLE        │
│  ─────────────────         ───────────────────      ────────────────────    │
│  /article-writer:init      /author add              /article <topic>        │
│       │                         OR                        │                 │
│       │                    /author analyze                │                 │
│       ▼                         │                         ▼                 │
│  Creates structure              │              Plan → Research → Draft      │
│  + article_writer.db            │              → Companion Project → Review │
│                                 ▼              → Translate → Finalize       │
│                           Database updated               │                 │
│                                                          ▼                 │
│                                               content/articles/YYYY_MM_DD/  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Setup (One Time)

### Step 1: Initialize Plugin

```bash
/article-writer:init
```

This creates:

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json    # Article task schema
│   │   ├── authors.schema.json          # Author profile schema
│   │   └── settings.schema.json         # Settings schema
│   └── article_writer.db                # SQLite database (all data)
├── content/
│   └── articles/                        # Output folder for articles
└── docs/                                # Documentation folder
```

### Step 2: Review Default Settings

```bash
/article-writer:settings show
```

This shows the default configuration for each companion project type (code, document, diagram, etc.).

**To customize defaults:**

```bash
# View code companion project defaults
/article-writer:settings show code

# Change Laravel version
/article-writer:settings set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'

# Change test command
/article-writer:settings set code.test_command "vendor/bin/pest"
```

---

## Phase 2: Create Author Profile

Every article needs an author. You have two options:

### Option A: Manual Questionnaire

```bash
/article-writer:author add
```

Claude will ask about:

| Category | Questions |
|----------|-----------|
| **Identity** | ID (slug), display name, role, experience, expertise |
| **Languages** | Primary language, translation targets |
| **Tone** | Formality (1-10), opinionated (1-10) |
| **Vocabulary** | Terms to use freely, terms to always explain |
| **Phrases** | Signature phrases, phrases to avoid |
| **Opinions** | Strong positions, topics to stay neutral on |
| **Voice** | Example paragraph in their voice |

### Option B: Extract from Transcripts (Recommended)

If you have recordings (podcasts, interviews, meetings):

```bash
# 1. First, list speakers to find the right name
/article-writer:author analyze --list-speakers podcast.txt

# Output:
# Speakers found:
#   - John Smith: 156 turns
#   - Jane Doe: 142 turns

# 2. Extract voice for target speaker
/article-writer:author analyze --speaker "John Smith" podcast.txt interview.txt
```

Claude will:
1. Analyze speaking patterns
2. Show extracted voice characteristics
3. Ask for identity info (id, name, languages, expertise)
4. Create complete author profile

### Verify Author

```bash
# List all authors
/article-writer:author list

# View full details
/article-writer:author show mwguerra
```

---

## Phase 3: Create Article

### Single Article

```bash
# With default author (lowest sort_order)
/article-writer:article implementing rate limiting in Laravel

# With specific author
/article-writer:article API versioning best practices --author tech-writer
```

### From Queue

If you have articles queued in the database:

```bash
# Get next pending article
/article-writer:next

# View full queue
/article-writer:queue list

# Create specific article by ID
/article-writer:article from-queue 42
```

### Batch Processing

```bash
# Process next 5 pending
/article-writer:batch 5

# Process all by author
/article-writer:batch author:mwguerra
```

---

## Article Creation Phases

When you run `/article-writer:article`, these phases execute:

### Phase 3.1: Initialize

- Load author profile from database
- Generate article slug from title
- Create folder structure:

```
content/articles/YYYY_MM_DD_slug/
├── 00_context/
│   └── author_profile.json      # Copy of author for reference
├── 01_planning/
│   ├── classification.md        # Article type, audience
│   └── outline.md               # Section outline
├── 02_research/
│   ├── sources.json             # All researched URLs
│   └── research_notes.md        # Key findings
├── 03_drafts/
│   ├── draft_v1.{lang}.md       # Initial draft
│   └── draft_v2.{lang}.md       # After companion project integration
├── 04_review/
│   └── checklists/              # Review checklists
├── 05_assets/
│   └── images/                  # Article images
└── code/                        # Practical companion project
```

### Phase 3.2: Plan

- Classify article type (Tutorial, Deep-dive, Guide, etc.)
- Identify target audience
- Create section outline
- Plan companion project type and scope

**CHECKPOINT:** Claude shows plan and asks for approval before continuing.

### Phase 3.3: Research (Web Search)

Claude searches the web for:

1. **Official Documentation** - Primary sources for accuracy
2. **Recent Updates** - News from the past year
3. **Best Practices** - Community recommendations
4. **Related Repositories** - GitHub examples

All sources are recorded and saved to the article's `sources_used` field in the database.

### Phase 3.4: Draft (Initial)

- Write in author's primary language
- Apply author's voice profile:
  - Tone (formality, opinionated level)
  - Signature phrases
  - Vocabulary rules
  - Voice analysis patterns (if present)
- Mark example locations: `<!-- EXAMPLE: description -->`
- Save as `03_drafts/draft_v1.{lang}.md`

### Phase 3.5: Create Companion Project

> **CRITICAL: Companion projects must be COMPLETE and RUNNABLE**

#### Step 1: Load Settings

**ALWAYS load settings before creating companion projects:**

```bash
# View settings for your companion project type
/article-writer:settings show code
```

This reads companion project defaults and shows:
- `scaffold_command`: Command to create base project
- `post_scaffold`: Commands to run after scaffolding
- `technologies`: Default tech stack
- `test_command`: Command to verify companion project

#### Step 2: Merge with Article Overrides

If the article task has `companion_project` settings, those override the defaults.

#### Step 3: Execute Scaffold

**For Code Companion Projects (e.g., Laravel):**

```bash
# Execute scaffold_command from settings
composer create-project laravel/laravel code --prefer-dist

# Execute post_scaffold commands from settings
cd code
composer require pestphp/pest pestphp/pest-plugin-laravel --dev
php artisan pest:install
sed -i 's/DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env
touch database/database.sqlite
```

#### Step 4: Add Article-Specific Code

Then add article-specific code:
- Models, Controllers, Routes
- Migrations, Seeders
- Tests
- README explaining the companion project

#### Step 5: VERIFY (Mandatory)

**You MUST actually run these commands and confirm they succeed:**

```bash
cd code

# 1. Install dependencies - MUST SUCCEED
composer install
# Check: No errors, vendor/ exists

# 2. Setup - MUST SUCCEED
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
# Check: No errors

# 3. Run application - MUST START
php artisan serve &
# Check: Server starts on localhost:8000
# Stop server after confirming

# 4. Run tests - ALL MUST PASS
php artisan test
# Check: "Tests: X passed" (0 failures)
```

**If ANY step fails -> Fix the code -> Re-verify -> Repeat until all pass.**

**For Other Types:**

| Type | Verification |
|------|--------------|
| `node` | `npm install` -> `npm start` -> `npm test` |
| `python` | `pip install -r requirements.txt` -> `python src/main.py` -> `pytest` |
| `config` | `docker-compose up -d` -> `docker-compose ps` (all "Up") |
| `script` | `chmod +x` -> `./script.sh --help` (runs without error) |
| `document` | Manual: all sections complete, filled examples exist |
| `diagram` | Manual: renders in Mermaid preview |

### Phase 3.6: Integrate Companion Project

**Only proceed here after verification passes.**

- Replace `<!-- EXAMPLE: -->` markers with actual code
- Add file references: "See `code/app/Models/Post.php`"
- Add run instructions
- Save as `03_drafts/draft_v2.{lang}.md`

### Phase 3.7: Review

Check:
- [ ] Explanation flows logically
- [ ] Companion project code matches article snippets
- [ ] Voice matches author profile
- [ ] Technical accuracy
- [ ] All outline points covered

**CHECKPOINT:** Claude confirms article + companion project are ready.

### Phase 3.8: Condense (if needed)

If article exceeds `max_words`:
- Identify and remove redundancy
- Tighten verbose passages
- Preserve author voice and technical accuracy
- Maintain narrative flow and quality

### Phase 3.9: Translate

For each additional language in author's profile:
- Translate article content
- Keep code snippets unchanged
- Optionally translate code comments
- Save as `{slug}.{lang}.md`

### Phase 3.10: Finalize

- Write final article with frontmatter
- Move from `03_drafts/` to root of article folder
- Update database:
  - `output_folder`: folder path
  - `output_files`: per-language file paths
  - `sources_used`: all researched URLs
  - `companion_project`: companion project info
  - `status`: "draft"
  - `written_at`: timestamp

---

## Output Structure

After completion, your article folder looks like:

```
content/articles/2025_01_15_rate-limiting/
├── 00_context/
│   └── author_profile.json
├── 01_planning/
│   ├── classification.md
│   └── outline.md
├── 02_research/
│   ├── sources.json
│   └── research_notes.md
├── 03_drafts/
│   ├── draft_v1.pt_BR.md
│   └── draft_v2.pt_BR.md
├── 04_review/
│   └── checklists/
├── 05_assets/images/
├── code/                              # COMPLETE Laravel project
│   ├── app/
│   │   ├── Http/Controllers/
│   │   └── Models/
│   ├── database/
│   │   ├── migrations/
│   │   └── seeders/
│   ├── routes/
│   ├── tests/Feature/
│   ├── .env.example
│   ├── artisan
│   ├── composer.json
│   └── README.md
├── rate-limiting.pt_BR.md             # Primary article
└── rate-limiting.en_US.md             # Translation
```

---

## Social Media Posts

In addition to blog articles, the article-writer supports creating social media content for LinkedIn, Instagram, and X/Twitter.

### Creating Social Posts

```bash
# Standalone from a topic
/article-writer:social linkedin "Why rate limiting matters"
/article-writer:social instagram "5 Laravel tips"
/article-writer:social x "The future of PHP"

# Derive from an existing blog article
/article-writer:social linkedin derive 42
/article-writer:social all derive 42    # All 3 platforms
```

### Social Post Workflow

Social posts follow a lighter workflow than blog articles:

```
Standalone: Initialize → Plan → Research (light) → Draft → Review → Translate → Finalize
Derive:     Initialize → Read Source → Plan Adaptation → Draft → Review → Translate → Finalize
```

Key differences from blog articles:
- **No companion project** — social posts link to the blog's if derived
- **Lighter folder structure** — only `00_context/`, `01_planning/`, `02_research/`
- **Voice adjustment** — author's base tone is shifted per platform
- **Platform constraints** — character limits, hashtag counts, structural requirements

### Social Post Output

**Standalone posts** get their own article folder (lighter structure):
```
content/articles/YYYY_MM_DD_slug/
├── 00_context/author_profile.json
├── 01_planning/outline.md
├── 02_research/research_notes.md
└── {slug}.linkedin.{lang}.md
```

**Derived posts** are stored in the source article's `social/` subfolder:
```
content/articles/YYYY_MM_DD_rate-limiting/
├── ... (existing blog article files) ...
└── social/
    ├── rate-limiting.linkedin.pt_BR.md
    ├── rate-limiting.instagram.pt_BR.md
    ├── rate-limiting.instagram.carousel.pt_BR.md
    ├── rate-limiting.x.tweet.pt_BR.md
    └── rate-limiting.x.thread.pt_BR.md
```

### Platform Settings

Each platform has configurable defaults:

```bash
# View platform settings
/article-writer:settings show linkedin
/article-writer:settings show instagram
/article-writer:settings show x

# Modify platform settings
/article-writer:settings set platform_defaults.linkedin.max_words 800
/article-writer:settings set platform_defaults.x.thread_tweets.default 10
```

---

## Queue Management

### View Queue Status

```bash
/article-writer:queue status
```

Shows summary: total articles, by status, by author, top areas.

### View Queue Details

```bash
/article-writer:queue list                    # All
/article-writer:queue list pending            # By status
/article-writer:queue list author:mwguerra    # By author
```

### Article Statuses

| Status | Meaning |
|--------|---------|
| `pending` | Waiting to be written |
| `in_progress` | Currently being written |
| `draft` | Written, needs review |
| `review` | Under review |
| `published` | Published |
| `archived` | No longer active |

---

## Troubleshooting

### Validate Database

```bash
/article-writer:doctor
```

Checks database integrity and all records, offers to fix issues.

### Reset Settings

```bash
/article-writer:settings reset              # Reset all
/article-writer:settings reset-type code    # Reset just code defaults
```

### Check Initialization

```bash
/article-writer:init --check
```

Shows what's missing without creating anything.

### Migration from JSON

If you have existing JSON files from a previous version:

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/migrate.ts
```

---

## Data Reference

| Resource | Purpose | View Command |
|----------|---------|--------------|
| `.article_writer/article_writer.db` | All data | See commands above |
| `.article_writer/schemas/` | Schema documentation | `/doctor` |

---

## Best Practices

### Authors

1. **Use voice extraction** when you have transcripts - it captures authentic patterns
2. **Start with one author** and refine their profile over multiple articles
3. **Review generated articles** and update phrases based on what sounds wrong

### Settings

1. **Keep SQLite default** for code companion projects - no external dependencies needed
2. **Customize per-article** rather than changing global defaults
3. **Run doctor** after manual edits to catch errors

### Articles

1. **Approve the plan** before Claude starts writing
2. **Check the companion project first** - if it doesn't run, the article is incomplete
3. **Review voice compliance** - does it sound like the author?

---

## See Also

- [COMMANDS.md](COMMANDS.md) - Complete command reference
- [README.md](../README.md) - Plugin overview
- [skills/article-writer/SKILL.md](../skills/article-writer/SKILL.md) - Detailed writing guidelines
- [skills/companion-project-creator/SKILL.md](../skills/companion-project-creator/SKILL.md) - Companion project creation guidelines
