---
description: Run comprehensive E2E tests with Playwright - test all pages, all roles, all flows in a visible browser
allowed-tools: Skill(e2e-test-plan), Skill(e2e-page-test), Skill(e2e-role-test), Skill(e2e-flow-test), Bash(npm:*), Bash(npx:*), mcp__playwright__*, Read(*), Glob(*)
argument-hint: <base-url> [--roles role1,role2] [--viewport desktop|tablet|mobile] [--headless]
---

# Comprehensive E2E Test

Run comprehensive end-to-end tests using Playwright MCP. This command tests all pages, all user roles, and all critical flows in a visible browser.

## Standard Test Plan Location

**Plan file**: `docs/detailed-test-list.md`

This command reads the test plan from `docs/detailed-test-list.md`. If the plan file doesn't exist, this command will automatically invoke the `/e2e-test-specialist:plan` command first to generate the plan before running tests.

## Usage

```bash
/e2e-test-specialist:test http://localhost:8000
/e2e-test-specialist:test http://localhost:3000 --roles admin,user,guest
/e2e-test-specialist:test http://localhost:8000 --viewport mobile
```

## Process

### Phase 0: Test Plan Verification (REQUIRED FIRST)

**CRITICAL**: Before any testing, check if the test plan exists.

1. **Check for Test Plan**
   - Look for `docs/detailed-test-list.md`
   - If the file exists, read and use it for test execution
   - If the file does NOT exist, invoke `Skill(e2e-test-plan)` to generate it first

2. **Plan Generation (if missing)**
   - Invoke the e2e-test-plan skill
   - Wait for plan to be saved to `docs/detailed-test-list.md`
   - Then proceed with Phase 1

### Phase 1: Discovery & Planning

1. **Read the Test Plan**
   - Read `docs/detailed-test-list.md`
   - Extract navigation registry from Section 0
   - Extract pages to test from the plan
   - Extract user roles from the plan
   - Extract critical flows from the plan

2. **Verify Plan Content**
   - Confirm navigation registry is complete
   - Confirm pages are listed
   - Confirm roles are defined with credentials
   - Confirm flows are documented
   - Set test priorities from plan

### Phase 1.5: Docker-Local Detection (For Laravel Projects)

**IMPORTANT**: For Laravel projects, check if docker-local is running before using localhost URLs.

1. **Check for docker-local**
   - Look for docker-local configuration files
   - Check if `.env` contains docker-local settings
   - Check if docker containers are running: `docker ps | grep docker-local`

2. **Use .test Domains**
   If docker-local is detected and running:
   - Use the `.test` domain instead of `localhost`
   - Check `.env` for `APP_URL` (e.g., `myapp.test`)
   - DO NOT spin up new servers with `php artisan serve`
   - docker-local already has everything running and configured

3. **Update Base URL**
   - If docker-local detected: Use `http://[project-name].test`
   - If not detected: Continue with provided localhost URL

### Phase 2: Environment Setup

1. **Verify Browser**
   - Check if Playwright browser is installed
   - Install if needed using `mcp__playwright__browser_install`

2. **Build Application Assets (IMPORTANT)**
   Missing assets cause most E2E test failures. Before testing:
   - Check for `package.json` in project root
   - Run `npm install` if `node_modules` is missing
   - Run `npm run build` to compile assets
   - For Vite projects: assets go to `dist/` or `build/`
   - For Laravel: run `npm run build` for frontend assets

   Common build commands:
   ```bash
   npm install && npm run build
   # or for development:
   npm run dev
   ```

3. **Check for Existing Sessions**
   - Use `mcp__playwright__browser_tabs` to check for running tests
   - Open new tab if needed
   - **IMPORTANT**: Wait at least 1 second between opening multiple tabs

4. **Set Viewport**
   - Use `mcp__playwright__browser_resize` for specified viewport
   - Default: Desktop (1920x1080)

### Phase 2.3: CSS/Tailwind Rendering Verification (CRITICAL)

**ALWAYS verify that CSS and styling are rendering correctly before proceeding.**

1. **Visual Rendering Check**
   After navigating to the first page:
   - Take a screenshot: `mcp__playwright__browser_take_screenshot`
   - Check if the page looks styled (not raw HTML)
   - Verify icons are displaying and sized correctly
   - Check that Tailwind classes are being applied

