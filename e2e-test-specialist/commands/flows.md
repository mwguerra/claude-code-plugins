---
description: Test complete user flows end-to-end (login, registration, checkout, etc.)
allowed-tools: Skill(e2e-test-plan), Skill(e2e-flow-test), mcp__playwright__*, Read(*), Glob(*)
argument-hint: <base-url> [--flows login,register,checkout] [--role user]
---

# Test User Flows

Test complete user flows end-to-end using Playwright MCP. Executes multi-step journeys through the application.

## Standard Test Plan Location

**Plan file**: `tests/e2e-test-plan.md`

This command reads the test plan from `tests/e2e-test-plan.md` to determine which flows to test. If the plan file doesn't exist, this command will automatically invoke the `e2e-test-plan` skill first to generate the plan before running tests.

## Usage

```bash
/e2e-test-specialist:flows http://localhost:8000
/e2e-test-specialist:flows http://localhost:8000 --flows login,register
/e2e-test-specialist:flows http://localhost:8000 --flows checkout --role user
```

## Process

### Step -1: Test Plan Verification (REQUIRED FIRST)

**CRITICAL**: Before testing any flows, check if the test plan exists.

1. **Check for Test Plan**
   - Look for `tests/e2e-test-plan.md`
   - If the file exists, read the flow definitions from it
   - If the file does NOT exist, invoke `Skill(e2e-test-plan)` to generate it first

2. **Read Flow Definitions from Plan**
   - Extract the "Critical Flows" section from the plan
   - Use flow list for testing (unless `--flows` flag overrides)

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

**Before testing any flows, verify the application is accessible at the correct URL.**

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

**ALWAYS verify CSS and styling before testing flows.**

1. **Visual Check**
   - Take screenshot of entry point page
   - Verify page is styled (not raw HTML)
   - Check icons are displaying correctly

2. **Framework-Specific Checks**
   - **Laravel**: Check vite.config.js, tailwind.config.js
   - **Filament**: Check custom panel themes
   - Run `npm run build` if needed

### Step 1: Flow Discovery

1. **Identify Critical Flows**
   - Authentication flows
   - Core business flows
   - Administrative flows

2. **Map Flow Steps**
   - Entry points
   - Required actions
   - Expected outcomes

### Step 2: Flow Execution

For EACH flow:

1. **Setup**
   - Clear previous state if needed
   - Login if required
   - Navigate to entry point

2. **Execute Steps**
   ```
   For each step:
     mcp__playwright__browser_navigate or click
     mcp__playwright__browser_fill_form if needed
     mcp__playwright__browser_click to proceed
     mcp__playwright__browser_snapshot to verify
   ```

3. **Verify Completion**
   - Check final state
   - Verify data persisted
   - Check side effects

4. **Test Error Cases**
   - Invalid inputs
   - Missing data
   - Error recovery

### Step 2.5: Error Detection and Resolution

**When errors are found, fix them and retest.**

1. **Error Detection**
   At each flow step:
   - Check for error pages (500, 404, 403)
   - Check for error messages in UI
   - Check browser console
   - Check network requests

2. **Error Resolution**
   When error found:
   - Take screenshot of error
   - Identify root cause
   - Fix the error
   - Retest the flow step
   - Document the solution

3. **Remember Solutions**
   - Track errors and solutions during session
   - Apply known solutions to recurring errors
   - If same error occurs in different flow, use known fix

### Step 2.7: Screenshot Capture (ALWAYS)

**Take screenshots at every flow step.**

1. **When to Screenshot**
   - Flow entry point
   - After each step completion
   - Form fill states
   - Confirmation pages
   - Error states
   - Flow completion

2. **Storage**
   - Save to `tests/screenshots/flows/`
   - Use naming: `flow_[flowname]_step[N]_[status].png`

### Step 3: Report Generation

Generate report with:
- Flows tested
- Steps completed
- Errors found AND solutions applied
- Screenshots at each step (with paths)

## Common Flows

### Authentication
- Login
- Logout
- Registration
- Password Reset
- Email Verification

### User Management
- Profile View
- Profile Edit
- Settings Change
- Account Deletion

### E-commerce
- Browse Products
- Add to Cart
- Checkout
- Order History

### Content
- Create Post
- Edit Post
- Delete Post
- Comment

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| base-url | Application URL | Required |
| --flows | Specific flows to test | All discovered |
| --role | Role to test as | All roles |

## Output

```markdown
# Flow Test Results

## Summary
- Flows Tested: 8
- Passed: 7
- Failed: 1

## Results

### Login Flow - PASSED
| Step | Action | Status |
|------|--------|--------|
| 1 | Navigate to /login | OK |
| 2 | Fill credentials | OK |
| 3 | Submit | OK |
| 4 | Verify dashboard | OK |

### Checkout Flow - FAILED
| Step | Action | Status |
|------|--------|--------|
| 1 | Add to cart | OK |
| 2 | View cart | OK |
| 3 | Checkout | OK |
| 4 | Payment | FAILED |
| 5 | Confirmation | SKIPPED |

Error: Payment gateway timeout
```

## Examples

### Test All Flows
```bash
/e2e-test-specialist:flows http://localhost:8000
```

### Test Specific Flows
```bash
/e2e-test-specialist:flows http://localhost:8000 --flows login,register
```

### Test as Specific Role
```bash
/e2e-test-specialist:flows http://localhost:8000 --flows checkout --role user
```
