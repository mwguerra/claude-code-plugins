---
description: Generate ads for Instagram, Facebook, LinkedIn, Twitter/X, and other social platforms
argument-hint: [create|list|export] [--platform instagram|facebook|linkedin|twitter|all] [--persona <n>]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Ad Creation Command

Generate social media ads tailored to your personas and platforms.

## Subcommands

### `create` - Create ads for platforms
```
/pd-ads create [--platform instagram|facebook|linkedin|twitter|all] [--persona <n>]
```

### `list` - List existing ads
```
/pd-ads list [--platform <platform>] [--status draft|ready|exported]
```

### `export` - Export ads for use
```
/pd-ads export [--platform <platform>] [--format json|csv|zip]
```

## Instructions

1. Parse subcommand from `$ARGUMENTS`
2. Load personas from `.post-development/personas/`
3. Load screenshots from `.post-development/screenshots/`
4. Generate platform-specific ad content

### For `create`:

For each persona and platform combination:

1. **Analyze persona** - messaging, pain points, channels
2. **Select screenshots** - best visuals for the platform
3. **Write copy** - platform-optimized text
4. **Design specifications** - dimensions, formats
5. **Generate variations** - A/B testing options

## Output Structure

```
.post-development/ads/
├── ads-plan.json           # Master ad plan
├── instagram/
│   ├── feed/
│   │   ├── ad-1-primary-persona.json
│   │   ├── ad-2-primary-persona.json
│   │   └── ...
│   ├── stories/
│   │   └── ...
│   └── reels/
│       └── ...
├── facebook/
│   ├── feed/
│   ├── stories/
│   └── carousel/
├── linkedin/
│   ├── single-image/
│   ├── carousel/
│   └── video/
├── twitter/
│   ├── single-image/
│   └── carousel/
└── google/
    ├── display/
    └── responsive/
```

## Platform Specifications

### Instagram

**Feed Post**
- Image: 1080×1080 (square), 1080×1350 (portrait), 1080×566 (landscape)
- Caption: 2,200 characters max (125 visible before "more")
- Hashtags: 20-30 recommended

**Stories**
- Image/Video: 1080×1920 (9:16)
- Duration: Up to 15 seconds
- Text overlay zones: Safe areas

**Reels**
- Video: 1080×1920 (9:16)
- Duration: 15-90 seconds
- Caption: 2,200 characters

### Facebook

**Feed Post**
- Image: 1200×630 (link preview), 1080×1080 (square)
- Text: 125 characters above fold
- Headline: 40 characters
- Description: 30 characters

**Carousel**
- Images: 1080×1080
- 2-10 cards
- Each card: headline + description

### LinkedIn

**Single Image**
- Image: 1200×627 (horizontal), 1080×1080 (square)
- Introductory text: 150 characters recommended
- Headline: 70 characters

**Carousel**
- Document: PDF format
- 2-10 slides
- 1080×1080 or 1920×1080

### Twitter/X

**Single Image**
- Image: 1200×675 (16:9), 1200×1200 (1:1)
- Tweet: 280 characters
- Card title: 70 characters

## Ad Schema

```json
{
  "id": "ig-feed-primary-001",
  "platform": "instagram",
  "format": "feed",
  "persona": "startup-founder",
  
  "creative": {
    "type": "single-image",
    "dimensions": "1080x1080",
    "image": {
      "source": "../screenshots/desktop/light/1_dashboard_1.png",
      "overlay": {
        "headline": "Stop juggling 10 tools",
        "position": "top-center",
        "style": "bold-white-shadow"
      },
      "logo": {
        "position": "bottom-right",
        "size": "small"
      }
    }
  },
  
  "copy": {
    "primary": "Tired of switching between 10 different tools just to get work done?\n\nMeet MyApp - the all-in-one platform that actually gets out of your way.\n\n✅ Everything in one place\n✅ 5-minute setup\n✅ Free forever for small teams\n\nStop context-switching. Start shipping.",
    "cta": "Learn More",
    "ctaUrl": "https://myapp.com/?utm_source=instagram&utm_medium=feed&utm_campaign=launch",
    "hashtags": ["#productivity", "#startups", "#saas", "#workflow", "#teamwork"]
  },
  
  "variations": [
    {
      "id": "ig-feed-primary-001-b",
      "copyVariation": "What if you could replace 10 tools with just one?",
      "ctaVariation": "Try Free"
    }
  ],
  
  "targeting": {
    "interests": ["entrepreneurship", "startups", "productivity", "technology"],
    "demographics": "25-45, tech industry",
    "lookalike": "website visitors"
  },
  
  "status": "draft",
  "createdAt": "2025-01-15T10:00:00Z"
}
```

## Copy Guidelines by Platform

### Instagram
- Visual-first, scroll-stopping imagery
- Emojis acceptable and encouraged
- Story-telling approach
- Strong visual hook in first line
- Hashtag strategy important

### Facebook
- Can be longer-form
- Problem-solution narrative
- Social proof effective
- Clear CTA button
- Engagement-focused

### LinkedIn
- Professional tone
- Industry insights
- Thought leadership angle
- Statistics and data
- B2B focused messaging

### Twitter
- Concise and punchy
- Conversational tone
- Thread potential
- Timely/trending hooks
- Engagement bait (questions, polls)

## Ad Types by Objective

### Awareness
- Brand introduction
- Problem highlighting
- Educational content
- Wide targeting

### Consideration
- Feature showcases
- Comparison content
- Social proof
- Testimonials
- Demos

### Conversion
- Direct CTA
- Limited time offers
- Free trial push
- Pricing focus
- Urgency elements

## A/B Testing Recommendations

For each ad, create variations testing:

1. **Headlines** - Different hooks
2. **Images** - Different screenshots/angles
3. **CTAs** - Different action words
4. **Copy length** - Short vs detailed
5. **Tone** - Professional vs casual

## Export Formats

### JSON
Complete ad data for programmatic use

### CSV
Spreadsheet-friendly for team review

### ZIP
Package with images and copy files ready for upload
