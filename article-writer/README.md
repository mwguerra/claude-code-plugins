# Article Writer Plugin

Create high-quality technical articles with authentic author voice, web research, practical examples, and multi-language support.

## Documentation

| Document | Description |
|----------|-------------|
| **[docs/COMMANDS.md](docs/COMMANDS.md)** | Complete command reference |
| **[docs/PROCESS.md](docs/PROCESS.md)** | Step-by-step workflow guide |

## Architecture

All data is stored in a single SQLite database (`.article_writer/article_writer.db`) using Bun's built-in `bun:sqlite` - zero external dependencies. The database uses WAL mode for concurrent reads and foreign keys for referential integrity.

```
┌─────────────────────────────────────────────┐
│           article_writer.db                 │
├─────────────┬──────────────┬────────────────┤
│  authors    │  articles    │  settings      │
│  (profiles) │  (queue)     │  (config)      │
├─────────────┴──────────────┴────────────────┤
│  metadata  │  schema_version │  articles_fts │
└─────────────────────────────────────────────┘
```

## Features

- **Authentic Voice**: Extract voice patterns from transcripts OR create profiles manually
- **Multi-Author**: Support multiple authors with distinct voices
- **Multi-Language**: Write in primary language, auto-translate to others
- **Web Research**: Automatic source gathering and citation
- **Verified Examples**: Full runnable applications that are actually tested before completion
- **Social Media**: Create platform-optimized posts for LinkedIn, Instagram, and X/Twitter
- **Batch Processing**: Queue and process multiple articles
- **SQLite Backend**: Zero external dependencies, WAL mode, FTS5 full-text search

## Quick Start

### 1. Initialize

```bash
/article-writer:init
```

Creates: `.article_writer/` folder with SQLite database, schemas, and default settings.

### 2. Create Author

**Option A - Manual questionnaire:**
```bash
/article-writer:author add
```

**Option B - Extract from transcripts (recommended):**
```bash
/article-writer:author analyze --speaker "Your Name" podcast.txt
```

### 3. Verify Setup

```bash
# View your author
/article-writer:author list

# View settings
/article-writer:settings show
```

### 4. Write Articles

```bash
/article-writer:article implementing rate limiting in Laravel
```

## Social Media Posts

Create platform-optimized content for LinkedIn, Instagram, and X/Twitter — standalone or derived from blog articles.

```bash
# Standalone posts
/article-writer:social linkedin "Why rate limiting matters"
/article-writer:social instagram "5 Laravel tips"
/article-writer:social x "The future of PHP"

# Derive from existing blog article (all 3 platforms)
/article-writer:social all derive 42
```

Each platform has distinct formatting, length limits, and tone adjustments applied automatically to the author's base voice:

| Platform | Length | Tone Shift |
|----------|--------|------------|
| LinkedIn | 200-1300 words | Slightly more formal |
| Instagram | 2200 char caption + carousel | More casual, opinionated |
| X/Twitter | 280 char tweets / threads | Casual, punchy, opinionated |

Derived posts are stored in a `social/` subfolder inside the source blog article's folder.

## Commands Reference

