---
description: Create a detailed E2E test plan covering all pages, roles, and flows
allowed-tools: Skill(e2e-test-plan), Glob(*), Grep(*), Read(*), Write(*)
argument-hint: [--output path/to/plan.md] [--force]
---

# Create E2E Test Plan

Generate a comprehensive E2E test plan by analyzing the codebase. The plan documents all pages, user roles, critical flows, and test scenarios.

## Standard Plan Location

**Default location**: `tests/e2e-test-plan.md`

The test plan is always saved to `tests/e2e-test-plan.md` by default. This standard location allows all E2E testing commands to automatically find and use the plan. Other commands (test, pages, roles, flows) will look for the plan at this location and invoke this command first if the plan is missing.

## Plan Review and Update Mode

When an existing plan exists at `tests/e2e-test-plan.md`, the command operates in **review and update mode**:

1. **Validate Existing Plan**
   - Check if documented pages still exist in the codebase
   - Verify routes are still valid
   - Check if roles are still defined
   - Ensure test credentials are still valid

2. **Discover New Content**
   - Scan for new pages/routes added since the plan was created
   - Identify new user roles or permissions
   - Detect new flows based on new features
   - Find new form fields or actions

3. **Update the Plan**
   - Add newly discovered pages to the inventory
   - Remove pages that no longer exist (mark as deprecated first)
   - Update roles if permissions changed
   - Add new critical flows
   - Update the "Generated" date
   - Keep test credentials that still work

4. **Report Changes**
   - List pages added
   - List pages removed/deprecated
   - List new flows discovered
   - Show what changed since last update

Use `--force` flag to completely regenerate the plan instead of updating.

## Usage

```bash
/e2e-test-specialist:plan                    # Updates existing or creates new plan
/e2e-test-specialist:plan --output custom.md # Saves to custom location
/e2e-test-specialist:plan --force            # Force complete regeneration
```

## Process

### Step 0: Check for Existing Plan

1. **Look for Existing Plan**
   - Check if `tests/e2e-test-plan.md` exists
   - If exists and no `--force` flag: Enter **review and update mode**
   - If exists and `--force` flag: Skip to Step 1 (full regeneration)
   - If doesn't exist: Skip to Step 1 (create new plan)

2. **Review and Update Mode** (when plan exists)
   - Read existing plan content
   - Parse pages, roles, flows, and credentials
   - Proceed to validation and discovery steps
   - Merge new findings with existing plan
   - Preserve working test credentials

### Step 1: Project Analysis

1. **Identify Framework**
   - Check package.json, composer.json
   - Determine routing mechanism
   - Note authentication system

2. **Discover Routes**
   - Find route definitions
   - Map URL patterns
   - Note middleware/guards

3. **Identify Roles**
   - Find role/permission definitions
   - Map role hierarchy
   - Note role-specific pages

### Step 2: Page Inventory

1. **List All Pages**
   - Public pages
   - Authenticated pages
   - Admin pages
   - Error pages

2. **Define Expected Elements**
   - Navigation
   - Main content
   - Forms
   - Actions

### Step 3: Flow Mapping

1. **Authentication Flows**
   - Login, logout, register
   - Password reset
   - Email verification

2. **Business Flows**
   - Core features
   - CRUD operations
   - Transactions

3. **Admin Flows**
   - User management
   - Settings
   - Reports

### Step 4: Generate Plan Document

Create markdown document with:
- Application overview
- Page inventory
- Role matrix
- Flow definitions
- Test scenarios
- Execution order

## Output

Creates a detailed test plan document:

```markdown
# E2E Test Plan

## Application Information
- Name: [app name]
- Framework: [framework]
- Base URL: [url]

## Pages to Test
[Table of all pages with routes, roles, and actions]

## User Roles
[Table of roles with permissions]

## Critical Flows
[Detailed flow definitions]

## Test Scenarios
[Test cases for each page/flow]

## Execution Order
[Prioritized test sequence]
```

## Examples

### Generate New Plan or Update Existing
```bash
/e2e-test-specialist:plan
```
If plan exists: Reviews and updates with new pages/flows.
If plan doesn't exist: Creates new plan at `tests/e2e-test-plan.md`.

### Save Plan to Custom Location
```bash
/e2e-test-specialist:plan --output docs/custom-plan.md
```

### Force Complete Regeneration
```bash
/e2e-test-specialist:plan --force
```
Ignores existing plan and creates a completely new one.

## Output (Update Mode)

When updating an existing plan, the output includes a changes summary:

```markdown
# E2E Test Plan Update Report

## Changes Since Last Update

### New Pages Discovered
- /settings/notifications (Settings page for notifications)
- /admin/reports (Admin reports dashboard)
- /api-docs (API documentation page)

### Pages Removed/Deprecated
- /legacy/dashboard (Route no longer exists)

### New Flows Detected
- Notification Settings Flow (new preferences management)
- Report Generation Flow (admin can generate reports)

### Updated Roles
- moderator role: Added new permission "manage_reports"

### Plan Updated
- Generated: [new date]
- Previous: [old date]
```

## Important

After generating the plan:
1. The plan is saved to `tests/e2e-test-plan.md` (or custom path if specified)
2. The `tests/` directory is created if it doesn't exist
3. Other E2E commands will automatically read from this location
4. In update mode, existing test credentials are preserved if still valid
