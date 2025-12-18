---
description: Design landing page proposals with hero, features, testimonials, and CTAs tailored to personas
argument-hint: [create|list|export] [--persona <n>] [--template saas|product|service]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Landing Page Command

Generate comprehensive landing page proposals tailored to each persona.

## Subcommands

### `create` - Create landing page proposals
```
/pd-landing create [--persona <n>|all] [--template saas|product|service]
```

### `list` - List existing proposals
```
/pd-landing list [--status draft|ready]
```

### `export` - Export landing page specs
```
/pd-landing export [--format json|html|figma] [--persona <n>]
```

## Instructions

1. Parse subcommand from `$ARGUMENTS`
2. Load personas from `.post-development/personas/`
3. Load screenshots from `.post-development/screenshots/`
4. Load SEO data from `.post-development/seo/`
5. Generate persona-specific landing page proposals

### For `create`:

For each persona, generate a complete landing page specification:

1. **Analyze persona** - pain points, motivations, objections
2. **Select messaging** - from strategy and CTAs
3. **Choose screenshots** - best visuals for this persona
4. **Structure sections** - optimized for conversion
5. **Write copy** - persona-specific language
6. **Define CTAs** - strategic placement

## Output Structure

```
.post-development/landing-pages/
├── landing-plan.json           # Master landing page plan
├── primary-persona/
│   ├── landing-page.json       # Full specification
│   ├── copy.md                 # All copy in markdown
│   ├── wireframe.md            # ASCII wireframe
│   └── images/
│       ├── hero.png
│       ├── features/
│       └── testimonials/
├── secondary-persona-1/
│   └── ...
└── secondary-persona-2/
    └── ...
```

## Landing Page Schema

```json
{
  "id": "lp-startup-founder",
  "persona": "startup-founder",
  "template": "saas",
  "url": "/lp/startups",
  
  "meta": {
    "title": "MyApp for Startups | Ship Faster with Less Chaos",
    "description": "The all-in-one platform built for fast-moving startup teams. Replace 10 tools with one. Start free.",
    "ogImage": "images/og-startups.png"
  },
  
  "sections": [
    {
      "id": "hero",
      "type": "hero",
      "layout": "image-right",
      "content": {
        "badge": "🚀 Built for Startups",
        "headline": "Stop juggling tools.\nStart shipping products.",
        "subheadline": "The all-in-one platform that lets your team focus on what matters - building great products.",
        "cta": {
          "primary": {
            "text": "Start Free Trial",
            "url": "/signup?ref=lp-startups",
            "style": "large-prominent"
          },
          "secondary": {
            "text": "Watch Demo",
            "url": "/demo",
            "style": "text-link"
          }
        },
        "socialProof": "Join 500+ startups already shipping faster"
      },
      "image": {
        "src": "../screenshots/desktop/light/1_dashboard_1.png",
        "alt": "MyApp dashboard",
        "style": "browser-frame-shadow"
      }
    },
    
    {
      "id": "pain-points",
      "type": "problem-agitation",
      "layout": "three-column",
      "content": {
        "headline": "Sound familiar?",
        "items": [
          {
            "icon": "🔀",
            "title": "Tool Chaos",
            "description": "Switching between Slack, Notion, Asana, and 7 other tools just to get one thing done."
          },
          {
            "icon": "⏰",
            "title": "Context Switching",
            "description": "Losing hours every week to finding information scattered across different platforms."
          },
          {
            "icon": "💸",
            "title": "Subscription Bloat",
            "description": "Paying for 10 different tools when you only use 20% of each one."
          }
        ]
      }
    },
    
    {
      "id": "solution",
      "type": "solution-intro",
      "layout": "center-text",
      "content": {
        "headline": "There's a better way",
        "description": "MyApp brings everything together in one beautiful, fast platform. No more tab juggling. No more \"where did I put that?\" Just focus and flow.",
        "image": {
          "src": "../screenshots/desktop/light/2_features_1.png",
          "alt": "Unified workspace view"
        }
      }
    },
    
    {
      "id": "features",
      "type": "feature-grid",
      "layout": "alternating",
      "content": {
        "headline": "Everything you need. Nothing you don't.",
        "features": [
          {
            "title": "Unified Workspace",
            "description": "Docs, tasks, messages, and files in one place. Finally.",
            "image": "../screenshots/focused/workspace.png",
            "bullets": [
              "Real-time collaboration",
              "Smart organization",
              "Instant search"
            ]
          },
          {
            "title": "Workflow Automation",
            "description": "Automate the boring stuff. Focus on the creative work.",
            "image": "../screenshots/focused/automation.png",
            "bullets": [
              "Visual workflow builder",
              "100+ integrations",
              "Custom triggers"
            ]
          },
          {
            "title": "Team Analytics",
            "description": "See what's working. Double down on what matters.",
            "image": "../screenshots/focused/analytics.png",
            "bullets": [
              "Project insights",
              "Time tracking",
              "Goal progress"
            ]
          }
        ]
      }
    },
    
    {
      "id": "social-proof",
      "type": "testimonials",
      "layout": "carousel",
      "content": {
        "headline": "Trusted by fast-moving teams",
        "testimonials": [
          {
            "quote": "We replaced 8 tools with MyApp. Our team is 40% more productive and we're saving $2,000/month.",
            "author": "Sarah Chen",
            "title": "CEO, TechStartup",
            "avatar": "placeholder-avatar",
            "logo": "placeholder-logo"
          }
        ],
        "logos": ["company1", "company2", "company3", "company4", "company5"]
      }
    },
    
    {
      "id": "pricing-teaser",
      "type": "pricing-simple",
      "layout": "center",
      "content": {
        "headline": "Simple, startup-friendly pricing",
        "description": "Start free. Scale as you grow. No credit card required.",
        "highlight": {
          "plan": "Startup",
          "price": "$0",
          "period": "forever for teams up to 5",
          "features": [
            "Unlimited projects",
            "All core features",
            "5 team members",
            "Community support"
          ]
        },
        "cta": {
          "text": "Start Free",
          "url": "/signup"
        },
        "note": "Need more? Pro plans start at $12/user/month"
      }
    },
    
    {
      "id": "objection-handling",
      "type": "faq",
      "layout": "two-column",
      "content": {
        "headline": "Questions? We've got answers.",
        "items": [
          {
            "question": "How long does setup take?",
            "answer": "Most teams are up and running in under 5 minutes. We'll import your existing data automatically."
          },
          {
            "question": "Can we migrate from our current tools?",
            "answer": "Yes! We have one-click imports from Notion, Asana, Trello, and 20+ other tools."
          },
          {
            "question": "What if my team doesn't adopt it?",
            "answer": "Our onboarding team will help your team get started. Plus, the interface is so intuitive most people figure it out in minutes."
          },
          {
            "question": "Is our data secure?",
            "answer": "Absolutely. We're SOC 2 certified with enterprise-grade encryption. Your data is yours."
          }
        ]
      }
    },
    
    {
      "id": "final-cta",
      "type": "cta-section",
      "layout": "center-prominent",
      "content": {
        "headline": "Ready to ship faster?",
        "subheadline": "Join 500+ startups who've simplified their workflow with MyApp",
        "cta": {
          "primary": {
            "text": "Start Your Free Trial",
            "url": "/signup?ref=lp-startups-bottom",
            "style": "extra-large"
          }
        },
        "note": "No credit card required • Set up in 5 minutes • Cancel anytime"
      }
    }
  ],
  
  "design": {
    "colorScheme": "light",
    "accentColor": "primary-brand",
    "typography": {
      "headlineFont": "Inter",
      "bodyFont": "Inter"
    },
    "spacing": "generous",
    "style": "modern-minimal"
  },
  
  "tracking": {
    "utm": {
      "source": "landing-page",
      "medium": "web",
      "campaign": "startups-launch"
    },
    "events": [
      "page_view",
      "scroll_depth",
      "cta_click",
      "demo_start"
    ]
  },
  
  "status": "draft",
  "createdAt": "2025-01-15T10:00:00Z"
}
```

