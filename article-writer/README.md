# Article Writer Plugin

Create high-quality technical articles with authentic author voice, web research, practical examples, and multi-language support.

## Features

- **Authentic Voice**: Extract voice patterns from transcripts OR create profiles manually
- **Multi-Author**: Support multiple authors with distinct voices
- **Multi-Language**: Write in primary language, auto-translate to others
- **Web Research**: Automatic source gathering and citation
- **Complete Examples**: Full runnable applications, not code snippets
- **Batch Processing**: Queue and process multiple articles

## Quick Start

```bash
# 1. Initialize plugin
/article-writer:init

# 2. Create author (choose one)
/article-writer:author add                    # Manual questionnaire
/article-writer:author analyze --speaker "Name" transcript.txt  # From transcripts

# 3. Write articles
/article-writer:article implementing rate limiting in Laravel
/article-writer:article --author mwguerra API versioning best practices

# 4. Batch process
/article-writer:batch 5
```

## Commands

| Command | Description |
|---------|-------------|
| `/article-writer:init` | Initialize plugin structure |
| `/article-writer:author add` | Create author via questionnaire |
| `/article-writer:author analyze` | Extract voice from transcripts |
| `/article-writer:author list` | List all authors |
| `/article-writer:author show ID` | Show author details |
| `/article-writer:article <topic>` | Create single article |
| `/article-writer:batch N` | Process N pending articles |
| `/article-writer:queue list` | Show article queue |
| `/article-writer:doctor` | Validate JSON files |
| `/article-writer:settings` | Manage example defaults |

## Author Profiles

### Two Ways to Create Authors

#### Option 1: Manual Questionnaire

```bash
/article-writer:author add
```

Claude asks about identity, tone, vocabulary, phrases, and opinions.

#### Option 2: Voice Extraction (Recommended)

```bash
# List speakers in transcript
/article-writer:author analyze --list-speakers podcast.txt

# Extract voice patterns
/article-writer:author analyze --speaker "John Smith" podcast.txt interview.txt

# Enhance existing author
/article-writer:author analyze --speaker "John" --author-id john-dev new_recording.txt
```

Voice extraction analyzes:
- Sentence structure and length
- Communication style (enthusiastic, analytical, direct, etc.)
- Characteristic expressions ("you know", "I think", etc.)
- Signature vocabulary
- Common sentence starters

#### Supported Transcript Formats

- Plain text: `Speaker: text`
- Timestamped: `[00:01:23] Speaker: text`
- WhatsApp: `[17:30, 12/6/2025] Speaker: text`
- SRT subtitles

### Author Profile Structure

```json
{
  "id": "mwguerra",
  "name": "MW Guerra",
  "languages": ["pt_BR", "en_US"],
  "role": "Senior Software Engineer",
  "expertise": ["Laravel", "PHP", "Architecture"],
  "tone": {
    "formality": 4,
    "opinionated": 7
  },
  "vocabulary": {
    "use_freely": ["Controllers", "Middleware"],
    "always_explain": ["DDD", "CQRS"]
  },
  "phrases": {
    "signature": ["Na prática...", "Vamos direto ao ponto:"],
    "avoid": ["Simplesmente", "É só fazer..."]
  },
  "voice_analysis": {
    "extracted_from": ["podcast_ep1.txt"],
    "sample_count": 156,
    "communication_style": [
      { "trait": "enthusiasm", "percentage": 28.5 }
    ],
    "characteristic_expressions": ["you know", "the thing is"],
    "signature_vocabulary": ["approach", "strategy"]
  }
}
```

## Multi-Language Support

Authors define their languages:
- **First language** = Primary (article written here first)
- **Other languages** = Translation targets

```json
{
  "languages": ["pt_BR", "en_US", "es_ES"]
}
```

Output files:
```
rate-limiting.pt_BR.md  # Primary (written first)
rate-limiting.en_US.md  # Translated
rate-limiting.es_ES.md  # Translated
```

## Article Creation Process

