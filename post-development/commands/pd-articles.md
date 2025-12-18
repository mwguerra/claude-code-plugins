---
description: Generate showcase articles about your app in technical, casual, or story style for content marketing
argument-hint: [create|list|edit|export] [--article 1|2|3] [--style technical|casual|story]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Article Generation Command

Generate 3 high-quality showcase articles about your application for content marketing.

## Subcommands

### `create` - Create articles
```
/pd-articles create [--count 3] [--style technical|casual|story]
```

### `list` - List existing articles
```
/pd-articles list [--status draft|ready|published]
```

### `edit` - Edit specific article
```
/pd-articles edit [--article 1|2|3]
```

### `export` - Export articles
```
/pd-articles export [--format markdown|html|docx] [--article 1|2|3|all]
```

## Instructions

1. Parse subcommand from `$ARGUMENTS`
2. Load project context from SEO analysis and personas
3. Load available screenshots for article images
4. Generate 3 distinct articles with different angles

### For `create`:

Generate 3 articles with distinct purposes:

**Article 1: Problem-Solution Story**
- Focus on the pain point your app solves
- Narrative structure with relatable scenario
- Hero's journey format
- Target: Awareness stage

**Article 2: Feature Deep-Dive**
- Technical walkthrough of key features
- How-to format with screenshots
- Practical value demonstration
- Target: Consideration stage

**Article 3: Success Story / Case Study**
- Results-focused narrative
- Before/after comparison
- Social proof and metrics
- Target: Decision stage

## Output Structure

```
.post-development/articles/
├── articles-plan.json      # Master article plan
├── article-1/
│   ├── article.json        # Article metadata
│   ├── article.md          # Full article in Markdown
│   ├── outline.md          # Article outline
│   └── images/
│       ├── hero.png        # Symlink to screenshot
│       ├── feature-1.png
│       └── ...
├── article-2/
│   ├── article.json
│   ├── article.md
│   ├── outline.md
│   └── images/
└── article-3/
    ├── article.json
    ├── article.md
    ├── outline.md
    └── images/
```

## Article Schema

```json
{
  "id": "article-1",
  "title": "How [Product] Saved Our Team 10 Hours Every Week",
  "subtitle": "A founder's journey from chaos to clarity",
  "slug": "how-product-saved-team-10-hours",
  
  "metadata": {
    "type": "problem-solution",
    "targetPersona": "startup-founder",
    "buyerStage": "awareness",
    "estimatedReadTime": "8 min",
    "wordCount": 1800
  },
  
  "seo": {
    "metaTitle": "How [Product] Saved Our Team 10 Hours Every Week | [Brand]",
    "metaDescription": "Discover how one startup went from juggling 10 tools to streamlined productivity with [Product]. Real results, real story.",
    "keywords": ["productivity", "startup tools", "workflow automation"],
    "canonicalUrl": "/blog/how-product-saved-team-10-hours"
  },
  
  "structure": {
    "hook": "Opening that grabs attention with relatable pain",
    "sections": [
      {
        "heading": "The Breaking Point",
        "purpose": "Establish the problem",
        "wordCount": 300
      },
      {
        "heading": "Searching for a Solution",
        "purpose": "The journey to finding the product",
        "wordCount": 250
      },
      {
        "heading": "The [Product] Difference",
        "purpose": "Introduce the solution",
        "wordCount": 400
      },
      {
        "heading": "Results That Matter",
        "purpose": "Concrete outcomes",
        "wordCount": 350
      },
      {
        "heading": "Getting Started",
        "purpose": "CTA and next steps",
        "wordCount": 200
      }
    ],
    "conclusion": "Strong CTA with emotional resonance"
  },
  
  "images": [
    {
      "placement": "hero",
      "source": "../screenshots/desktop/light/1_dashboard_1.png",
      "alt": "MyApp dashboard showing key metrics",
      "caption": "The MyApp dashboard - everything at a glance"
    },
    {
      "placement": "section-3",
      "source": "../screenshots/desktop/light/2_features_1.png",
      "alt": "Feature demonstration",
      "caption": "Setting up your first workflow takes just 5 minutes"
    }
  ],
  
  "cta": {
    "primary": {
      "text": "Start Your Free Trial",
      "url": "/signup?utm_source=blog&utm_medium=article-1"
    },
    "secondary": {
      "text": "See How It Works",
      "url": "/demo"
    }
  },
  
  "status": "draft",
  "createdAt": "2025-01-15T10:00:00Z"
}
```

## Article Types & Templates

### Type 1: Problem-Solution Story

**Structure:**
1. **Hook** (100 words) - Relatable pain point scenario
2. **The Problem** (300 words) - Deep dive into the challenge
3. **The Search** (200 words) - What solutions were tried
4. **The Discovery** (300 words) - Finding your product
5. **The Transformation** (400 words) - Implementation and features
6. **The Results** (300 words) - Concrete outcomes
7. **Your Turn** (200 words) - CTA and encouragement

**Tone:** Narrative, empathetic, inspiring
**Images:** 3-4 screenshots showing transformation

### Type 2: Feature Deep-Dive

**Structure:**
1. **Introduction** (150 words) - What problem this solves
2. **Feature Overview** (200 words) - High-level explanation
3. **Step-by-Step Guide** (600 words) - Detailed walkthrough
4. **Pro Tips** (300 words) - Advanced usage
5. **Common Questions** (250 words) - FAQ format
6. **Getting Started** (150 words) - CTA

**Tone:** Educational, practical, clear
**Images:** 5-6 screenshots with annotations

### Type 3: Success Story / Case Study

**Structure:**
1. **Executive Summary** (150 words) - Key results upfront
2. **The Challenge** (300 words) - Initial situation
3. **The Solution** (300 words) - How product was implemented
4. **The Process** (400 words) - Implementation journey
5. **The Results** (300 words) - Metrics and outcomes
6. **Key Takeaways** (200 words) - Lessons learned
7. **Next Steps** (150 words) - CTA

**Tone:** Professional, data-driven, credible
**Images:** Before/after comparisons, metrics graphics

## Image Selection Guidelines

For each article, select images that:

1. **Support the narrative** - Illustrate key points
2. **Show the product** - Real screenshots, not stock photos
3. **Highlight value** - Focus on features mentioned
4. **Are high quality** - Clear, well-composed
5. **Have variety** - Different views/sections of app

### Image Placement

- **Hero image**: Full-width at top (desktop screenshot)
- **Inline images**: Within sections (feature-specific)
- **Comparison images**: Side-by-side when relevant
- **CTA image**: Near conclusion (success/results view)

## Content Guidelines

### Headlines
- Use numbers when possible ("5 Ways...", "10 Hours...")
- Include benefit or outcome
- Create curiosity or urgency
- Keep under 70 characters for SEO

### Body Copy
- Short paragraphs (3-4 sentences max)
- Use subheadings every 200-300 words
- Include bullet points for lists
- Bold key phrases for scanning
- Use "you" language (reader-focused)

### SEO Optimization
- Primary keyword in title and H1
- Keywords in first 100 words
- Keywords in subheadings naturally
- Meta description with CTA
- Alt text for all images

### CTAs Within Article
- Soft CTA after introduction
- Medium CTA mid-article
- Strong CTA at conclusion
- Contextual CTAs near relevant features

## Export Formats

### Markdown
Standard markdown for most CMS platforms

### HTML
Styled HTML ready for web publishing

### DOCX
Word document for editing/review

### JSON
Structured data for headless CMS
