---
description: Test all pages for errors, missing elements, and broken interactions
allowed-tools: Skill(test-plan), Skill(page-test), mcp__playwright__*, Read(*), Glob(*)
argument-hint: <base-url> [--pages /path1,/path2] [--viewport desktop|tablet|mobile]
---

# Test All Pages

Systematically test all pages in the application for errors, missing elements, and broken interactions using Playwright MCP.

## Standard Test Plan Location

**Plan file**: `docs/detailed-test-list.md`

This command reads the test plan from `docs/detailed-test-list.md` to determine which pages to test. If the plan file doesn't exist, this command will automatically invoke the `test-plan` skill first to generate the plan before running tests.

## Usage

```bash
/e2e-test-specialist:pages http://localhost:8000
/e2e-test-specialist:pages http://localhost:8000 --pages /login,/dashboard,/profile
/e2e-test-specialist:pages http://localhost:8000 --viewport mobile
```

## Process

### Step -1: Test Plan Verification (REQUIRED FIRST)

**CRITICAL**: Before testing any pages, check if the test plan exists.

1. **Check for Test Plan**
   - Look for `docs/detailed-test-list.md`
   - If the file exists, read the page inventory from it
   - If the file does NOT exist, invoke `Skill(test-plan)` to generate it first

2. **Read Page List from Plan**
   - Extract the navigation registry from Section 0
   - Extract pages from test sections
   - Use page list for testing (unless `--pages` flag overrides)

### Step 0: Docker-Local Detection (For Laravel Projects)

**IMPORTANT**: For Laravel projects, check if docker-local is running.

1. **Check for docker-local**
   - Look for docker-local configuration
   - Check if `.env` contains docker-local settings (APP_URL with .test domain)
   - Check if docker containers are running

2. **Use .test Domains**
   If docker-local is detected and running:
   - Use the `.test` domain from APP_URL
   - DO NOT use `php artisan serve`
   - docker-local already has the server configured

### Step 0.5: URL/Port Verification (CRITICAL FIRST)

**Before testing any pages, verify the application is accessible at the correct URL.**

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

### Step 0.7: CSS/Tailwind Rendering Verification

**ALWAYS verify CSS and styling before testing pages.**

1. **Visual Check**
   - Take screenshot of first page
   - Verify page is styled (not raw HTML)
   - Check icons are displaying correctly
   - Verify Tailwind classes are applied

2. **CSS Issues Detection**
   Look for:
   - Unstyled content
   - Missing icons or icon placeholders
   - Broken layouts
   - Missing background colors

3. **Framework-Specific Checks**
   - **Laravel**: Check vite.config.js, tailwind.config.js, run `npm run build`
   - **Filament**: Check custom theme, run `php artisan filament:assets`
   - **Other**: Verify CSS build configuration

4. **Fix and Retest**
   If CSS issues found:
   - Fix the configuration
   - Rebuild assets
   - Retest before proceeding

### Step 1: Page Discovery

1. **Identify All Pages**
   - Analyze route definitions
   - Map all accessible URLs
   - Note authentication requirements

2. **Categorize Pages**
   - Public pages
   - Authenticated pages
   - Admin pages

### Step 2: Page Testing

For EACH page:

1. **Navigate to Page**
   ```
   mcp__playwright__browser_navigate to URL
   ```

2. **Verify Page Loads**
   ```
   mcp__playwright__browser_snapshot to capture state
   Check for expected elements
   ```

3. **Check for Errors**
   ```
   mcp__playwright__browser_console_messages for JS errors
   mcp__playwright__browser_network_requests for failed requests
   ```

4. **Test Interactions**
   ```
   mcp__playwright__browser_click on buttons/links
   mcp__playwright__browser_fill_form on forms
   Verify actions work correctly
   ```

### Step 3: Responsive Testing

If viewport specified:
1. Resize browser to viewport size
2. Test each page at that size
3. Verify layout adapts correctly

### Step 3.5: Error Detection and Resolution

**When errors are found, fix them and retest.**

1. **Error Detection**
   For each page:
   - Check for error pages (500, 404, 403)
   - Check for error messages in UI
   - Check browser console
   - Check network requests

2. **Error Resolution**
   When error found:
   - Take screenshot of error
   - Identify root cause
   - Fix the error
   - Retest the page
   - Document the solution

3. **Remember Solutions**
   - Track errors and solutions during session
   - Apply known solutions to recurring errors

### Step 3.7: Screenshot Capture (ALWAYS)

**Take screenshots at every step.**

1. **When to Screenshot**
   - Every page initial load
   - After interactions
   - When errors found
   - At different viewports

2. **Storage**
   - Save to `tests/screenshots/`
   - Use descriptive names

### Step 4: Report Generation

Generate report with:
- Pages tested
- Pass/fail status
- Errors found AND solutions applied
- Screenshots taken (with paths)

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| base-url | Application URL | Required |
| --pages | Specific pages to test | All pages |
| --viewport | Screen size | desktop |

## Output

```markdown
# Page Test Results

## Summary
- Pages Tested: 25
- Passed: 23
- Failed: 2

## Results

### Passed Pages
- / (Home) - OK
- /about - OK
- /login - OK
...

### Failed Pages
- /dashboard - Console error: "undefined is not a function"
- /settings - 404 on /api/settings
```

## Examples

### Test All Pages
```bash
/e2e-test-specialist:pages http://localhost:8000
```

### Test Specific Pages
```bash
/e2e-test-specialist:pages http://localhost:8000 --pages /,/login,/dashboard
```

### Test Mobile Layout
```bash
/e2e-test-specialist:pages http://localhost:8000 --viewport mobile
```
