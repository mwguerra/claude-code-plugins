---
description: Capture screenshots of your app for marketing materials - supports multiple viewports and color modes
argument-hint: [init|capture|quick|status] [options]
allowed-tools: Bash, Read, Write, Glob
---

# Screenshot Capture Command

Capture screenshots of your application for marketing materials, documentation, and ads.

## Subcommands

### `init` - Initialize screenshot plan
```
/pd-screenshots init [--base-url http://localhost:3000]
```

### `capture` - Run screenshot capture
```
/pd-screenshots capture [--id specific-id] [--status pending] [--parallel]
```

### `quick` - Quick single-page capture
```
/pd-screenshots quick <url> [--viewport desktop|mobile] [--mode light|dark|both]
```

### `status` - View capture status
```
/pd-screenshots status [--verbose]
```

## Instructions

1. Parse subcommand from `$ARGUMENTS`
2. Load screenshot plan from `.post-development/screenshots/screenshot-plan.json`
3. Execute using Playwright scripts

### For `init`:

Create screenshot plan with routes discovered from project:
- Scan for public routes
- Generate entries for each route
- Configure viewports and color modes

### For `capture`:

Execute the capture plan:
```bash
bun run ${CLAUDE_PLUGIN_ROOT}/scripts/capture.ts $ARGUMENTS
```

### For `quick`:

Fast single-page capture:
```bash
bun run ${CLAUDE_PLUGIN_ROOT}/scripts/quick-capture.ts $ARGUMENTS
```

## Output Structure

```
.post-development/screenshots/
├── screenshot-plan.json    # Capture plan with status
├── desktop/
│   ├── light/
│   │   ├── 1_homepage_1.png
│   │   ├── 2_features_1.png
│   │   └── ...
│   └── dark/
│       └── ...
├── tablet/
│   ├── light/
│   └── dark/
├── mobile/
│   ├── light/
│   └── dark/
└── focused/                # Element-specific captures
    ├── hero-section.png
    ├── pricing-table.png
    └── ...
```

## Viewport Presets

| Preset | Dimensions | Scale | Use Case |
|--------|-----------|-------|----------|
| desktop | 1920×1080 | 1x | Website previews |
| desktop-hd | 2560×1440 | 2x | High-res marketing |
| laptop | 1366×768 | 1x | Common laptop |
| tablet | 768×1024 | 2x | iPad portrait |
| mobile | 375×812 | 3x | iPhone |

## Marketing-Focused Captures

For marketing materials, capture:

1. **Hero sections** - Above-the-fold content
2. **Key features** - Feature highlights
3. **Dashboard/Main UI** - Core app experience
4. **Social proof** - Testimonials, logos
5. **CTAs** - Call-to-action buttons

## File Naming Convention

```
{sequence}_{route}_{viewport}_{mode}_{index}.{format}
```

Example: `1_dashboard_desktop_light_1.png`

## Actions Before Capture

```json
{
  "actions": [
    { "type": "waitFor", "selector": ".content-loaded" },
    { "type": "fill", "selector": "input[name='demo']", "value": "Demo Data" },
    { "type": "click", "selector": ".show-features" },
    { "type": "wait", "ms": 1000 }
  ]
}
```

## Focus Areas

Capture specific sections for targeted marketing:

```json
{
  "focus": [
    { "selector": ".hero", "name": "hero", "padding": 40 },
    { "selector": ".features-grid", "name": "features", "padding": 20 },
    { "selector": ".testimonials", "name": "social-proof", "padding": 30 }
  ]
}
```

## Requirements

1. **Playwright**: `npm install -D playwright @playwright/test`
2. **Chromium**: `npx playwright install chromium`
3. **Running app**: Your app must be accessible at baseUrl
