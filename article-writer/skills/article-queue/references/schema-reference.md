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
  "created_at": "2025-01-10T10:00:00Z",
  "written_at": "2025-01-15T14:00:00Z"
}
```
