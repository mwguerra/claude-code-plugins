# Schema Reference

> **Storage:** All data is stored in a SQLite database at `.article_writer/article_writer.db` using Bun's built-in `bun:sqlite`. The database uses WAL mode for concurrent reads and foreign keys for referential integrity.

## Article Task Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | Yes | Unique identifier (min: 1) |
| `title` | string | Yes | Article title (10-200 chars) |
| `subject` | string | Yes | Main topic (3-100 chars) |
| `area` | enum | Yes | Technical category |
| `tags` | string | Yes | Comma-separated keywords |
| `difficulty` | enum | Yes | Target skill level |
| `relevance` | string | Yes | Priority description |
| `content_type` | enum | Yes | Article format |
| `estimated_effort` | enum | Yes | Writing time estimate |
| `versions` | string | Yes | Target versions |
| `series_potential` | string | Yes | Series info |
| `prerequisites` | string | Yes | Required knowledge |
| `reference_urls` | string | Yes | Source URLs |
| `status` | enum | Yes | Current state |
| `author_id` | string | | Author ID (FK to authors table) |
| `author_name` | string | | Cached author display name |
| `author_languages` | JSON | | Author languages for this article |
| `output_folder` | string | | Base folder path |
| `output_files` | JSON | | Per-language file paths |
| `sources_used` | JSON | | Web sources researched and used |
| `companion_project` | JSON | | Companion project info |
| `created_at` | datetime | | When task was created |
| `written_at` | datetime | | When primary article completed |
| `published_at` | datetime | | When article published |
| `updated_at` | datetime | | Last modification |
| `error_note` | string | | Error details |

## Author Reference

Articles store author references as separate columns:

```sql
author_id TEXT REFERENCES authors(id),
author_name TEXT,
author_languages TEXT  -- JSON array
```

| Field | Type | Description |
|-------|------|-------------|
| `author_id` | string | Must match id in authors table |
| `author_name` | string | Cached display name |
| `author_languages` | JSON array | Languages for this article |

## Output File

Stored in the `output_files` JSON column as an array:

```json
[
  {
    "language": "pt_BR",
    "path": "content/articles/2025_01_15_slug/slug.pt_BR.md",
    "translated_at": "2025-01-15T14:00:00Z"
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `language` | string | Language code |
| `path` | string | Path from project root |
| `translated_at` | datetime | When completed |

## Source Reference

Stored in the `sources_used` JSON column as an array.

```json
[
  {
    "url": "https://laravel.com/docs/11.x/rate-limiting",
    "title": "Rate Limiting - Laravel Documentation",
    "summary": "Official docs covering RateLimiter facade and configuration",
    "usage": "Primary reference for syntax and best practices",
    "accessed_at": "2025-01-15T10:00:00Z",
    "type": "documentation"
  }
]
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | string | Yes | URL of the source |
| `title` | string | | Page/document title |
| `summary` | string | Yes | What the source covers |
| `usage` | string | Yes | How it was used in article |
| `accessed_at` | datetime | | When accessed |
| `type` | enum | | documentation/tutorial/news/blog/repository/specification/other |

## Companion Project Info

Stored in the `companion_project` JSON column.

> **Companion projects must be COMPLETE and RUNNABLE.**

