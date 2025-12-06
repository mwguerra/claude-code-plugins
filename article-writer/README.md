# Article Writer Plugin

Create high-quality technical articles with research, documentation, and multi-language support. Supports multiple authors, automatic translations, and batch processing via agent mode.

## Quick Start

```bash
# Initialize in your project (creates first author)
/article-writer:init

# Add another author
/article-writer:author add

# Create single article
/article-writer:article implementing rate limiting in Laravel

# Create with specific author
/article-writer:article implementing rate limiting --author mwguerra

# Check queue status
/article-writer:queue status

# Process batch of articles
/article-writer:batch 5
```

## Commands

| Command | Description |
|---------|-------------|
| `/article-writer:init` | Initialize plugin, create first author |
| `/article-writer:author add` | Add new author profile |
| `/article-writer:author list` | List all authors |
| `/article-writer:author show ID` | Show author details |
| `/article-writer:article <topic>` | Create article (uses default author) |
| `/article-writer:article <topic> --author ID` | Create with specific author |
| `/article-writer:article from-queue ID` | Create from queue |
| `/article-writer:batch N` | Process N pending articles |
| `/article-writer:batch author:ID` | Process all for author |
| `/article-writer:queue status` | Show queue summary |
| `/article-writer:queue list` | List pending articles |

## Agent Mode

For fully autonomous batch processing:

```
Process next 10 pending articles
Process all pending articles in area "Laravel"
Process all pending articles by author "mwguerra"
Show article queue status
```

## Project Structure

After `/article-writer:init`:

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json
│   │   ├── authors.schema.json
│   │   └── settings.schema.json
│   ├── article_tasks.json           # Task queue
│   ├── authors.json                 # Author profiles
│   └── settings.json                # Global settings (example defaults)
└── content/
    └── articles/
        └── 2025_01_15_rate-limiting/
            ├── 00_context/
            ├── 01_planning/
            ├── 02_research/
            ├── 03_drafts/
            ├── 04_review/
            ├── 05_assets/
            ├── code/                     # Practical example
            │   ├── README.md
            │   ├── app/
            │   ├── tests/
            │   └── composer.json
            ├── rate-limiting.pt_BR.md    # Primary
            └── rate-limiting.en_US.md    # Translation
```

## Multi-Language Support

Authors define their writing languages:

```json
{
  "id": "mwguerra",
  "name": "MW Guerra",
  "languages": ["pt_BR", "en_US"]
}
```

- First language is **primary** (article written here first)
- Other languages are **translation targets**
- Each file includes language code: `article.pt_BR.md`

## Author Profiles

Authors define voice, tone, and preferences:

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
    "signature": ["Na prática..."],
    "avoid": ["Simplesmente"]
  }
}
```

## Article Task Fields

Key fields in article_tasks.json:

| Field | Description |
|-------|-------------|
| `author.id` | Author reference |
| `author.languages` | Languages for this article |
| `output_folder` | Base folder path |
| `output_files` | Per-language file paths |
| `sources_used` | Web sources researched and used |
| `example` | Practical example info (type, path, files) |
| `created_at` | When task was added |
| `written_at` | When primary article completed |
| `published_at` | When article went live |
| `status` | pending/in_progress/draft/review/published |

## Article Creation Process

1. **Initialize** - Select author, create folder structure
2. **Plan** - Classify type, define audience, create outline
3. **Research** - **Search web** for docs, news, tutorials (< 1 year)
4. **Draft** - Write initial draft in primary language
5. **Example** - Create practical example (code project, document, template)
6. **Integrate** - Update draft with example code/content
7. **Review** - Check flow, voice compliance, example accuracy
8. **Translate** - Create versions for other languages
9. **Finalize** - Update task with paths, sources, and example info

## Practical Examples

> **Examples must be COMPLETE and RUNNABLE, not snippets.**

Every article includes a practical example that readers can clone and run immediately.

### Code Examples (Laravel)

Code examples are **full Laravel installations** created via `composer create-project`:

```
content/articles/2025_01_15_rate-limiting/
├── code/                          # FULL Laravel project
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── public/
│   ├── resources/
│   ├── routes/
│   ├── storage/
│   ├── tests/
│   ├── .env.example
│   ├── artisan
│   ├── composer.json
│   └── README.md
├── rate-limiting.pt_BR.md
└── rate-limiting.en_US.md
```

**Readers can immediately:**
```bash
cd code
composer install
php artisan serve
# Visit http://localhost:8000
```

### Example Types

| Type | What Gets Created |
|------|-------------------|
| `code` | **Full application** (Laravel, Node, etc.) |
| `document` | Templates + filled examples |
| `diagram` | Valid Mermaid diagrams |
| `config` | Working docker-compose setup |
| `script` | Executable bash scripts |
| `dataset` | Data files + schemas |

### Global Example Defaults

Defaults in `.article_writer/settings.json`:

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

Article-specific values override defaults.

### Verification

Before an example is complete:
- [ ] Can be cloned fresh
- [ ] Dependencies install without errors  
- [ ] Application runs
- [ ] Tests pass

See `skills/example-creator/SKILL.md` for complete instructions.

## Web Research

During article creation, the system searches the web for:
- Official documentation
- Recent news and updates (within 1 year for technical subjects)
- Tutorials and best practices
- Related GitHub repositories

All sources are tracked in `article_tasks.json`:

```json
{
  "sources_used": [
    {
      "url": "https://laravel.com/docs/11.x/rate-limiting",
      "title": "Rate Limiting - Laravel Documentation",
      "summary": "Official docs on RateLimiter facade",
      "usage": "Primary reference for code examples",
      "type": "documentation"
    }
  ]
}
```

## Scripts

```bash
# Initialize plugin
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/init.ts

# Check init status
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/init.ts --check

# Add author from JSON
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/init.ts --author '{"id":"...", ...}'

# Queue management
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/queue.ts status
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/queue.ts list author:mwguerra
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/queue.ts show 42

# Create article folder
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts <path>

# Run quality checklists
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/run-checklist.ts <folder>
```

## Skills

| Skill | Purpose |
|-------|---------|
| article-writer | Full article creation workflow |
| author-profile | Author management and voice |
| article-queue | Queue operations |

## Requirements

- Bun runtime (for scripts)
- Claude Code with plugin support

## Writing Standards

- Hook reader in first 150 words
- Maximum 4 sentences per paragraph
- Explain technical terms on first use
- Test all code examples
- Attribute sources inline
- Match author's tone settings
