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

### Step 0: URL/Port Verification (CRITICAL FIRST)

**Before capturing any screenshots, verify the application is accessible at the correct URL.**

1. **Navigate to Provided URL**
   - Use `mcp__playwright__browser_navigate` to base URL
   - Use `mcp__playwright__browser_snapshot` to capture state

2. **Verify Correct Application**
   - Check for expected app name/logo/navigation
   - Ensure NOT a default server page ("Welcome to nginx!", "It works!")
   - Ensure NOT a connection error page

3. **Port Discovery (if verification fails)**
   Try common ports: 8000, 8080, 3000, 5173, 5174, 5000, 4200

4. **Proceed or Stop**
   - If correct URL found: Update base URL and continue
   - If no working URL found: **STOP** and report error

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
