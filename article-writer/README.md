# Article Writer Plugin

Create high-quality technical articles with authentic author voice, web research, practical examples, and multi-language support.

## Documentation

| Document | Description |
|----------|-------------|
| **[docs/COMMANDS.md](docs/COMMANDS.md)** | Complete command reference |
| **[docs/PROCESS.md](docs/PROCESS.md)** | Step-by-step workflow guide |

## Features

- **Authentic Voice**: Extract voice patterns from transcripts OR create profiles manually
- **Multi-Author**: Support multiple authors with distinct voices
- **Multi-Language**: Write in primary language, auto-translate to others
- **Web Research**: Automatic source gathering and citation
- **Complete Examples**: Full runnable applications, not code snippets
- **Batch Processing**: Queue and process multiple articles

## Quick Start

### 1. Initialize

```bash
/article-writer:init
```

Creates: `.article_writer/` folder with schemas, settings, and empty queue.

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

## Commands Reference

| Command | Description | Details |
|---------|-------------|---------|
| `/article-writer:init` | Initialize plugin | [docs/COMMANDS.md#init](docs/COMMANDS.md#article-writerinit) |
| `/article-writer:author add` | Create author (questionnaire) | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:author analyze` | Extract voice from transcripts | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:author list` | List all authors | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:author show <id>` | Show author details | [docs/COMMANDS.md#author](docs/COMMANDS.md#article-writerauthor) |
| `/article-writer:settings show` | Show all settings | [docs/COMMANDS.md#settings](docs/COMMANDS.md#article-writersettings) |
| `/article-writer:settings show <type>` | Show example type defaults | [docs/COMMANDS.md#settings](docs/COMMANDS.md#article-writersettings) |
| `/article-writer:settings set` | Modify a setting | [docs/COMMANDS.md#settings](docs/COMMANDS.md#article-writersettings) |
| `/article-writer:article <topic>` | Create single article | [docs/COMMANDS.md#article](docs/COMMANDS.md#article-writerarticle) |
| `/article-writer:queue status` | Show queue summary | [docs/COMMANDS.md#queue](docs/COMMANDS.md#article-writerqueue) |
| `/article-writer:batch <n>` | Process n articles | [docs/COMMANDS.md#batch](docs/COMMANDS.md#article-writerbatch) |
| `/article-writer:doctor` | Validate JSON files | [docs/COMMANDS.md#doctor](docs/COMMANDS.md#article-writerdoctor) |

## File Locations

| File | Purpose | View Command |
|------|---------|--------------|
| `.article_writer/authors.json` | Author profiles | `/article-writer:author list` |
| `.article_writer/settings.json` | Example defaults | `/article-writer:settings show` |
| `.article_writer/article_tasks.json` | Article queue | `/article-writer:queue status` |
| `.article_writer/schemas/` | JSON schemas | `/article-writer:doctor` |
| `content/articles/` | Output folder | (check after creation) |

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
│   ├── article_tasks.json
│   ├── authors.json
│   └── settings.json
├── content/
│   └── articles/
│       └── 2025_01_15_rate-limiting/
│           ├── code/                     # Complete example
│           ├── rate-limiting.pt_BR.md    # Primary
│           └── rate-limiting.en_US.md    # Translation
└── docs/
```

## Practical Examples

> **Examples must be COMPLETE and RUNNABLE, not snippets.**

A Laravel example is a **full Laravel installation**:

```bash
cd code && composer install && php artisan serve
# Visit http://localhost:8000
```

**Example types:**

| Type | What Gets Created |
|------|-------------------|
| `code` | Full application (Laravel, Node, etc.) |
| `document` | Templates + filled examples |
| `diagram` | Valid Mermaid diagrams |
| `config` | Working docker-compose setup |
| `script` | Executable bash scripts |
| `dataset` | Data files + schemas |

## Troubleshooting

### Validate Configuration

```bash
/article-writer:doctor
```

Checks all JSON files against schemas and offers to fix issues.

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

- Bun runtime (for scripts)
- Claude Code with plugin support

## Skills Reference

| Skill | Purpose | Location |
|-------|---------|----------|
| `article-writer` | Full article creation workflow | `skills/article-writer/SKILL.md` |
| `author-profile` | Author management | `skills/author-profile/SKILL.md` |
| `voice-extractor` | Voice extraction from transcripts | `skills/voice-extractor/SKILL.md` |
| `example-creator` | Create complete examples | `skills/example-creator/SKILL.md` |
| `article-queue` | Queue operations | `skills/article-queue/SKILL.md` |

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/init.ts` | Initialize plugin |
| `scripts/show.ts` | View authors, settings, queue |
| `scripts/config.ts` | Modify settings |
| `scripts/voice-extractor.ts` | Extract voice from transcripts |
| `scripts/queue.ts` | Queue management |
| `scripts/doctor.ts` | Validate and fix JSON |
| `scripts/create-article-folder.ts` | Create article folder structure |

## Further Reading

- **[docs/COMMANDS.md](docs/COMMANDS.md)** - Complete command reference with examples
- **[docs/PROCESS.md](docs/PROCESS.md)** - Detailed workflow guide
- **[schemas/](schemas/)** - JSON schema definitions
- **[skills/](skills/)** - Skill documentation
