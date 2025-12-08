# Article Writer Commands

Complete reference for all article-writer commands.

**File Locations:**
- Authors: `.article_writer/authors.json`
- Settings: `.article_writer/settings.json`
- Article Queue: `.article_writer/article_tasks.json`
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
| `/article-writer:settings show <type>` | Show example type defaults |
| `/article-writer:settings set <path> <value>` | Update a setting |
| `/article-writer:settings reset` | Reset to defaults |
| `/article-writer:article <topic>` | Create new article |
| `/article-writer:next` | Get next pending article |
| `/article-writer:queue list` | List queued articles |
| `/article-writer:queue status` | Show queue summary |
| `/article-writer:batch <n>` | Process n articles |
| `/article-writer:doctor` | Validate JSON files |

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
│   ├── article_tasks.json        # Empty queue
│   ├── authors.json              # Empty (add authors next)
│   └── settings.json             # Example defaults
├── content/
│   └── articles/                 # Where articles go
└── docs/                         # Documentation folder
```

### Example Output

```
🚀 Article Writer Initialization

✅ Already exists (will not modify):
   • .article_writer
   • content/articles

📋 Missing items to create:
   • settings.json

📁 Creating directories...
   ✓ .article_writer/schemas/

📋 Setting up schema files...
   ✓ settings.schema.json

📝 Creating data files...
   ✓ settings.json (with example defaults)

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
  File: /your/project/.article_writer/authors.json
────────────────────────────────────────────────────────────────

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
/article-writer:settings set-author mwguerra tone.formality 6

# Add phrase
/article-writer:settings add-phrase mwguerra signature "Na prática..."
```

---

#### `remove <id>` - Remove Author

```bash
/article-writer:author remove tech-writer
```

Asks for confirmation before removing.

---

## /article-writer:settings

View and modify global settings.

### `show` - View Settings

```bash
/article-writer:settings show              # Show all settings
/article-writer:settings show code         # Show code example defaults
/article-writer:settings show document     # Show document defaults
```

**Example output for `/article-writer:settings show`:**

```
═══════════════════════════════════════════════════════════════
  SETTINGS
═══════════════════════════════════════════════════════════════
  File: /your/project/.article_writer/settings.json
────────────────────────────────────────────────────────────────

  Metadata:
    Version: 1.0.0
    Last updated: 2025-01-15T10:00:00Z

  Example Defaults:
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

**Example output for `/article-writer:settings show code`:**

```
═══════════════════════════════════════════════════════════════
  EXAMPLE DEFAULTS: CODE
═══════════════════════════════════════════════════════════════
  File: /your/project/.article_writer/settings.json
────────────────────────────────────────────────────────────────

  Technologies:
    • Laravel 12
    • Pest 4
    • SQLite

  Has Tests: Yes ✓
  Test Command: php artisan test

  Default Path: code/

  Scaffold Command:
    composer create-project laravel/laravel code --prefer-dist

  Post-Scaffold Commands:
    1. cd code
    2. composer require pestphp/pest --dev
    3. php artisan pest:install

  Run Command: php artisan serve

  Notes:
    Create COMPLETE Laravel applications. Must be runnable.

  To modify: /article-writer:settings set <key> <value>
  Example: /article-writer:settings set code.technologies '["Laravel 11"]'
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
| `code.technologies` | `'["Laravel 11", "Pest 3", "MySQL"]'` |
| `code.has_tests` | `true` or `false` |
| `code.scaffold_command` | `"composer create-project laravel/laravel:^11.0 code"` |
| `code.run_command` | `"php artisan serve"` |
| `code.test_command` | `"vendor/bin/pest"` |
| `document.technologies` | `'["Markdown", "AsciiDoc"]'` |

**Examples:**

```bash
# Change Laravel version
/article-writer:settings set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'

# Disable tests for code examples
/article-writer:settings set code.has_tests false

# Change scaffold command
/article-writer:settings set code.scaffold_command "composer create-project laravel/laravel:^11.0 code"
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
5. **Example** - Create complete runnable example
6. **Integrate** - Merge example into article
7. **Review** - Check accuracy and voice compliance
8. **Translate** - Create other language versions
9. **Finalize** - Update task metadata

