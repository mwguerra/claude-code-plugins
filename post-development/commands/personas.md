---
description: Create buyer personas, audience segments, and marketing strategies with targeted CTAs per market type
argument-hint: [create|list|strategy|cta] [--type b2b|b2c|b2g|b2d] [--persona <name>]
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Persona & Strategy Command

Create detailed personas, target audience segments, and marketing strategies with compelling CTAs.

## Subcommands

### `create` - Create new personas
```
/post-development:personas create [--type b2b|b2c|b2g|b2d] [--count 3]
```

### `list` - List existing personas
```
/post-development:personas list [--verbose]
```

### `strategy` - Generate marketing strategy for persona
```
/post-development:personas strategy [--persona <name>] [--all]
```

### `cta` - Generate CTAs for personas
```
/post-development:personas cta [--persona <name>] [--style aggressive|subtle|educational]
```

## Instructions

1. Parse subcommand from `$ARGUMENTS`
2. Load SEO analysis from `.post-development/seo/` for context
3. Read project documentation to understand features/benefits
4. Generate comprehensive personas and strategies

### For `create`:

Analyze the project and generate personas based on:

1. **Product type** (from SEO analysis)
2. **Key features and benefits**
3. **Target market** (B2B, B2C, B2G, B2D)
4. **Industry/niche**

Create 3-5 detailed personas covering:
- Primary persona (ideal customer)
- Secondary personas (important segments)
- Edge personas (unexpected users)

### For `strategy`:

Generate comprehensive marketing strategy including:
- Messaging framework
- Channel recommendations
- Content pillars
- Conversion funnel
- Competitive positioning

### For `cta`:

Generate CTAs for each persona across:
- Different stages (awareness, consideration, decision)
- Different channels (website, email, ads)
- Different tones (urgent, educational, value-focused)

## Output Structure

```
.post-development/personas/
├── personas.json           # All personas
├── personas/
│   ├── primary-persona.json
│   ├── secondary-persona-1.json
│   └── secondary-persona-2.json
├── strategies/
│   ├── b2b-strategy.json
│   ├── b2c-strategy.json
│   └── overall-strategy.json
├── cta/
│   ├── by-persona/
│   │   ├── primary-ctas.json
│   │   └── secondary-ctas.json
│   └── by-channel/
│       ├── website-ctas.json
│       ├── email-ctas.json
│       └── ads-ctas.json
└── audience-segments.json
```

## Persona Schema

```json
{
  "id": "startup-founder",
  "name": "Sarah the Startup Founder",
  "type": "primary",
  "market": "b2b",
  
  "demographics": {
    "age": "28-40",
    "gender": "any",
    "location": "urban, tech hubs",
    "income": "$80k-200k",
    "education": "bachelor's or higher",
    "jobTitle": "Founder, CEO, CTO",
    "companySize": "1-50 employees"
  },
  
  "psychographics": {
    "values": ["efficiency", "growth", "innovation"],
    "goals": [
      "Scale the business quickly",
      "Reduce operational overhead",
      "Stay competitive with limited resources"
    ],
    "challenges": [
      "Limited time and budget",
      "Too many tools to manage",
      "Need to move fast without breaking things"
    ],
    "fears": [
      "Missing market opportunity",
      "Burning through runway",
      "Team productivity bottlenecks"
    ],
    "motivations": [
      "Building something meaningful",
      "Financial independence",
      "Industry disruption"
    ]
  },
  
  "behavior": {
    "decisionMaking": "fast, ROI-focused",
    "researchStyle": "peer recommendations, product reviews",
    "preferredChannels": ["LinkedIn", "Twitter", "ProductHunt", "newsletters"],
    "contentPreferences": ["case studies", "quick demos", "ROI calculators"],
    "buyingTriggers": [
      "Competitor using similar tool",
      "Growth milestone reached",
      "Pain point becomes critical"
    ],
    "objections": [
      "Is this worth the time to implement?",
      "Will my team actually use it?",
      "Can we afford this at our stage?"
    ]
  },
  
  "journey": {
    "awareness": {
      "touchpoints": ["LinkedIn posts", "tech blogs", "peer mentions"],
      "questions": ["Is there a better way to do X?"]
    },
    "consideration": {
      "touchpoints": ["product website", "comparison articles", "free trials"],
      "questions": ["How does this compare to Y?", "What's the learning curve?"]
    },
    "decision": {
      "touchpoints": ["pricing page", "demo call", "case studies"],
      "questions": ["What's the total cost?", "How fast can we implement?"]
    }
  },
  
  "messaging": {
    "hook": "Stop juggling 10 tools. Start shipping faster.",
    "valueProposition": "One platform to manage your entire workflow, built for startups that move fast.",
    "proofPoints": [
      "Used by 500+ startups",
      "40% average time savings",
      "5-minute setup"
    ],
    "tone": "confident, peer-like, action-oriented"
  }
}
```

