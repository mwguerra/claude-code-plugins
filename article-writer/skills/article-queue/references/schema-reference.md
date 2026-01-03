# Schema Reference

## Article Task Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | ✓ | Unique identifier (min: 1) |
| `title` | string | ✓ | Article title (10-200 chars) |
| `subject` | string | ✓ | Main topic (3-100 chars) |
| `area` | enum | ✓ | Technical category |
| `tags` | string | ✓ | Comma-separated keywords |
| `difficulty` | enum | ✓ | Target skill level |
| `relevance` | string | ✓ | Priority description |
| `content_type` | enum | ✓ | Article format |
| `estimated_effort` | enum | ✓ | Writing time estimate |
| `versions` | string | ✓ | Target versions |
| `series_potential` | string | ✓ | Series info |
| `prerequisites` | string | ✓ | Required knowledge |
| `reference_urls` | string | ✓ | Source URLs |
| `status` | enum | ✓ | Current state |
| `author` | object | | Author reference |
| `output_folder` | string | | Base folder path |
| `output_files` | array | | Per-language file paths |
| `sources_used` | array | | Web sources researched and used |
| `created_at` | datetime | | When task was created |
| `written_at` | datetime | | When primary article completed |
| `published_at` | datetime | | When article published |
| `updated_at` | datetime | | Last modification |
| `error_note` | string | | Error details |

## Author Reference

```json
{
  "id": "author-slug",
  "name": "Display Name",
  "languages": ["pt_BR", "en_US"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Must match id in authors.json |
| `name` | string | Cached display name |
| `languages` | array | Languages for this article |

## Output File

```json
{
  "language": "pt_BR",
  "path": "content/articles/2025_01_15_slug/slug.pt_BR.md",
  "translated_at": "2025-01-15T14:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `language` | string | Language code |
| `path` | string | Path from project root |
| `translated_at` | datetime | When completed |

## Source Reference

Tracks web sources researched and used in the article.

```json
{
  "url": "https://laravel.com/docs/11.x/rate-limiting",
  "title": "Rate Limiting - Laravel Documentation",
  "summary": "Official docs covering RateLimiter facade and configuration",
  "usage": "Primary reference for syntax and best practices",
  "accessed_at": "2025-01-15T10:00:00Z",
  "type": "documentation"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | string | ✓ | URL of the source |
| `title` | string | | Page/document title |
| `summary` | string | ✓ | What the source covers |
| `usage` | string | ✓ | How it was used in article |
| `accessed_at` | datetime | | When accessed |
| `type` | enum | | documentation/tutorial/news/blog/repository/specification/other |

## Companion Project Info

Tracks the practical companion project created for the article.

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
| `type` | enum | code/document/diagram/template/dataset/config/script/spreadsheet/other |
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

## Settings (settings.json)

Global settings including companion project defaults.

### Structure

```json
{
  "$schema": "./schemas/settings.schema.json",
  "companion_project_defaults": {
    "code": { ... },
    "document": { ... },
    "diagram": { ... },
    "template": { ... },
    "dataset": { ... },
    "config": { ... },
    "other": { ... }
  },
  "metadata": {
    "version": "1.0.0",
    "last_updated": "2025-01-15T00:00:00Z"
  }
}
```

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
settings.json          article companion_project    result
─────────────          ────────────────────────     ──────
technologies: [L12]    technologies: [L11] →     [L11]
has_tests: true        (not set)           →     true
path: "code/"          path: "example/"    →     "example/"
```

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
  "author": {
    "id": "mwguerra",
    "name": "MW Guerra",
    "languages": ["pt_BR", "en_US"]
  },
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
