---
description: Create a detailed E2E test plan covering all pages, roles, and flows
allowed-tools: Skill(e2e-test-plan), Glob(*), Grep(*), Read(*), Write(*)
argument-hint: [--output path/to/plan.md]
---

# Create E2E Test Plan

Generate a comprehensive E2E test plan by analyzing the codebase. The plan documents all pages, user roles, critical flows, and test scenarios.

## Standard Plan Location

**Default location**: `tests/e2e-test-plan.md`

The test plan is always saved to `tests/e2e-test-plan.md` by default. This standard location allows all E2E testing commands to automatically find and use the plan. Other commands (test, pages, roles, flows) will look for the plan at this location and invoke this command first if the plan is missing.

## Usage

```bash
/e2e-test-specialist:plan                    # Saves to tests/e2e-test-plan.md (default)
/e2e-test-specialist:plan --output custom.md # Saves to custom location
```

## Process

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

### Generate Plan (Default Location)
```bash
/e2e-test-specialist:plan
```
Saves the plan to `tests/e2e-test-plan.md`.

### Save Plan to Custom Location
```bash
/e2e-test-specialist:plan --output docs/custom-plan.md
```

## Important

After generating the plan:
1. The plan is saved to `tests/e2e-test-plan.md` (or custom path if specified)
2. The `tests/` directory is created if it doesn't exist
3. Other E2E commands will automatically read from this location