| Command | Description | Details |
|---------|-------------|---------|
| `/article-writer:init` | Initialize plugin | [docs/COMMANDS.md#init](docs/COMMANDS.md#article-writerinit) |
| `/article-writer:author add` | Create author (questionnaire) | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:author analyze` | Extract voice from transcripts | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:author list` | List all authors | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:author show <id>` | Show author details | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:settings show` | Show all settings | [docs/COMMANDS.md#settings](docs/COMMANDS.md#article-writersettings) |
| `/article-writer:settings show <type>` | Show companion project type defaults | [docs/COMMANDS.md#settings](docs/COMMANDS.md#article-writersettings) |
| `/article-writer:settings set` | Modify a setting | [docs/COMMANDS.md#settings](docs/COMMANDS.md#article-writersettings) |
| `/article-writer:article <topic>` | Create single article | [docs/COMMANDS.md#article](docs/COMMANDS.md#article-writerarticle) |
| `/article-writer:social <platform> <topic>` | Create social media posts | [docs/COMMANDS.md#social](docs/COMMANDS.md#article-writersocial) |
| `/article-writer:next` | Get next pending article | [docs/COMMANDS.md#next](docs/COMMANDS.md#article-writernext) |
| `/article-writer:queue status` | Show queue summary | [docs/COMMANDS.md#queue](docs/COMMANDS.md#article-writerqueue) |
| `/article-writer:batch <n>` | Process n articles | [docs/COMMANDS.md#batch](docs/COMMANDS.md#article-writerbatch) |
| `/article-writer:doctor` | Validate database records | [docs/COMMANDS.md#doctor](docs/COMMANDS.md#article-writerdoctor) |

## Data Storage

| Table | Purpose | View Command |
|-------|---------|--------------|
| `authors` | Author profiles | `/article-writer:author list` |
| `settings` | Companion project defaults + article limits | `/article-writer:settings show` |
| `articles` | Article queue (blog + social) | `/article-writer:queue status` |
| `metadata` | Version and timestamp tracking | (internal) |
| `articles_fts` | Full-text search index | (internal) |

All data lives in a single file: `.article_writer/article_writer.db`

## Author Profiles

### Two Ways to Create Authors

#### Manual Questionnaire

```bash
/article-writer:author add
```

Claude asks about: identity, languages, tone, vocabulary, phrases, opinions.

#### Voice Extraction (Recommended)

```bash
# List speakers in transcript
/article-writer:author analyze --list-speakers podcast.txt

# Extract voice patterns
/article-writer:author analyze --speaker "John Smith" podcast.txt interview.txt
```

**What gets extracted:**
- Sentence structure and length
- Communication style (enthusiastic, analytical, direct, etc.)
- Characteristic expressions
- Signature vocabulary
- Common sentence starters

**Supported transcript formats:** Plain text, timestamped, WhatsApp, SRT subtitles.

### View Authors

```bash
# List all
/article-writer:author list

# Show one in detail
/article-writer:author show mwguerra
```

## Settings

### View Settings

```bash
# Show all
/article-writer:settings show

# Show specific type
/article-writer:settings show code
```

### Modify Settings

```bash
# Change Laravel version
/article-writer:settings set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'

# Change scaffold command
/article-writer:settings set code.scaffold_command "composer create-project laravel/laravel:^11.0 code"

# Set word limit
/article-writer:settings set article_limits.max_words 5000
```

### Reset Settings

```bash
/article-writer:settings reset              # Reset all
/article-writer:settings reset-type code    # Reset just code
```

## Project Structure

After initialization:

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json
│   │   ├── authors.schema.json
│   │   └── settings.schema.json
│   └── article_writer.db
├── content/
│   └── articles/
│       └── 2025_01_15_rate-limiting/
│           ├── code/                     # Complete companion project
│           ├── rate-limiting.pt_BR.md    # Primary
│           └── rate-limiting.en_US.md    # Translation
└── docs/
```

## Practical Companion Projects

> **Companion projects must be COMPLETE and RUNNABLE, not snippets.**

A Laravel companion project is a **full Laravel installation**:

```bash
cd code && composer install && php artisan serve
# Visit http://localhost:8000
```

**Companion project types:**

| Type | What Gets Created |
|------|-------------------|
| `code` | Full application (Laravel, Node, etc.) |
| `node` | Node.js application |
| `python` | Python script/application |
| `document` | Templates + filled-in samples |
| `diagram` | Valid Mermaid diagrams |
| `config` | Working docker-compose setup |
| `script` | Executable bash scripts |
| `dataset` | Data files + schemas |

## Migration from JSON

If upgrading from a previous JSON-based version:

```bash
# Check what would be migrated
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/migrate.ts --check

# Run migration
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/migrate.ts

# Rollback if needed
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/migrate.ts --rollback
```

The migration:
- Reads all 3 JSON files (article_tasks.json, authors.json, settings.json)
- Creates the SQLite database with all tables and indexes
- Inserts all data preserving IDs and relationships
- Renames JSON files to `.json.migrated` (safety net)

## Troubleshooting

### Validate Database

```bash
/article-writer:doctor
```

Checks database integrity, validates all records, and offers to fix issues.

### Check Initialization

```bash
/article-writer:init --check
```

Shows what's missing without creating anything.

### Reset Settings

```bash
/article-writer:settings reset
```

Resets to plugin defaults.

## Requirements

- Bun runtime (for scripts and `bun:sqlite`)
- Claude Code with plugin support

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/init.ts` | Initialize plugin |
| `scripts/show.ts` | View authors, settings, queue |
| `scripts/config.ts` | Modify settings |
| `scripts/queue.ts` | Queue management |
| `scripts/article-stats.ts` | Queue stats and status updates |
| `scripts/doctor.ts` | Validate and fix database |
| `scripts/migrate.ts` | Migrate from JSON to SQLite |
| `scripts/create-article-folder.ts` | Create article folder structure |
| `scripts/voice-extractor.ts` | Extract voice from transcripts |
| `scripts/db.ts` | Shared database module |

## Database Schema

### Tables

| Table | Key Columns | Description |
|-------|-------------|-------------|
| `authors` | id (PK), name, languages (JSON), tone_formality, tone_opinionated, vocabulary (JSON), phrases (JSON), sort_order | Author profiles |
| `articles` | id (PK), title, status, area, difficulty, author_id (FK), platform, derived_from (FK), platform_data (JSON), output_files (JSON), sources_used (JSON) | Article queue with CHECK constraints on all enums |
| `settings` | id=1, article_limits (JSON), companion_project_defaults (JSON), platform_defaults (JSON) | Singleton configuration |
| `metadata` | id=1, version, last_updated | Plugin metadata |
| `articles_fts` | title, subject, tags | FTS5 full-text search (auto-synced via triggers) |

### Key Design Decisions

- **Scalar columns** for frequently-queried fields (status, area, difficulty) with CHECK constraints
- **JSON columns** for complex nested data (voice_analysis, companion_project, output_files)
- **sort_order** on authors: lowest = default author
- **WAL mode** for concurrent read access
- **FTS5** virtual table with insert/update/delete triggers for full-text search

## Skills Reference

| Skill | Purpose | Location |
|-------|---------|----------|
| `article-writer` | Full article creation workflow | `skills/article-writer/SKILL.md` |
| `author-profile` | Author management | `skills/author-profile/SKILL.md` |
| `voice-extractor` | Voice extraction from transcripts | `skills/voice-extractor/SKILL.md` |
| `companion-project-creator` | Create complete companion projects | `skills/companion-project-creator/SKILL.md` |
| `social-post-writer` | Social media post creation | `skills/social-post-writer/SKILL.md` |
| `article-queue` | Queue operations | `skills/article-queue/SKILL.md` |

## Further Reading

- **[docs/COMMANDS.md](docs/COMMANDS.md)** - Complete command reference with examples
- **[docs/PROCESS.md](docs/PROCESS.md)** - Detailed workflow guide
- **[schemas/](schemas/)** - JSON schema definitions and SQL schema
- **[skills/](skills/)** - Skill documentation