---

## /article-writer:next

Get the next pending article from the queue.

### Usage

```bash
/article-writer:next
```

### What It Does

1. Loads `.article_writer/article_tasks.json`
2. Filters articles with `status: "pending"`
3. Sorts by priority (critical → high → normal → low)
4. Returns the first pending article with details
5. Shows the command to start writing

### Example Output

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  ID:       laravel-rate-limiting
  Title:    Implementing Rate Limiting in Laravel
  Area:     Backend Development
  Author:   mwguerra
  Priority: high

  Subject:
  How to implement and customize rate limiting in Laravel APIs
  using built-in middleware and Redis.

────────────────────────────────────────────────────────────────
  To start writing:
  /article-writer:article laravel-rate-limiting
────────────────────────────────────────────────────────────────

  Queue: 1 pending, 3 draft, 2 published
═══════════════════════════════════════════════════════════════
```

### When Queue is Empty

```
═══════════════════════════════════════════════════════════════
  NEXT ARTICLE
═══════════════════════════════════════════════════════════════

  ✓ No pending articles in queue!

  Queue: 0 pending, 5 draft, 10 published

  To add articles:
  /article-writer:queue add "Article Title" --area "Category"
═══════════════════════════════════════════════════════════════
```

### Priority Order

Articles are selected in this order:
1. **Priority** (if set): `critical` → `high` → `normal` → `low`
2. **Position** in file (first pending wins)

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
  File: /your/project/.article_writer/article_tasks.json
────────────────────────────────────────────────────────────────

  Total: 25 articles

  By Status:
    ⏳ pending: 18
    📝 draft: 5
    ✅ published: 2

  By Author:
    • mwguerra: 20
    • tech-writer: 5

  Top Areas:
    • Laravel: 10
    • PHP: 6
    • Architecture: 4

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

## /article-writer:doctor

Validate and fix JSON configuration files.

### Usage

```bash
/article-writer:doctor                  # Interactive mode
/article-writer:doctor --check          # Check only, don't fix
/article-writer:doctor --fix            # Auto-fix with defaults
```

### What It Validates

**authors.json:**
- Required fields (id, name, languages)
- ID format (slug-like)
- Languages array not empty
- Tone values 1-10

**settings.json:**
- Valid example types
- Correct field types
- Array fields are arrays

**article_tasks.json:**
- Required fields
- Valid enum values (status, difficulty, area, etc.)
- Author references
- Source and example structures

### Example Output

```
🔍 Article Writer Doctor
========================

Mode: interactive

Checking schema files...
✓ article-tasks.schema.json found
✓ authors.schema.json found
✓ settings.schema.json found
✓ authors.json loaded (2 authors)
✓ settings.json loaded
✓ article_tasks.json loaded (25 articles)

Validating authors.json...
   ✓ All 2 authors valid

Validating settings.json...
   ✓ Settings valid

Validating article_tasks.json...
⚠ Article #5: Invalid status 'wip'
   Valid options: pending, in_progress, draft, review, published, archived
   Suggested fix: in_progress
   Apply fix? [Y/n/custom]

────────────────────────────────────────
Summary:
  Checked: 25 articles, 2 authors, settings
  Issues found: 1
  Fixed: yes

✅ Files have been repaired
```

---

## File Locations Reference

| File | Purpose | Command to View |
|------|---------|-----------------|
| `.article_writer/authors.json` | Author profiles | `/article-writer:author list` |
| `.article_writer/settings.json` | Global settings | `/article-writer:settings show` |
| `.article_writer/article_tasks.json` | Article queue | `/article-writer:queue status` |
| `.article_writer/schemas/*.json` | JSON schemas | (validate with doctor) |
| `content/articles/` | Article output | (check after creation) |

---

## See Also

- [PROCESS.md](PROCESS.md) - Complete workflow guide
- [README.md](../README.md) - Plugin overview
- [schemas/](../schemas/) - JSON schema definitions