2. **CSS Issues Detection**
   Look for these signs of CSS problems:
   - Unstyled content (Times New Roman font, default link colors)
   - Icons not showing or showing as squares/placeholders
   - Missing background colors
   - Elements not positioned correctly
   - Mobile menu/navigation broken
   - Buttons without styling

3. **For Laravel Projects - Check Vite/Tailwind Config**
   If CSS is not rendering:
   - Check `vite.config.js` exists and is correct
   - Check `tailwind.config.js` content paths
   - Verify `resources/css/app.css` imports Tailwind
   - Check `package.json` has required dependencies
   - Run `npm install && npm run build`
   - Check `public/build/manifest.json` exists

4. **For Filament Projects - Check Custom Themes**
   If this is a Filament panel:
   - Check for custom theme at `resources/css/filament/[panel]/theme.css`
   - Verify theme is registered in Panel Provider
   - Check `tailwind.config.js` includes Filament content paths
   - Run `php artisan filament:assets` if needed
   - Verify Vite builds include Filament assets

5. **For Other Projects - Tailwind/CSS Verification**
   - Check build tool configuration (Vite, Webpack, etc.)
   - Verify CSS files are being loaded (check Network tab)
   - Check for PostCSS configuration if using Tailwind
   - Verify Tailwind content paths include all component files

6. **Fix and Retest**
   If CSS issues detected:
   - Identify the root cause
   - Apply the fix (config change, rebuild, etc.)
   - Clear browser cache if needed
   - Retest the page
   - Document the fix for future reference

### Phase 2.5: URL/Port Verification (CRITICAL FIRST TEST)

**IMPORTANT**: The server may not be running on the expected port. Always verify before testing.

1. **Navigate to Provided URL**
   - Use `mcp__playwright__browser_navigate` to base URL
   - Use `mcp__playwright__browser_snapshot` to capture state

2. **Verify Correct Application**
   Check the snapshot for indicators:
   - ✅ Expected application name/logo
   - ✅ Known navigation elements
   - ✅ Expected page structure
   - ❌ NOT default server pages ("Welcome to nginx!", "It works!")
   - ❌ NOT connection errors
   - ❌ NOT a different application

3. **Port Discovery (if verification fails)**
   Try common alternative ports in order:
   - 8000, 8080, 3000, 5173, 5174, 5000, 4200, 8888

   For each port:
   - Navigate to `http://localhost:{port}`
   - Take snapshot and check for expected application
   - If found, use this URL for all subsequent tests

4. **Check Project Configuration (if still not found)**
   Look for port settings in:
   - `.env` files (APP_PORT, PORT, VITE_PORT)
   - `package.json` scripts
   - `vite.config.js/ts`
   - `docker-compose.yml`

5. **Report and Proceed**
   - If URL differs from provided, warn user
   - Update base URL for all subsequent phases
   - If no working URL found, STOP and report error

### Phase 3: Page Testing

1. **Navigate to Each Page**
   - Use `mcp__playwright__browser_navigate`

2. **Verify Page Load**
   - Use `mcp__playwright__browser_snapshot`
   - Check for expected elements

3. **Check for Errors**
   - Use `mcp__playwright__browser_console_messages`
   - Use `mcp__playwright__browser_network_requests`

4. **Test Interactions**
   - Use `mcp__playwright__browser_click`
   - Use `mcp__playwright__browser_fill_form`

### Phase 4: Role-Based Testing

For each role:

1. **Login as Role**
   - Navigate to login
   - Fill credentials
   - Verify login success

2. **Test Accessible Pages**
   - Navigate to each page role should access
   - Verify proper access

3. **Test Blocked Pages**
   - Try accessing restricted pages
   - Verify proper blocking (403/redirect)

4. **Test Role-Specific Features**
   - Perform role-specific actions
   - Verify expected behavior

5. **Logout**
   - Logout and proceed to next role

### Phase 5: Flow Testing

For each critical flow:

1. **Execute Flow**
   - Perform each step in sequence
   - Verify state at each step

2. **Check Completion**
   - Verify flow completes successfully
   - Check data persistence

3. **Test Error Cases**
   - Test with invalid inputs
   - Verify error handling

### Phase 5.5: Error Detection and Resolution

**CRITICAL**: When errors are detected, solve them and retest.

1. **Error Detection During Testing**
   For each page/flow test:
   - Check for error pages (500, 404, 403 screens)
   - Check for error messages in the UI
   - Check console for JavaScript errors
   - Check network for failed requests

