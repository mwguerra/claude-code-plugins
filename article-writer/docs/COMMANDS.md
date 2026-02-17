# Article Writer Commands

Complete reference for all article-writer commands.

**Data Storage:**
- Database: `.article_writer/article_writer.db` (SQLite)
- Schemas: `.article_writer/schemas/`

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `/article-writer:init` | Initialize plugin in project |
| `/article-writer:author add` | Create author (questionnaire) |
| `/article-writer:author analyze` | Extract voice from transcripts |
| `/article-writer:author list` | List all authors |
| `/article-writer:author show <id>` | Show author details |
| `/article-writer:author edit <id>` | Edit author |
| `/article-writer:author remove <id>` | Remove author |
| `/article-writer:settings show` | Show all settings |
| `/article-writer:settings show <type>` | Show companion project type defaults |
| `/article-writer:settings set <path> <value>` | Update a setting |
| `/article-writer:settings reset` | Reset to defaults |
| `/article-writer:article <topic>` | Create new article |
| `/article-writer:next` | Get next pending article |
| `/article-writer:queue list` | List queued articles |
| `/article-writer:queue status` | Show queue summary |
| `/article-writer:batch <n>` | Process n articles |
| `/article-writer:social <platform> <topic\|derive ID>` | Create social media posts |
| `/article-writer:doctor` | Validate database records |

---

## /article-writer:init

Initialize the article-writer plugin in your project.

### Usage

```bash
/article-writer:init              # Full initialization
/article-writer:init --check      # Check what's missing without creating
```

### What It Creates

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json
│   │   ├── authors.schema.json
│   │   └── settings.schema.json
│   └── article_writer.db          # SQLite database
├── content/
│   └── articles/                  # Where articles go
└── docs/                          # Documentation folder
```

### Example Output

```
🚀 Article Writer Initialization

✅ Already exists (will not modify):
   • .article_writer
   • content/articles

📋 Missing items to create:
   • article_writer.db

📁 Creating directories...
   ✓ .article_writer/schemas/

📋 Setting up schema files...
   ✓ settings.schema.json

💾 Creating database...
   ✓ article_writer.db (with default settings)

──────────────────────────────────────────────────────
✅ Article Writer initialized!

Next step: Create your first author profile:
   /article-writer:author add
```

---

## /article-writer:author

Manage author profiles for consistent writing voice.

### Subcommands

#### `add` - Create New Author

Interactive questionnaire to create an author profile.

```bash
/article-writer:author add
```

**Questions asked:**
1. ID (slug-like identifier)
2. Display name
3. Languages (primary + translations)
4. Role/title
5. Experience
6. Expertise areas
7. Tone: Formality (1-10)
8. Tone: Opinionated (1-10)
9. Vocabulary to use freely
10. Vocabulary to always explain
11. Signature phrases
12. Phrases to avoid
13. Strong positions (opinions)
14. Topics to stay neutral on
15. Example paragraph in their voice

---

#### `analyze` - Extract Voice from Transcripts

Extract authentic voice patterns from podcast/interview/meeting transcripts.

```bash
# List speakers in a transcript
/article-writer:author analyze --list-speakers transcript.txt

# Create new author from transcripts
/article-writer:author analyze --speaker "John Smith" podcast.txt interview.txt

# Add voice data to existing author
/article-writer:author analyze --speaker "John" --author-id john-smith new_recording.txt
```

**Supported transcript formats:**
- Plain text: `Speaker: text`
- Timestamped: `[00:01:23] Speaker: text`
- WhatsApp: `[17:30, 12/6/2025] Speaker: text`
- SRT subtitles

**What gets extracted:**
- Sentence structure (length, variety)
- Communication style (enthusiastic, analytical, direct, etc.)
- Characteristic expressions ("you know", "I think", etc.)
- Sentence starters
- Signature vocabulary

---

#### `list` - List All Authors

```bash
/article-writer:author list
```

**Example output:**

```
═══════════════════════════════════════════════════════════════
  AUTHORS
═══════════════════════════════════════════════════════════════

  Total: 2 author(s)

  1. MW Guerra (mwguerra) [DEFAULT]
     Languages: pt_BR, en_US
     Role: Senior Software Engineer
     Expertise: Laravel, PHP, Architecture
     Tone: Formality 4/10, Opinionated 7/10
     Voice Analysis: ✓ (234 samples)

  2. Tech Writer (tech-writer)
     Languages: en_US
     Role: Technical Writer
     Expertise: Documentation, APIs
     Voice Analysis: ✗

  To see full details: /article-writer:author show <id>
────────────────────────────────────────────────────────────────
```

---

#### `show <id>` - Show Author Details

```bash
/article-writer:author show mwguerra
```

Displays complete author profile including:
- Identity (ID, name, role, experience, expertise)
- Languages (primary + translations)
- Tone settings (visual scale)
- Vocabulary rules
- Phrases (signature and avoid)
- Opinions (strong positions and neutral topics)
- Voice analysis data (if present)
- Example voice sample

---

#### `edit <id>` - Edit Author

```bash
/article-writer:author edit mwguerra
```

Provides interactive editing. For direct edits, use:

```bash
# Change tone
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts set-author mwguerra tone.formality 6