## Strategy Schema

```json
{
  "persona": "startup-founder",
  "market": "b2b",
  
  "positioning": {
    "category": "productivity platform",
    "differentiation": "all-in-one simplicity",
    "competitiveAdvantage": "fastest time-to-value",
    "tagline": "Build faster. Ship smarter."
  },
  
  "messagingFramework": {
    "primary": {
      "headline": "Stop context-switching. Start shipping.",
      "subheadline": "The all-in-one platform for teams that move fast",
      "supportingPoints": ["..."]
    },
    "emotional": {
      "headline": "Remember why you started",
      "angle": "freedom from tool chaos"
    },
    "logical": {
      "headline": "40% less time in meetings",
      "angle": "ROI and efficiency"
    }
  },
  
  "channels": {
    "primary": ["LinkedIn", "Google Ads", "ProductHunt"],
    "secondary": ["Twitter", "tech newsletters", "podcasts"],
    "rationale": "Where startup founders spend time and trust recommendations"
  },
  
  "contentPillars": [
    {
      "pillar": "Productivity Tips",
      "topics": ["workflow optimization", "async communication", "focus techniques"],
      "format": ["short posts", "threads", "quick videos"]
    },
    {
      "pillar": "Startup Growth",
      "topics": ["scaling operations", "team efficiency", "tool consolidation"],
      "format": ["case studies", "interviews", "guides"]
    }
  ],
  
  "conversionFunnel": {
    "tofu": {
      "goal": "awareness",
      "content": ["educational blog posts", "industry reports"],
      "cta": "Learn More"
    },
    "mofu": {
      "goal": "consideration",
      "content": ["product comparisons", "feature deep-dives", "webinars"],
      "cta": "See How It Works"
    },
    "bofu": {
      "goal": "decision",
      "content": ["free trial", "demo", "ROI calculator"],
      "cta": "Start Free Trial"
    }
  }
}
```

## CTA Examples by Style

### Aggressive
- "Start Free Trial Now"
- "Claim Your Spot"
- "Don't Miss Out"
- "Get Started in 60 Seconds"

### Value-Focused
- "See How Much Time You'll Save"
- "Calculate Your ROI"
- "Discover the Difference"

### Educational
- "Learn How Top Teams Work"
- "See How It Works"
- "Explore Features"

### Social Proof
- "Join 10,000+ Teams"
- "See Why Teams Love Us"
- "Read Success Stories"

## Target Market Types

### B2B (Business to Business)
- Focus on ROI, efficiency, scalability
- Longer sales cycle, multiple stakeholders
- Case studies and demos important

### B2C (Business to Consumer)
- Focus on benefits, emotions, lifestyle
- Faster decisions, individual buyer
- Social proof and reviews important

### B2G (Business to Government)
- Focus on compliance, security, reliability
- Long procurement cycles
- Certifications and documentation important

### B2D (Business to Developer)
- Focus on technical excellence, DX
- Self-service, documentation-first
- Community and open source important