2. **Error Resolution Workflow**
   When an error is found:
   ```
   1. Take a screenshot of the error
   2. Document the error message
   3. Identify the root cause:
      - Check Laravel logs (storage/logs/laravel.log)
      - Check browser console
      - Check network requests
   4. Fix the error in the codebase
   5. Retest the page/flow
   6. Verify the fix worked
   7. Continue testing
   ```

3. **Remember Solutions for Recurring Errors**
   Track common errors and their solutions:
   - Store in memory during the session
   - If same error occurs again, apply known solution
   - Common patterns:
     - CSRF token mismatch → Clear session, refresh
     - 419 Page Expired → Regenerate CSRF token
     - 500 Server Error → Check logs, fix code
     - Missing route → Add route or fix URL
     - Permission denied → Check policies/gates

4. **Error Documentation**
   For each error found and fixed:
   - Note the error type and message
   - Document the root cause
   - Record the solution applied
   - Include in final test report

### Phase 5.6: Screenshot Capture (ALWAYS)

**ALWAYS take screenshots throughout testing.**

1. **When to Take Screenshots**
   - Initial page load (every page)
   - After each significant interaction
   - Before and after form submissions
   - When errors are detected
   - After successful flow completion
   - At different viewport sizes

2. **Screenshot Naming Convention**
   ```
   [phase]_[page/flow]_[state].png
   Examples:
   - page_home_initial.png
   - page_login_form_filled.png
   - flow_checkout_step3_payment.png
   - error_dashboard_500.png
   ```

3. **Screenshot Storage**
   - Store in `tests/screenshots/` directory
   - Organize by test run date/time
   - Include in test report

### Phase 6: Reporting

Generate comprehensive report with:
- All pages tested and results
- All roles tested and results
- All flows tested and results
- Errors found AND solutions applied
- Screenshots taken (with paths)
- Recommendations

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| base-url | Application URL to test | Required |
| --roles | Comma-separated list of roles | All discovered |
| --viewport | Screen size (desktop/tablet/mobile) | desktop |
| --headless | Run without visible browser | false |

## Viewport Sizes

| Viewport | Width | Height |
|----------|-------|--------|
| desktop | 1920 | 1080 |
| tablet | 768 | 1024 |
| mobile | 375 | 812 |

## Examples

### Full Test Suite
```bash
/e2e-test-specialist:test http://localhost:8000
```
Tests everything with default settings.

### Test Specific Roles
```bash
/e2e-test-specialist:test http://localhost:8000 --roles admin,user
```
Tests only admin and user roles.

### Mobile Testing
```bash
/e2e-test-specialist:test http://localhost:8000 --viewport mobile
```
Tests at mobile viewport size.

### Multiple Viewports
```bash
/e2e-test-specialist:test http://localhost:8000 --viewport desktop
/e2e-test-specialist:test http://localhost:8000 --viewport tablet
/e2e-test-specialist:test http://localhost:8000 --viewport mobile
```

## Output

The command produces:
1. Real-time test execution visible in browser
2. Comprehensive test report in markdown
3. List of errors found
4. Recommendations for fixes

## Notes

- **Sequential Testing**: E2E tests MUST run sequentially (one at a time), never in parallel. This prevents race conditions, state conflicts, and flaky results.
- **URL Verification First**: Always verifies the application is accessible at the provided URL before testing. If the server is on a different port, attempts to discover the correct port automatically.
- **Docker-Local Detection**: For Laravel projects, automatically detects if docker-local is running and uses `.test` domains instead of localhost. Never spins up `php artisan serve` if docker-local is available.
- **CSS/Tailwind Verification**: Always checks that CSS is rendering correctly before proceeding. Verifies icons, Tailwind classes, and overall styling.
- **Filament Theme Checks**: For Filament projects, verifies custom panel themes are loading correctly.
- **Error Resolution**: When errors are found, fixes them and retests. Remembers solutions for recurring errors during the session.
- **Always Screenshots**: Takes screenshots at every significant step - page loads, interactions, errors, flow completions.
- Always runs in a visible browser by default so you can watch tests
- Opens a new browser tab if other tests are running
- Takes snapshots at each step for debugging
- Checks console and network errors on every page
- Will stop immediately if the correct application cannot be found (prevents testing wrong app)