# Add phrase
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts add-phrase mwguerra signature "Na pratica..."
```

---

#### `remove <id>` - Remove Author

```bash
/article-writer:author remove tech-writer
```

Asks for confirmation before removing.

---

## /article-writer:settings

View and modify global settings, including **article word limits** and companion project defaults.

### Article Limits

The `article_limits` section defines hard limits that apply to ALL articles regardless of content type:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `max_words` | integer | 3000 | Maximum word count for article prose (excludes frontmatter and code blocks) |

Articles exceeding `max_words` are automatically condensed during the Condense phase while preserving quality, flow, and author voice.

### `show` - View Settings

```bash
/article-writer:settings show              # Show all settings
/article-writer:settings show code         # Show code companion project defaults
/article-writer:settings show document     # Show document companion project defaults
```

**Example output for `/article-writer:settings show`:**

```
═══════════════════════════════════════════════════════════════
  SETTINGS
═══════════════════════════════════════════════════════════════
────────────────────────────────────────────────────────────────

  Article Limits:
    Max Words: 3000

  Companion Project Defaults:
  ┌────────────┬─────────────────────────────────┬───────────┐
  │ Type       │ Technologies                    │ Has Tests │
  ├────────────┼─────────────────────────────────┼───────────┤
  │ code       │ Laravel 12, Pest 4, SQLite      │ Yes       │
  │ document   │ Markdown                        │ No        │
  │ diagram    │ Mermaid                         │ No        │
  │ config     │ Docker, Docker Compose, YAML    │ No        │
  └────────────┴─────────────────────────────────┴───────────┘

  To see type details: /article-writer:settings show <type>
────────────────────────────────────────────────────────────────
```

---

### `set` - Modify Settings

```bash
/article-writer:settings set <path> <value>
```

**Common paths:**

| Path | Example Value |
|------|---------------|
| `article_limits.max_words` | `3000` |
| `code.technologies` | `'["Laravel 11", "Pest 3", "MySQL"]'` |
| `code.has_tests` | `true` or `false` |
| `code.scaffold_command` | `"composer create-project laravel/laravel:^11.0 code"` |
| `code.run_command` | `"php artisan serve"` |
| `code.test_command` | `"vendor/bin/pest"` |
| `document.technologies` | `'["Markdown", "AsciiDoc"]'` |

**Examples:**

```bash
# Set article word limit to 2000 words
/article-writer:settings set article_limits.max_words 2000

# Change Laravel version
/article-writer:settings set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'

# Disable tests for code companion projects
/article-writer:settings set code.has_tests false
```

---

### `reset` - Reset to Defaults

```bash
/article-writer:settings reset              # Reset all settings
/article-writer:settings reset-type code    # Reset just code defaults
```

---

## /article-writer:article

Create a new article.

### Usage

```bash
/article-writer:article <topic>
/article-writer:article <topic> --author <id>
/article-writer:article from-queue <task-id>
```

### Examples

```bash
# Create with default author
/article-writer:article implementing rate limiting in Laravel

# Create with specific author
/article-writer:article API versioning best practices --author tech-writer

# Create from queue
/article-writer:article from-queue 42
```

### What Happens

1. **Initialize** - Create folder structure, load author profile
2. **Plan** - Classify article type, create outline
3. **Research** - Web search for sources
4. **Draft** - Write in primary language
5. **Companion Project** - Create complete runnable companion project
6. **Integrate** - Merge companion project into article
7. **Review** - Check accuracy and voice compliance
8. **Condense** - Enforce max_words limit
9. **Translate** - Create other language versions
10. **Finalize** - Update database metadata

---

## /article-writer:next

Get the next pending article from the queue.

### Usage

```bash
/article-writer:next
```

### What It Does

1. Queries the database for articles with `status = 'pending'`
2. Sorts by ID (ascending)
3. Returns the first pending article with details
4. Shows the command to start writing

### Example Output

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  ID:       5
  Title:    Implementing Rate Limiting in Laravel
  Area:     Backend
  Author:   mwguerra

  Subject:
  How to implement and customize rate limiting in Laravel APIs
  using built-in middleware and Redis.

────────────────────────────────────────────────────────────────
  To start writing:
  /article-writer:article from-queue 5
────────────────────────────────────────────────────────────────

  Queue: 1 pending, 3 draft, 2 published
═══════════════════════════════════════════════════════════════
```

---

## /article-writer:queue

Manage the article queue.

### `list` - List Queued Articles

```bash
/article-writer:queue list                    # All articles
/article-writer:queue list pending            # Only pending
/article-writer:queue list author:mwguerra    # By author
/article-writer:queue list area:Laravel       # By area
```

### `status` - Queue Summary

```bash
/article-writer:queue status
```

**Example output:**

