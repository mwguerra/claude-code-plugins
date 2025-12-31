---
description: Capture screenshots of all pages at different viewports
allowed-tools: mcp__playwright__*
argument-hint: <base-url> [--output screenshots/] [--viewports desktop,tablet,mobile]
---

# Capture Page Screenshots

Capture screenshots of all pages at different viewport sizes using Playwright MCP.

## Usage

```bash
/e2e-test-specialist:screenshot http://localhost:8000
/e2e-test-specialist:screenshot http://localhost:8000 --output docs/screenshots
/e2e-test-specialist:screenshot http://localhost:8000 --viewports desktop,mobile
```

## Process

### Step 1: Setup

1. **Prepare Output Directory**
   - Create screenshots folder
   - Organize by viewport/page

2. **Configure Viewports**
   - Desktop: 1920x1080
   - Tablet: 768x1024
   - Mobile: 375x812

### Step 2: Screenshot Capture

For EACH page and viewport:

1. **Resize Browser**
   ```
   mcp__playwright__browser_resize({ width, height })
   ```

2. **Navigate to Page**
   ```
   mcp__playwright__browser_navigate({ url })
   ```

3. **Wait for Load**
   ```
   mcp__playwright__browser_wait_for({ time: 2 })
   ```

4. **Capture Screenshot**
   ```
   mcp__playwright__browser_take_screenshot({
     filename: "page-viewport.png",
     fullPage: true
   })
   ```

### Step 3: Report Generation

Create index with all screenshots.

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| base-url | Application URL | Required |
| --output | Output directory | ./screenshots |
| --viewports | Viewport sizes | all |
| --full-page | Capture full page | true |

## Viewport Sizes

| Name | Width | Height |
|------|-------|--------|
| desktop | 1920 | 1080 |
| tablet | 768 | 1024 |
| mobile | 375 | 812 |

## Output Structure

```
screenshots/
├── desktop/
│   ├── home.png
│   ├── login.png
│   ├── dashboard.png
│   └── ...
├── tablet/
│   ├── home.png
│   ├── login.png
│   └── ...
├── mobile/
│   ├── home.png
│   ├── login.png
│   └── ...
└── index.html
```

## Examples

### All Viewports
```bash
/e2e-test-specialist:screenshot http://localhost:8000
```

### Specific Viewports
```bash
/e2e-test-specialist:screenshot http://localhost:8000 --viewports desktop,mobile
```

### Custom Output
```bash
/e2e-test-specialist:screenshot http://localhost:8000 --output docs/images
```
