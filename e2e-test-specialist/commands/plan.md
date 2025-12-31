---
description: Create a detailed E2E test plan covering all pages, roles, and flows
allowed-tools: Skill(e2e-test-plan), Glob(*), Grep(*), Read(*)
argument-hint: [--output path/to/plan.md]
---

# Create E2E Test Plan

Generate a comprehensive E2E test plan by analyzing the codebase. The plan documents all pages, user roles, critical flows, and test scenarios.

## Usage

```bash
/e2e-test-specialist:plan
/e2e-test-specialist:plan --output docs/test-plan.md
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

### Generate Plan to Console
```bash
/e2e-test-specialist:plan
```

### Save Plan to File
```bash
/e2e-test-specialist:plan --output tests/e2e-plan.md
```
