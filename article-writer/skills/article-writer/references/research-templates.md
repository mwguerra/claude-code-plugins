# Research Templates

## sources.json (Primary Format)

```json
{
  "researched_at": "2025-01-15T10:00:00Z",
  "topic": "Rate Limiting in Laravel 11",
  "search_queries": [
    "Laravel 11 rate limiting documentation",
    "Laravel rate limiter best practices 2024",
    "Laravel throttle middleware configuration"
  ],
  "sources": [
    {
      "url": "https://laravel.com/docs/11.x/rate-limiting",
      "title": "Rate Limiting - Laravel 11.x Documentation",
      "summary": "Official documentation covering RateLimiter facade, defining rate limiters in AppServiceProvider, and applying via middleware",
      "usage": "Primary reference for syntax, configuration options, and official best practices",
      "accessed_at": "2025-01-15T10:15:00Z",
      "type": "documentation",
      "credibility": 5
    },
    {
      "url": "https://laravel-news.com/laravel-11-rate-limiting",
      "title": "What's New in Rate Limiting for Laravel 11",
      "summary": "Article covering changes and improvements to rate limiting in Laravel 11",
      "usage": "Used for section on new features and migration notes from Laravel 10",
      "accessed_at": "2025-01-15T10:30:00Z",
      "type": "news",
      "credibility": 4
    },
    {
      "url": "https://github.com/laravel/framework/blob/11.x/src/Illuminate/Cache/RateLimiter.php",
      "title": "Laravel RateLimiter Source Code",
      "summary": "Actual implementation showing token bucket algorithm",
      "usage": "Referenced to explain how rate limiting works under the hood",
      "accessed_at": "2025-01-15T10:45:00Z",
      "type": "repository",
      "credibility": 5
    }
  ]
}
```

## Source Types

| Type | Description | Example |
|------|-------------|---------|
| `documentation` | Official docs | laravel.com/docs, php.net |
| `tutorial` | How-to guides | Step-by-step articles |
| `news` | Announcements | Laravel News, PHP releases |
| `blog` | Blog posts | Dev.to, Medium articles |
| `repository` | Code repos | GitHub, GitLab |
| `specification` | Specs/RFCs | PSR standards, RFCs |
| `other` | Everything else | Forums, videos |

## Credibility Scale

| Score | Source Type | Trust Level |
|-------|-------------|-------------|
| 5 | Official docs, source code, RFCs | Absolute |
| 4 | Official blogs, reputable publications | High |
| 3 | Conference talks, known authors | Medium-High |
| 2 | Blog posts, tutorials | Medium |
| 1 | Forums, comments, unverified | Low |

## sources.md (Alternative Markdown Format)

```markdown
# Sources

## Primary Sources (Credibility 5/5)
| ID | Title | URL | Key Info | Accessed |
|----|-------|-----|----------|----------|
| P1 | Laravel Docs - Rate Limiting | https://... | Official implementation | 2025-01-15 |

## Secondary Sources (Credibility 3-4/5)
| ID | Title | URL | Key Info | Accessed |
|----|-------|-----|----------|----------|
| S1 | Laravel News Article | https://... | New features in v11 | 2025-01-15 |

## How Each Source Was Used
- **P1**: Primary reference for all code examples and configuration
- **S1**: Background on version changes, migration tips
```

## research_notes.md

```markdown
# Research Notes

## Session 1: 2025-01-15

**Focus:** Rate limiting implementation in Laravel 11

**Web Searches Performed:**
1. "Laravel 11 rate limiting documentation" 
   → Found official docs, comprehensive coverage
2. "Laravel rate limiting best practices 2024"
   → Found several tutorials, one from Laravel News
3. "Laravel throttle vs rate limiter difference"
   → Clarified that throttle middleware uses RateLimiter

**Key Findings:**
1. RateLimiter facade is the primary API (Source: P1)
2. Token bucket algorithm used internally (Source: GitHub)
3. New `perMinute()` helper in Laravel 11 (Source: S1)

**Used In Article:**
- Intro: General concept from P1
- Configuration section: Code from P1
- Best practices: Recommendations from S1
- Under the hood: Implementation from GitHub

**Questions Resolved:**
- ✅ Does Laravel 11 change rate limiting? Yes, minor API improvements
- ✅ Default rate limit? 60/minute for API routes
```

## fact_verification.md

```markdown
# Fact Verification

| Claim | Source | Verified | Notes |
|-------|--------|----------|-------|
| Laravel 11 requires PHP 8.2+ | P1 | ✅ | Confirmed in docs |
| Rate limiter uses token bucket | GitHub | ✅ | Verified in source |
| 60 requests/minute is default | P1 | ✅ | For API routes |

## Claims From Web Research
- [x] "New perMinute() helper" - Verified in Laravel News + tested
- [x] "Supports Redis and database" - Confirmed in docs
- [ ] "Performance improved 20%" - Cannot verify, removed claim
```

## code_samples/README.md

```markdown
# Code Samples

## Tested Environment
- PHP: 8.2.x
- Laravel: 11.x
- Cache: Redis (for rate limiting tests)

## Files
- `basic-limiter.php` - Basic rate limiting setup
- `custom-limiter.php` - Custom limiter with dynamic limits
- `test-results.md` - Output from running examples

## Source Attribution
- `basic-limiter.php` based on: Laravel Docs (P1)
- `custom-limiter.php` adapted from: Laravel News example (S1)
```
