# Frontmatter Specification

This document defines the YAML frontmatter standard for all notes in the Obsidian vault.

## Required Fields

### title
- **Type:** String (quoted)
- **Purpose:** The display title of the note
- **Rules:**
  - Must match or closely relate to the `# Heading` in the note body
  - Use title case for readability
  - Keep under 80 characters

**Examples:**
```yaml
title: "Laravel Queue Configuration with Redis"
title: "API Rate Limiting Implementation"
title: "Code Reviewer Agent"
```

### description
- **Type:** String (quoted)
- **Purpose:** Brief explanation of the note's content
- **Rules:**
  - One to two sentences
  - Provides context without reading the full note
  - Useful for search results and previews

**Examples:**
```yaml
description: "Step-by-step guide for configuring Laravel queues with Redis backend"
description: "Git commit implementing rate limiting for all public API endpoints"
description: "Specialized agent for reviewing code changes against project standards"
```

### tags
- **Type:** Array of strings
- **Purpose:** Categorization and searchability
- **Rules:**
  - Always include the category as a tag
  - Use lowercase, hyphenated format
  - Include relevant technologies, projects, and concepts
  - Aim for 3-7 tags

**Examples:**
```yaml
tags: [technologies, laravel, redis, queues, performance]
tags: [commit, my-saas-app, api, security, rate-limiting]
tags: [claude-code, agent, code-review, quality]
```

### related
- **Type:** Array of wiki-links
- **Purpose:** Connect related notes for navigation
- **Rules:**
  - Use Obsidian wiki-link format: `[[path/to/note]]`
  - Omit the `.md` extension
  - Prefer bidirectional links (both notes link to each other)
  - Add links as connections become apparent

**Examples:**
```yaml
related: []
related: [[technologies/redis]]
related: [[projects/my-saas-app/README], [technologies/laravel-queues]]
```

### created
- **Type:** Date (YYYY-MM-DD)
- **Purpose:** Track when the note was first created
- **Rules:**
  - Set once, never change
  - Use ISO 8601 date format

**Example:**
```yaml
created: 2026-01-27
```

### updated
- **Type:** Date (YYYY-MM-DD)
- **Purpose:** Track when the note was last modified
- **Rules:**
  - Update whenever content changes
  - Scripts update this automatically
  - Use ISO 8601 date format

**Example:**
```yaml
updated: 2026-01-27
```

## Optional Fields

### archived_from
- **Type:** String (path)
- **Purpose:** Track original location when archived
- **Rules:**
  - Added automatically by archive command
  - Removed when restored

**Example:**
```yaml
archived_from: technologies
```

### source
- **Type:** String
- **Purpose:** Track where the note came from
- **Values:** `claude-code`, `manual`, `imported`

**Example:**
```yaml
source: claude-code
```

### status
- **Type:** String
- **Purpose:** Track note completion state
- **Values:** `draft`, `active`, `archived`, `outdated`

**Example:**
```yaml
status: active
```

## Complete Example

```yaml
---
title: "Implementing API Rate Limiting with Redis"
description: "Complete guide to setting up rate limiting for Laravel APIs using Redis as the backend store"
tags: [technologies, laravel, redis, api, rate-limiting, security]
related: [[projects/my-saas-app/README], [technologies/redis-caching]]
created: 2026-01-27
updated: 2026-01-27
---
```

## Validation Rules

1. **All required fields must be present**
2. **Dates must be valid YYYY-MM-DD format**
3. **Tags must be an array (even if empty: `[]`)**
4. **Related must be an array (even if empty: `[]`)**
5. **Strings with special characters must be quoted**

## Scripts

The plugin's scripts automatically:
- Add frontmatter to new notes
- Update the `updated` field on changes
- Validate frontmatter structure
- Add/modify `archived_from` on archive/restore
