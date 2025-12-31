---
description: Test all pages and flows for each user role, verifying proper access control
allowed-tools: Skill(e2e-test-plan), Skill(e2e-role-test), mcp__playwright__*, Read(*), Glob(*)
argument-hint: <base-url> [--roles admin,user,guest] [--credentials path/to/credentials.json]
---

# Role-Based Testing

Test all pages and flows for each user role using Playwright MCP. Verifies proper access control and role-specific functionality.

## Standard Test Plan Location

**Plan file**: `tests/e2e-test-plan.md`

This command reads the test plan from `tests/e2e-test-plan.md` to determine which roles to test and their credentials. If the plan file doesn't exist, this command will automatically invoke the `e2e-test-plan` skill first to generate the plan before running tests.

## Usage

```bash
/e2e-test-specialist:roles http://localhost:8000
/e2e-test-specialist:roles http://localhost:8000 --roles admin,user
/e2e-test-specialist:roles http://localhost:8000 --credentials test-users.json
```

## Process

### Step -1: Test Plan Verification (REQUIRED FIRST)

**CRITICAL**: Before testing any roles, check if the test plan exists.

1. **Check for Test Plan**
   - Look for `tests/e2e-test-plan.md`
   - If the file exists, read the role definitions and credentials from it
   - If the file does NOT exist, invoke `Skill(e2e-test-plan)` to generate it first

2. **Read Role Information from Plan**
   - Extract the "User Roles" section from the plan
   - Extract test credentials from the plan
   - Use role list for testing (unless `--roles` flag overrides)

### Step 0: URL/Port Verification (CRITICAL FIRST)

**Before testing any roles, verify the application is accessible at the correct URL.**

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

### Step 1: Role Discovery

1. **Identify All Roles**
   - Find role definitions in codebase
   - Map role hierarchy
   - Note role permissions

2. **Prepare Credentials**
   - Get test user for each role
   - Verify credentials work
   - Note login URLs

### Step 2: Guest Testing

1. **Test Public Pages**
   - Verify accessible pages load
   - Check content displays correctly

2. **Test Protected Pages**
   - Verify redirects to login
   - Check proper blocking

### Step 3: Authenticated Role Testing

For EACH role:

1. **Login**
   ```
   mcp__playwright__browser_navigate to /login
   mcp__playwright__browser_fill_form with credentials
   mcp__playwright__browser_click submit
   mcp__playwright__browser_wait_for success
   ```

2. **Test Accessible Pages**
   - Navigate to each page role should access
   - Verify content loads correctly

3. **Test Blocked Pages**
   - Try accessing restricted pages
   - Verify 403 or redirect

4. **Test Role Actions**
   - Perform role-specific actions
   - Verify correct behavior

5. **Logout**
   - Logout before next role

### Step 4: Security Tests

1. **Session Isolation**
   - Verify roles can't access each other's data

2. **Privilege Escalation**
   - Try admin actions as regular user
   - Verify blocked

### Step 5: Report Generation

Generate report with:
- Roles tested
- Pages accessible per role
- Pages correctly blocked
- Security test results

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| base-url | Application URL | Required |
| --roles | Roles to test | All discovered |
| --credentials | Credentials file | Interactive |

## Credentials File Format

```json
{
  "admin": {
    "email": "admin@example.com",
    "password": "adminpass"
  },
  "user": {
    "email": "user@example.com",
    "password": "userpass"
  }
}
```

## Output

```markdown
# Role-Based Test Results

## Summary
| Role | Pages OK | Pages Blocked | Issues |
|------|----------|---------------|--------|
| guest | 5/5 | 10/10 | 0 |
| user | 12/12 | 3/3 | 0 |
| admin | 15/15 | 0/0 | 0 |

## Details

### Guest Role
- [x] Can access public pages
- [x] Blocked from protected pages

### User Role
- [x] Can access user pages
- [x] Blocked from admin pages
- [x] Can perform user actions

### Admin Role
- [x] Full access to all pages
- [x] Can perform all actions
```

## Examples

### Test All Roles
```bash
/e2e-test-specialist:roles http://localhost:8000
```

### Test Specific Roles
```bash
/e2e-test-specialist:roles http://localhost:8000 --roles admin,user
```

### Use Credentials File
```bash
/e2e-test-specialist:roles http://localhost:8000 --credentials tests/users.json
```