```
═══════════════════════════════════════════════════════════════
  ARTICLE QUEUE
═══════════════════════════════════════════════════════════════

  Total: 25 articles

  By Status:
    ⏳ pending: 18
    📝 draft: 5
    ✅ published: 2

  By Author:
    mwguerra: 20
    tech-writer: 5

  Top Areas:
    Laravel: 10
    PHP: 6
    Architecture: 4

  For full list: /article-writer:queue list
────────────────────────────────────────────────────────────────
```

### `show <id>` - Show Article Details

```bash
/article-writer:queue show 42
```

---

## /article-writer:batch

Process multiple articles from the queue.

### Usage

```bash
/article-writer:batch <n>                  # Process n pending articles
/article-writer:batch author:<id>          # All pending by author
/article-writer:batch area:<name>          # All pending in area
```

### Examples

```bash
# Process next 5 pending
/article-writer:batch 5

# Process all by author
/article-writer:batch author:mwguerra

# Process all Laravel articles
/article-writer:batch area:Laravel
```

### During Processing

Commands available:
- `pause` - Finish current article, then stop
- `skip` - Skip current, continue to next
- `status` - Show progress
- `abort` - Stop immediately

---

## /article-writer:social

Create social media posts for LinkedIn, Instagram, or X/Twitter — standalone or derived from blog articles.

### Usage

```bash
# Standalone posts from a topic
/article-writer:social linkedin "Why rate limiting matters"
/article-writer:social instagram "5 Laravel tips"
/article-writer:social x "The future of PHP"

# Derive from existing blog article
/article-writer:social linkedin derive 42
/article-writer:social all derive 42    # All 3 platforms at once

# With author override
/article-writer:social linkedin "topic" --author mwguerra
```

### Platforms

| Platform | Length | Hashtags | Output Files |
|----------|--------|----------|-------------|
| `linkedin` | 200-1300 words | 3-5 | `{slug}.linkedin.{lang}.md` |
| `instagram` | 2200 chars caption + carousel | 20-30 | `{slug}.instagram.{lang}.md` + `{slug}.instagram.carousel.{lang}.md` |
| `x` | 280 chars/tweet, 5-15 tweet thread | 1-3 | `{slug}.x.tweet.{lang}.md` + `{slug}.x.thread.{lang}.md` |
| `all` | All 3 platforms | Per platform | All of the above |

### Derive Mode

When deriving from a blog article:
- Reads the source article to extract key themes
- Creates `social/` subfolder inside the source article's folder
- Links back to blog article via `derived_from` FK
- Content stands alone (no dependency on reading the blog)

### Workflow

```
Standalone: Initialize → Plan → Research (light) → Draft → Review → Translate → Finalize
Derive:     Initialize → Read Source → Plan Adaptation → Draft → Review → Translate → Finalize
```

### Platform Defaults

View and modify per-platform settings:

```bash
# View LinkedIn defaults
/article-writer:settings show linkedin

# Change LinkedIn word target
/article-writer:settings set platform_defaults.linkedin.max_words 800

# Reset one platform to defaults
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts reset-platform linkedin
```

### Queue Filtering

```bash
# List only LinkedIn posts
/article-writer:queue list platform:linkedin

# View platform breakdown
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --platform
```

---

## /article-writer:doctor

Validate and fix database records.

### Usage

```bash
/article-writer:doctor                  # Interactive mode
/article-writer:doctor --check          # Check only, don't fix
/article-writer:doctor --fix            # Auto-fix with defaults
```

### What It Validates

**Database Integrity:**
- SQLite PRAGMA integrity_check
- Foreign key constraint verification

**Authors:**
- Required fields (id, name, languages)
- ID format (slug-like)
- Languages array not empty
- Tone values 1-10

**Settings:**
- Valid companion project types
- Correct field types
- Array fields are arrays

**Articles:**
- Required fields
- Valid enum values (status, difficulty, area, etc.)
- Author references
- Source and companion project structures

### Example Output

```
🔍 Article Writer Doctor
========================

Mode: interactive

Checking database integrity...
✓ Database integrity: OK
✓ Foreign key constraints: OK

Validating authors...
   ✓ All 2 authors valid

Validating settings...
   ✓ Settings valid

Validating articles...
  Article #5: Invalid status 'wip'
   Valid options: pending, in_progress, draft, review, published, archived
   Suggested fix: in_progress
   Apply fix? [Y/n/custom]

────────────────────────────────────────
Summary:
  Checked: 25 articles, 2 authors, settings
  Issues found: 1
  Fixed: 1

✅ Database has been repaired
```

---

## Data Reference

| Resource | Purpose | Command to View |
|----------|---------|-----------------|
| `.article_writer/article_writer.db` | All data (authors, articles, settings) | See commands above |
| `.article_writer/schemas/*.json` | Schema documentation | (validate with doctor) |
| `content/articles/` | Article output | (check after creation) |

---

## See Also

- [PROCESS.md](PROCESS.md) - Complete workflow guide
- [README.md](../README.md) - Plugin overview
- [schemas/](../schemas/) - Schema definitions