## Section Types

### Hero
- Main value proposition
- Primary and secondary CTA
- Hero image or video
- Social proof badge

### Problem-Agitation
- Pain points the persona relates to
- Emotional connection
- 3-4 specific problems

### Solution-Intro
- Bridge from problem to solution
- High-level product introduction
- Single compelling image

### Feature-Grid
- Key features with images
- Benefit-focused descriptions
- Supporting bullet points

### Testimonials
- Customer quotes
- Names and titles
- Company logos

### Social Proof
- Logo wall
- Stats and numbers
- Trust badges

### Pricing-Simple
- Pricing overview
- Free tier highlight
- CTA to full pricing

### FAQ
- Common objections addressed
- Expandable format
- Trust-building answers

### CTA-Section
- Strong closing CTA
- Urgency or scarcity (optional)
- Final reassurance

## Layout Options

- `center-text`: Centered headline and text
- `image-right`: Content left, image right
- `image-left`: Image left, content right
- `alternating`: Features alternate sides
- `three-column`: Grid of 3 items
- `two-column`: Side-by-side layout
- `carousel`: Scrollable items
- `center-prominent`: Large centered CTA

## Persona-Specific Messaging

### B2B Personas
- Focus on ROI and efficiency
- Include security/compliance mentions
- Professional tone
- Team collaboration emphasis

### B2C Personas
- Focus on personal benefits
- Emotional appeal
- Casual, friendly tone
- Individual use emphasis

### Enterprise Personas
- Security and compliance first
- Integration capabilities
- Support and SLA mentions
- Custom pricing CTA

## Image Guidelines

### Hero Images
- Desktop screenshot in browser frame
- Show key value (dashboard, main feature)
- Clean, professional appearance

### Feature Images
- Focused on specific feature
- Clear annotations if needed
- Consistent styling

### Testimonial Images
- Professional headshots
- Company logos
- Trust indicators

## Export Formats

### JSON
Complete specification for developers

### HTML
Static HTML template with all sections

### Figma
Specification formatted for Figma import

### Markdown
Copy document for review and editing
