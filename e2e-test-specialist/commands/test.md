---
description: Run comprehensive E2E tests with Playwright - test all pages, all roles, all flows in a visible browser
allowed-tools: Skill(e2e-test-plan), Skill(e2e-page-test), Skill(e2e-role-test), Skill(e2e-flow-test), Bash(npm:*), Bash(npx:*), mcp__playwright__*, Read(*), Glob(*)
argument-hint: <base-url> [--roles role1,role2] [--viewport desktop|tablet|mobile] [--headless]
---

# Comprehensive E2E Test

Run comprehensive end-to-end tests using Playwright MCP. This command tests all pages, all user roles, and all critical flows in a visible browser.

## Standard Test Plan Location

**Plan file**: `tests/e2e-test-plan.md`

This command reads the test plan from `tests/e2e-test-plan.md`. If the plan file doesn't exist, this command will automatically invoke the `/e2e-test-specialist:plan` command first to generate the plan before running tests.

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
   - Look for `tests/e2e-test-plan.md`
   - If the file exists, read and use it for test execution
   - If the file does NOT exist, invoke `Skill(e2e-test-plan)` to generate it first

2. **Plan Generation (if missing)**
   - Invoke the e2e-test-plan skill
   - Wait for plan to be saved to `tests/e2e-test-plan.md`
   - Then proceed with Phase 1

### Phase 1: Discovery & Planning

1. **Read the Test Plan**
   - Read `tests/e2e-test-plan.md`
   - Extract pages to test from the plan
   - Extract user roles from the plan
   - Extract critical flows from the plan

2. **Verify Plan Content**
   - Confirm pages are listed
   - Confirm roles are defined with credentials
   - Confirm flows are documented
   - Set test priorities from plan

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

### Phase 6: Reporting

Generate comprehensive report with:
- All pages tested and results
- All roles tested and results
- All flows tested and results
- Errors found
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
- Always runs in a visible browser by default so you can watch tests
- Opens a new browser tab if other tests are running
- Takes snapshots at each step for debugging
- Checks console and network errors on every page
- Will stop immediately if the correct application cannot be found (prevents testing wrong app)