```json
{
  "type": "code",
  "path": "code/",
  "description": "Complete Laravel app demonstrating rate limiting",
  "technologies": ["Laravel 12", "Pest 4", "SQLite"],
  "scaffold_command": "composer create-project laravel/laravel code",
  "has_tests": true,
  "files": [
    "app/Http/Middleware/RateLimitMiddleware.php",
    "tests/Feature/RateLimitTest.php"
  ],
  "run_command": "php artisan serve",
  "run_instructions": "composer install && php artisan serve",
  "test_command": "php artisan test",
  "verified": true,
  "verified_at": "2025-01-15T14:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `type` | enum | code/node/python/document/diagram/template/dataset/config/script/spreadsheet/other |
| `path` | string | Path to companion project folder (usually `code/`) |
| `description` | string | What the companion project demonstrates |
| `technologies` | array | Technologies used |
| `scaffold_command` | string | Command to create base project |
| `has_tests` | boolean | Whether tests are included |
| `files` | array | Key files (article-specific additions) |
| `run_command` | string | Command to run the companion project |
| `run_instructions` | string | Full setup + run instructions |
| `test_command` | string | Command to run tests |
| `verified` | boolean | Whether companion project was verified working |
| `verified_at` | datetime | When verified |
| `skipped` | boolean | True if companion project was skipped |
| `skip_reason` | string | Why companion project was skipped |

## Settings (settings table)

Global settings stored as a singleton row (id=1) in the `settings` table.

### Structure

Two JSON columns:

| Column | Description |
|--------|-------------|
| `article_limits` | JSON object with `max_words` and other limits |
| `companion_project_defaults` | JSON object with defaults per type |

### Companion Project Defaults Fields

| Field | Type | Description |
|-------|------|-------------|
| `technologies` | array | Default tech stack for this type |
| `has_tests` | boolean | Include tests by default |
| `path` | string | Default companion project folder path |
| `run_instructions` | string | How to run the companion project |
| `setup_commands` | array | List of setup commands |
| `test_command` | string | Command to run tests |
| `file_structure` | array | Expected files/folders |
| `template_repo` | string | Git repo to clone (optional) |
| `notes` | string | Additional notes |

### Default Values (code type)

```json
{
  "code": {
    "technologies": ["Laravel 12", "Pest 4", "SQLite"],
    "has_tests": true,
    "path": "code/",
    "run_instructions": "composer install && cp .env.example .env && php artisan key:generate && touch database/database.sqlite && php artisan migrate --seed && php artisan test",
    "test_command": "php artisan test"
  }
}
```

### Merging with Article Companion Projects

Article-specific values **override** defaults:

```
settings defaults        article companion_project    result
─────────────            ────────────────────────     ──────
technologies: [L12]      technologies: [L11]    ->   [L11]
has_tests: true          (not set)              ->   true
path: "code/"            path: "example/"       ->   "example/"
```

## Database Tables

| Table | Description |
|-------|-------------|
| `authors` | Author profiles with JSON columns for complex data |
| `articles` | Article queue with enum-checked scalar columns + JSON columns |
| `settings` | Singleton settings (id=1) with two JSON columns |
| `metadata` | Singleton metadata (id=1) with version and timestamps |
| `schema_version` | Tracks applied database migrations |
| `articles_fts` | FTS5 full-text search index on title, subject, tags |

## Enums

### area
Architecture, Backend, Business, Database, DevOps, Files, Frontend, Full-stack, JavaScript, Laravel, Native Apps, Notifications, Performance, PHP, Quality, Security, Soft Skills, Testing, Tools, AI/ML

### difficulty
Beginner, Intermediate, Advanced, All Levels

### content_type
Tutorial, Deep-dive, Guide, Comparison, Quick Tip, Case Study, Opinion, etc.

### estimated_effort
Short, Medium, Long, Long (Series)

### status
pending, in_progress, draft, review, published, archived

## Timestamps

| Field | When Set |
|-------|----------|
| `created_at` | Task added to queue |
| `written_at` | Primary language article completed |
| `published_at` | Article goes live |
| `updated_at` | Any modification |

## Example Task

```json
{
  "id": 1,
  "title": "Implementing Rate Limiting in Laravel 11",
  "subject": "Rate Limiting",
  "area": "Laravel",
  "tags": "laravel, rate-limiting, api",
  "difficulty": "Intermediate",
  "relevance": "High",
  "content_type": "Tutorial with Examples",
  "estimated_effort": "Medium",
  "versions": "Laravel 11.x",
  "series_potential": "Yes",
  "prerequisites": "Basic Laravel",
  "reference_urls": "https://laravel.com/docs",
  "author_id": "mwguerra",
  "author_name": "MW Guerra",
  "author_languages": ["pt_BR", "en_US"],
  "status": "draft",
  "output_folder": "content/articles/2025_01_15_rate-limiting/",
  "output_files": [
    {
      "language": "pt_BR",
      "path": "content/articles/2025_01_15_rate-limiting/rate-limiting.pt_BR.md",
      "translated_at": "2025-01-15T14:00:00Z"
    }
  ],
  "sources_used": [
    {
      "url": "https://laravel.com/docs/11.x/rate-limiting",
      "title": "Rate Limiting - Laravel Documentation",
      "summary": "Official docs on RateLimiter facade and middleware",
      "usage": "Primary reference for all code examples",
      "accessed_at": "2025-01-15T10:00:00Z",
      "type": "documentation"
    }
  ],
  "companion_project": {
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
  },
  "created_at": "2025-01-10T10:00:00Z",
  "written_at": "2025-01-15T14:00:00Z"
}
```
