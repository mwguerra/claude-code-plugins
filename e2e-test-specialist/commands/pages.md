---
description: Test all pages for errors, missing elements, and broken interactions
allowed-tools: Skill(e2e-page-test), mcp__playwright__*
argument-hint: <base-url> [--pages /path1,/path2] [--viewport desktop|tablet|mobile]
---

# Test All Pages

Systematically test all pages in the application for errors, missing elements, and broken interactions using Playwright MCP.

## Usage

```bash
/e2e-test-specialist:pages http://localhost:8000
/e2e-test-specialist:pages http://localhost:8000 --pages /login,/dashboard,/profile
/e2e-test-specialist:pages http://localhost:8000 --viewport mobile
```

## Process

### Step 0: URL/Port Verification (CRITICAL FIRST)

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

### Step 4: Report Generation

Generate report with:
- Pages tested
- Pass/fail status
- Errors found
- Screenshots if needed

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