1. **Initialize** - Select author, create folder structure
2. **Plan** - Classify type, define audience, create outline
3. **Research** - Search web for docs, news, tutorials
4. **Draft** - Write initial draft in primary language
5. **Example** - Create COMPLETE practical example
6. **Integrate** - Update draft with example content
7. **Review** - Check accuracy, voice compliance
8. **Translate** - Create versions for other languages
9. **Finalize** - Update task with paths and metadata

## Practical Examples

> **Examples must be COMPLETE and RUNNABLE, not snippets.**

### Code Examples = Full Applications

A Laravel example is a **full Laravel installation**:

```bash
# Created via scaffold command
composer create-project laravel/laravel code --prefer-dist
```

Structure:
```
code/
├── app/
├── bootstrap/
├── config/
├── database/
├── public/
├── resources/
├── routes/
├── storage/
├── tests/
├── .env.example
├── artisan
├── composer.json
└── README.md
```

Readers can immediately:
```bash
cd code && composer install && php artisan serve
# Visit http://localhost:8000
```

### Example Types

| Type | What Gets Created |
|------|-------------------|
| `code` | Full application (Laravel, Node, etc.) |
| `document` | Templates + filled examples |
| `diagram` | Valid Mermaid diagrams |
| `config` | Working docker-compose setup |
| `script` | Executable bash scripts |
| `dataset` | Data files + schemas |

### Verification Required

Before completion:
- [ ] Can be cloned fresh
- [ ] Dependencies install without errors
- [ ] Application runs
- [ ] Tests pass

## Project Structure

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json
│   │   ├── authors.schema.json
│   │   └── settings.schema.json
│   ├── article_tasks.json           # Article queue
│   ├── authors.json                 # Author profiles
│   └── settings.json                # Example defaults
└── content/
    └── articles/
        └── 2025_01_15_rate-limiting/
            ├── 00_context/
            ├── 01_planning/
            ├── 02_research/
            ├── 03_drafts/
            ├── 04_review/
            ├── 05_assets/
            ├── code/                     # Complete example
            ├── rate-limiting.pt_BR.md    # Primary
            └── rate-limiting.en_US.md    # Translation
```

## Web Research

During article creation, the system searches for:
- Official documentation (highest priority)
- Recent news and updates (< 1 year for technical topics)
- Tutorials and best practices
- GitHub repositories

Sources tracked in `article_tasks.json`:
```json
{
  "sources_used": [
    {
      "url": "https://laravel.com/docs/...",
      "title": "Rate Limiting - Laravel Docs",
      "type": "documentation",
      "usage": "Primary reference"
    }
  ]
}
```

## Global Settings

Configure example defaults in `.article_writer/settings.json`:

```json
{
  "example_defaults": {
    "code": {
      "technologies": ["Laravel 12", "Pest 4", "SQLite"],
      "scaffold_command": "composer create-project laravel/laravel code --prefer-dist",
      "run_command": "php artisan serve",
      "test_command": "php artisan test"
    }
  }
}
```

Article-specific values override these defaults.

## Skills

| Skill | Purpose |
|-------|---------|
| `article-writer` | Full article creation workflow |
| `author-profile` | Author management and voice configuration |
| `voice-extractor` | Extract voice from transcripts |
| `example-creator` | Create complete, runnable examples |
| `article-queue` | Queue operations and task management |

## Scripts

```bash
# Initialize
bun run scripts/init.ts
bun run scripts/init.ts --check

# Voice extraction
bun run scripts/voice-extractor.ts --speaker "Name" transcript.txt
bun run scripts/voice-extractor.ts --list-speakers transcript.txt

# Queue management
bun run scripts/queue.ts status
bun run scripts/queue.ts list author:mwguerra

# Validation
bun run scripts/doctor.ts --check
bun run scripts/doctor.ts --fix
```

## Requirements

- Bun runtime (for scripts)
- Claude Code with plugin support

## Writing Standards

- Hook reader in first 150 words
- Maximum 4 sentences per paragraph
- Explain technical terms on first use
- Test all code examples
- Attribute sources inline
- Match author's voice and tone
