---
description: Analyze project and generate SEO data - meta tags, keywords, Open Graph images, favicons
argument-hint: [analyze|generate|export] [--page <route>] [--all]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# SEO Analysis Command

Analyze your project and generate comprehensive SEO data for all public pages.

## Subcommands

### `analyze` - Analyze project for SEO opportunities
```
/pd-seo analyze [--docs path/to/docs] [--pages path/to/pages]
```

### `generate` - Generate SEO data for pages
```
/pd-seo generate [--page /specific/route] [--all]
```

### `export` - Export SEO data in various formats
```
/pd-seo export [--format json|html|sitemap]
```

## Instructions

1. Parse subcommand from `$ARGUMENTS`
2. Load existing SEO plan from `.post-development/seo/seo-plan.json` if exists
3. Execute the appropriate action

### For `analyze`:

1. **Discover public pages**:
   - Scan route files (Next.js, React Router, Vue Router, etc.)
   - Look for public-facing pages (exclude admin, auth, API routes)
   - Read existing meta tags in pages

2. **Extract content for keywords**:
   - Read page components/templates
   - Analyze headings (H1, H2, H3)
   - Extract key features and benefits from docs
   - Identify industry/niche terms

3. **Analyze competitors** (if URLs provided):
   - Note common keywords
   - Identify content gaps

4. **Generate SEO recommendations**:
   - Primary keywords per page
   - Secondary keywords
   - Content structure suggestions

### For `generate`:

Create SEO data files in `.post-development/seo/pages/`:

```json
{
  "route": "/",
  "title": "MyApp - Streamline Your Workflow | #1 Productivity Tool",
  "description": "Transform how you work with MyApp. Boost productivity by 40% with our AI-powered workflow automation. Start free trial today.",
  "keywords": ["productivity", "workflow automation", "AI tools", "task management"],
  "openGraph": {
    "title": "MyApp - Streamline Your Workflow",
    "description": "Transform how you work with MyApp",
    "type": "website",
    "image": {
      "url": "/og/homepage.png",
      "width": 1200,
      "height": 630,
      "alt": "MyApp Dashboard Preview"
    }
  },
  "twitter": {
    "card": "summary_large_image",
    "title": "MyApp - Streamline Your Workflow",
    "description": "Transform how you work with MyApp",
    "image": "/og/homepage.png"
  },
  "structuredData": {
    "@type": "WebApplication",
    "name": "MyApp",
    "description": "...",
    "applicationCategory": "ProductivityApplication"
  },
  "canonical": "https://myapp.com/",
  "robots": "index, follow",
  "suggestions": {
    "images": [
      {
        "purpose": "og-image",
        "description": "Dashboard screenshot with key metrics visible",
        "dimensions": "1200x630"
      },
      {
        "purpose": "twitter-card",
        "description": "App logo with tagline",
        "dimensions": "1200x600"
      }
    ],
    "favicon": {
      "description": "Simple icon representing productivity/workflow",
      "sizes": ["16x16", "32x32", "180x180", "192x192", "512x512"]
    }
  }
}
```

### For `export`:

**JSON format**: Raw SEO data
**HTML format**: Ready-to-paste meta tags
**Sitemap format**: XML sitemap

## Output Structure

```
.post-development/seo/
├── seo-plan.json           # Master SEO plan
├── pages/
│   ├── homepage.json       # SEO data for /
│   ├── features.json       # SEO data for /features
│   ├── pricing.json        # SEO data for /pricing
│   └── ...
├── assets/
│   ├── favicons/
│   │   └── favicon-spec.json
│   └── og-images/
│       └── og-images-spec.json
├── sitemap.xml             # Generated sitemap
└── meta-tags.html          # Copy-paste meta tags
```

## SEO Plan Schema

```json
{
  "project": {
    "name": "MyApp",
    "domain": "myapp.com",
    "type": "saas",
    "industry": "productivity"
  },
  "global": {
    "brandKeywords": ["MyApp", "productivity tool"],
    "targetAudience": ["small business", "freelancers", "remote teams"],
    "competitors": ["competitor1.com", "competitor2.com"],
    "tone": "professional yet approachable"
  },
  "pages": [
    {
      "route": "/",
      "priority": 1.0,
      "status": "pending",
      "file": "pages/homepage.json"
    }
  ],
  "assets": {
    "favicon": { "status": "pending" },
    "ogImages": { "status": "pending" }
  },
  "generatedAt": null,
  "lastUpdated": null
}
```

## Keyword Research Guidelines

1. **Primary keyword**: Main topic of the page (1 per page)
2. **Secondary keywords**: Related terms (3-5 per page)
3. **Long-tail keywords**: Specific phrases users search (2-3 per page)
4. **LSI keywords**: Semantically related terms

## Title Tag Best Practices

- 50-60 characters max
- Primary keyword near the beginning
- Brand name at the end (if space)
- Unique for each page
- Compelling and click-worthy

## Meta Description Best Practices

- 150-160 characters max
- Include primary keyword naturally
- Call to action when appropriate
- Unique for each page
- Accurately describe page content

## Status Tracking

Each page in the SEO plan tracks:
- `pending`: Not yet analyzed
- `analyzed`: Content analyzed, keywords identified
- `generated`: Full SEO data generated
- `exported`: Meta tags exported for implementation
