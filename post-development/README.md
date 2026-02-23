# Post-Development Plugin for Claude Code

A comprehensive post-development toolkit that automates the creation of marketing materials after your web application is built. Generate SEO optimization, automated screenshots, marketing personas, social media ads, showcase articles, and landing page specifications.

## Features

- **🔍 SEO Analysis** - Discover routes, analyze pages, generate sitemaps and meta tags
- **📸 Screenshot Capture** - Automated screenshots with Playwright across viewports and color modes
- **👥 Persona Generation** - Create detailed marketing personas with strategies and CTAs
- **📢 Ad Creation** - Generate social media ads for Instagram, Facebook, LinkedIn, Twitter
- **📝 Article Writing** - Create 3 showcase articles for different funnel stages
- **🎨 Landing Pages** - Design persona-specific landing page specifications

## Installation

### Via Claude Code Plugin Marketplace

```bash
/plugin marketplace add your-org/claude-plugins
/plugin install post-development@your-org
```

### Manual Installation

1. Clone or download this plugin
2. Add to your local marketplace:
```bash
/plugin marketplace add ./path/to/post-development
/plugin install post-development@local-marketplace
```

## Quick Start

### Initialize Post-Development

```bash
# In your project directory
/post-development:run init --base-url http://localhost:3000
```

This creates a `.post-development/` directory with configuration files.

### Run All Tasks

```bash
/post-development:run run
```

This executes all tasks in dependency order:
1. SEO analysis (parallel)
2. Screenshots (parallel)
3. Personas (depends on SEO)
4. Ads (depends on personas + screenshots)
5. Articles (depends on personas + SEO)
6. Landing pages (depends on all above)

### Check Status

```bash
/post-development:run status
```

## Commands

| Command | Description |
|---------|-------------|
| `/post-development:run init` | Initialize post-development structure |
| `/post-development:run run` | Run all tasks |
| `/post-development:run status` | Show task status |
| `/post-development:seo` | SEO analysis commands |
| `/post-development:screenshots` | Screenshot capture commands |
| `/post-development:personas` | Persona generation commands |
| `/post-development:ads` | Ad creation commands |
| `/post-development:articles` | Article writing commands |
| `/post-development:landing` | Landing page design commands |

## Output Structure

```
.post-development/
├── post-development.json     # Master plan
├── screenshot-plan.json      # Screenshot configuration
├── seo/
│   ├── seo-plan.json
│   ├── sitemap.xml
│   ├── meta-tags.html
│   ├── pages/               # Per-page analysis
│   └── assets/              # Favicon & OG image specs
├── screenshots/
│   ├── desktop/
│   │   ├── light/
│   │   └── dark/
│   ├── tablet/
│   └── mobile/
├── personas/
│   ├── personas/            # Individual persona files
│   ├── strategies/
│   └── cta/
├── ads/
│   ├── instagram/
│   ├── facebook/
│   ├── linkedin/
│   └── twitter/
├── articles/
│   ├── article-1/           # Problem-solution story
│   ├── article-2/           # Feature deep-dive
│   └── article-3/           # Case study
├── landing-pages/
│   └── {persona-id}/
│       ├── landing-page.json
│       ├── copy.md
│       └── wireframe.md
└── exports/                  # Exported marketing assets
```

## Requirements

- **Bun** - JavaScript runtime for scripts
- **Playwright** - For screenshot capture
- **Running application** - Your app must be running at the configured baseUrl

### Install Dependencies

```bash
cd /path/to/plugin
bun install
npx playwright install chromium
```

## Configuration

### Base URL

Set your application's URL:

```bash
/post-development:run init --base-url http://localhost:3000
```

### Screenshot Viewports

Default viewports:
- Desktop: 1920×1080
- Tablet: 768×1024
- Mobile: 375×812

### Color Modes

The plugin captures both light and dark modes by default. Configure in `screenshot-plan.json`.

## Agents

The plugin provides specialized agents for each task:

| Agent | Purpose |
|-------|---------|
| `post-dev-orchestrator` | Coordinates all tasks |
| `seo-analyst` | SEO analysis and optimization |
| `screenshot-planner` | Screenshot capture planning |
| `persona-strategist` | Marketing persona creation |
| `ad-creator` | Social media ad generation |
| `content-writer` | Article writing |
| `landing-designer` | Landing page design |

## Skills

The plugin includes a `post-development` skill that Claude uses automatically when relevant tasks are detected.

## Scripts

Run scripts directly with Bun:

```bash
bun run scripts/init.ts --base-url http://localhost:3000
bun run scripts/capture.ts
bun run scripts/seo-analyze.ts
bun run scripts/persona-create.ts
bun run scripts/ad-generate.ts
bun run scripts/article-write.ts
bun run scripts/landing-design.ts
```

## Task Dependencies

```
SEO ─────────┐
             ├──► Personas ──► Ads
Screenshots ─┘              │
                            ├──► Articles
             SEO ───────────┘
                            │
             All ───────────┴──► Landing Pages
```

## License

MIT

## Contributing

Contributions welcome! Please read the contributing guidelines first.
