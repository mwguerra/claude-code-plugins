# Frontmatter Reference

## Standard Article Frontmatter

```yaml
---
title: "Article Title Here"
slug: "article-title-here"
description: "A 150-160 character meta description for SEO"
author: "mwguerra"
author_name: "MW Guerra"
language: "pt_BR"
translations:
  - lang: "en_US"
    path: "./article-title-here.en_US.md"
date: "2025-01-15"
updated: "2025-01-15"
category: "Laravel"
tags:
  - laravel
  - php
  - rate-limiting
difficulty: "Intermediate"
estimated_reading_time: "8 min"
series:
  name: "Laravel Security Series"
  part: 2
  total: 5
prerequisites:
  - "Basic Laravel knowledge"
  - "Understanding of middleware"
versions:
  php: "8.2+"
  laravel: "11.x"
featured_image: "/images/articles/rate-limiting-hero.jpg"
canonical_url: "https://example.com/articles/rate-limiting"
---
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| title | Yes | Article title (< 60 chars for SEO) |
| slug | Yes | URL-friendly identifier |
| description | Yes | Meta description (150-160 chars) |
| author | Yes | Author ID (from authors.json) |
| author_name | Yes | Author display name |
| language | Yes | Language code (e.g., pt_BR, en_US) |
| translations | No | Array of other language versions |
| date | Yes | Publication date (ISO format) |
| updated | No | Last update date |
| category | Yes | Primary category from allowed list |
| tags | Yes | Array of relevant tags |
| difficulty | Yes | Beginner/Intermediate/Advanced/All Levels |
| estimated_reading_time | No | Auto-calculated or manual |
| series | No | Series info if part of series |
| prerequisites | No | Array of required knowledge |
| versions | No | Technology version requirements |
| featured_image | No | Hero image path |
| canonical_url | No | For syndicated content |

## Categories (from schema)

- Architecture
- Backend
- Business
- Database
- DevOps
- Files
- Frontend
- Full-stack
- JavaScript
- Laravel
- Native Apps
- Notifications
- Performance
- PHP
- Quality
- Security
- Soft Skills
- Testing
- Tools
- AI/ML

## Difficulty Levels

| Level | Target Reader |
|-------|---------------|
| Beginner | New to programming or the technology |
| Intermediate | Familiar with basics, learning advanced |
| Advanced | Experienced, seeking deep knowledge |
| All Levels | Content accessible to everyone |

## Series Frontmatter

For articles in a series:

```yaml
series:
  name: "Building a SaaS with Laravel"
  slug: "laravel-saas-series"
  part: 3
  total: 10
  prev_slug: "part-2-authentication"
  next_slug: "part-4-billing"
```

## Minimal Frontmatter

For quick posts:

```yaml
---
title: "Quick Tip: Laravel Collection Macro"
slug: "laravel-collection-macro-tip"
description: "Add custom methods to Laravel collections easily"
author: "mwguerra"
author_name: "MW Guerra"
language: "pt_BR"
date: "2025-01-15"
category: "Laravel"
tags: [laravel, collections, tips]
difficulty: "Intermediate"
---
```

## Translation Frontmatter

For translated versions, reference the original:

```yaml
---
title: "Quick Tip: Laravel Collection Macro"
slug: "laravel-collection-macro-tip"
description: "Add custom methods to Laravel collections easily"
author: "mwguerra"
author_name: "MW Guerra"
language: "en_US"
original:
  lang: "pt_BR"
  path: "./laravel-collection-macro-tip.pt_BR.md"
date: "2025-01-15"
category: "Laravel"
tags: [laravel, collections, tips]
difficulty: "Intermediate"
---
```
