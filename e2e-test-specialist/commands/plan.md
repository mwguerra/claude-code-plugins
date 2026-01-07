---
description: Create a detailed E2E test plan covering all pages, roles, and flows
allowed-tools: Skill(e2e-test-plan), Glob(*), Grep(*), Read(*), Write(*), Bash(php:*), Bash(ls:*), Bash(cat:*), Bash(grep:*), Bash(find:*)
argument-hint: [--output path/to/plan.md] [--force] [--quick]
---

# Create E2E Test Plan

Generate a comprehensive, browser-testable E2E test plan by deeply analyzing the Laravel Filament application. The plan documents all pages, user roles, critical flows, navigation coverage, and detailed test scenarios that can be executed step-by-step by a QA tester.

## Standard Plan Location

**Default location**: `docs/detailed-test-list.md`

The test plan is always saved to `docs/detailed-test-list.md` by default. This standard location allows all E2E testing commands to automatically find and use the plan. Other commands (test, pages, roles, flows) will look for the plan at this location and invoke this command first if the plan is missing.

## Plan Review and Update Mode

When an existing plan exists at `docs/detailed-test-list.md`, the command operates in **review and update mode**:

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
Use `--quick` flag to generate a basic plan without deep discovery commands.

## Usage

```bash
/e2e-test-specialist:plan                    # Updates existing or creates new plan
/e2e-test-specialist:plan --output custom.md # Saves to custom location
/e2e-test-specialist:plan --force            # Force complete regeneration
/e2e-test-specialist:plan --quick            # Quick basic plan (skip deep discovery)
```

## Process

### Phase 0: Check for Existing Plan

1. **Look for Existing Plan**
   - Check if `docs/detailed-test-list.md` exists
   - If exists and no `--force` flag: Enter **review and update mode**
   - If exists and `--force` flag: Skip to Phase 1 (full regeneration)
   - If doesn't exist: Skip to Phase 1 (create new plan)

2. **Review and Update Mode** (when plan exists)
   - Read existing plan content
   - Parse pages, roles, flows, and credentials
   - Proceed to validation and discovery steps
   - Merge new findings with existing plan
   - Preserve working test credentials

### Phase 1: Deep Discovery (Execute All Commands Systematically)

Execute these discovery commands to understand the complete application architecture:

#### 1.1 Database Architecture Analysis

```bash
# List all migrations in order
ls -la database/migrations/

# Examine each migration file
cat database/migrations/*.php
```

For each table, document:
- Table name and purpose
- Key columns and their types
- Foreign key relationships
- Soft deletes, timestamps, or special traits
- Pivot tables and many-to-many relationships

#### 1.2 Model & Relationship Mapping

```bash
# List all models
ls -la app/Models/

# Examine each model
cat app/Models/*.php
```

For each model, extract:
- Relationships (hasMany, belongsTo, belongsToMany, morphTo, etc.)
- Scopes (local and global)
- Accessors and mutators
- Casts and attributes
- Model events and observers
- Traits used (HasRoles, SoftDeletes, etc.)

#### 1.3 Authentication & Authorization System

```bash
# Check auth configuration
cat config/auth.php

# Check for Spatie Permission
cat config/permission.php 2>/dev/null

# Check policies
ls -la app/Policies/ 2>/dev/null
cat app/Policies/*.php 2>/dev/null

# Check for gates in providers
cat app/Providers/AuthServiceProvider.php 2>/dev/null

# Check middleware
ls -la app/Http/Middleware/
cat app/Http/Middleware/*.php 2>/dev/null

# Check for role/permission seeders
cat database/seeders/*.php
grep -A 50 "Role\|Permission" database/seeders/*.php 2>/dev/null
```

Document:
- Authentication methods (email/password, OAuth, 2FA, etc.)
- All roles in the system
- All permissions per role
- Policy rules per resource
- Custom middleware restrictions
- Guard configurations

#### 1.4 Filament Panel Configuration

```bash
# Check Filament providers/panels
cat app/Providers/Filament/*.php 2>/dev/null
ls -la app/Filament/

# Check panel configurations
find app -name "*PanelProvider*" -exec cat {} \; 2>/dev/null
```

Document:
- Number of panels (Admin, User, Tenant, etc.)
- Panel URLs and access rules
- Navigation structure
- Global search configuration
- Tenant/team configuration if multi-tenant

#### 1.5 Filament Resources Deep Dive

```bash
# List all Filament resources
find app/Filament -name "*Resource.php" | head -50

# Examine each resource
find app/Filament -name "*Resource.php" -exec cat {} \;
```

For each resource, extract:
- Associated model
- Form fields and validation rules
- Table columns and filters
- Actions (table actions, bulk actions, header actions)
- Relation managers
- Custom pages
- Authorization (canViewAny, canCreate, canEdit, canDelete, etc.)

#### 1.6 Filament Pages & Widgets

```bash
# List custom pages
find app/Filament -name "*Page*.php" -exec cat {} \; 2>/dev/null

# List widgets
find app/Filament -name "*Widget*.php" -exec cat {} \; 2>/dev/null

# List custom Livewire components
ls -la app/Livewire/ 2>/dev/null
cat app/Livewire/*.php 2>/dev/null
```

#### 1.7 Business Logic Layer

```bash
# Actions/Services
ls -la app/Actions/ 2>/dev/null
cat app/Actions/**/*.php 2>/dev/null

ls -la app/Services/ 2>/dev/null
cat app/Services/**/*.php 2>/dev/null

# Jobs
ls -la app/Jobs/ 2>/dev/null
cat app/Jobs/*.php 2>/dev/null

# Events and Listeners
ls -la app/Events/ 2>/dev/null
ls -la app/Listeners/ 2>/dev/null
cat app/Events/*.php 2>/dev/null
cat app/Listeners/*.php 2>/dev/null

# Notifications
ls -la app/Notifications/ 2>/dev/null
cat app/Notifications/*.php 2>/dev/null

# Mail
ls -la app/Mail/ 2>/dev/null
cat app/Mail/*.php 2>/dev/null
```

#### 1.8 Routes & API

```bash
# Web routes
cat routes/web.php

# API routes
cat routes/api.php 2>/dev/null

# Filament routes (auto-generated)
php artisan route:list --path=admin 2>/dev/null
php artisan route:list 2>/dev/null | head -100
```

#### 1.9 Subscription/Billing System (if applicable)

```bash
# Check for billing packages
cat composer.json | grep -i "cashier\|stripe\|paddle\|lemon"

# Check billing configuration
cat config/cashier.php 2>/dev/null

# Check subscription models/tables
grep -r "subscription\|plan\|billing" database/migrations/
grep -r "Billable\|subscription" app/Models/
```

#### 1.10 Multi-tenancy (if applicable)

```bash
# Check for tenancy packages
cat composer.json | grep -i "tenancy\|team\|organization"

# Check tenant configuration
cat config/tenancy.php 2>/dev/null

# Check tenant models
grep -r "Tenant\|Team\|Organization\|Workspace" app/Models/
```

#### 1.11 Navigation Audit (CRITICAL)

```bash
# Find all Filament navigation definitions
grep -r "NavigationItem\|navigationItems\|getNavigation\|menu" app/Filament/ --include="*.php"
grep -r "::make\|NavigationGroup\|navigationLabel\|navigationIcon" app/Filament/ --include="*.php" | head -100

# Find action buttons and links in resources
grep -r "Action::make\|Tables\\\\Actions\|->url(\|->link(" app/Filament/ --include="*.php" | head -50
```

### Phase 2: Synthesis

Based on Phase 1 analysis, synthesize:

#### 2.1 Application Purpose Statement
Write a 2-3 sentence summary of what this application does and the core value it provides.

#### 2.2 User Ecosystem Map
Create a detailed role matrix:

| User Type/Role | Access Level | Primary Use Cases | Key Permissions |
|---------------|--------------|-------------------|-----------------|
| Super Admin   | Full         | System config...  | Everything      |
| Admin         | High         | Manage users...   | CRUD users...   |
| User          | Standard     | Core features...  | Own resources   |
| Guest         | Limited      | View only...      | Read public     |

#### 2.3 Core User Journeys
Identify the 5-10 most important user flows that deliver the application's value.

#### 2.4 Entity Relationship Map
Document key models and their relationships.

### Phase 3: Generate Test Plan Document

Create `docs/detailed-test-list.md` with these required sections:

1. **Test Environment Setup** - Prerequisites, test users table, initial data state
2. **Section 0: Navigation & Link Coverage Audit** (CRITICAL - 100% coverage required)
3. **Authentication Tests** - Login, logout, registration, password reset, 2FA
4. **Per-Role Tests** - Each role's complete functionality
5. **CRUD Tests** - For each Filament resource
6. **Multi-User Flows** - Invitations, sharing, collaboration, permission handoffs
7. **Subscription/Plan Tests** - If applicable
8. **Edge Cases** - Validation errors, permission denials, concurrent edits
9. **Notification/Email Tests** - Verify emails sent at correct triggers

### Test Format (Required Structure)

Every test MUST follow this format:

```markdown
#### Test X.Y.Z: [Descriptive Name]
**Actor:** [User ID] ([Role])
**Preconditions:** [What must exist before test]

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | [Specific browser action] | [Observable outcome] |
| 2 | ... | ... |

**Postconditions:** [State after test completes]
```

### Critical Requirements

- Every step = ONE browser action
- Every action = explicit expected result
- Include exact URL paths where known
- Include exact text for validation messages
- Mark dependencies between tests (Test 3.2 requires Test 3.1)
- Include "negative" tests (what should NOT happen)
- **100% NAVIGATION COVERAGE**: Every menu item and internal link must be clicked at least once across all tests

## Output

Creates a detailed test plan document at `docs/detailed-test-list.md`:

```markdown
# [Application Name] - Detailed Test List

> Generated: [Date]
> Application Version: [Version]
> Based on analysis of: [Key files analyzed]

## Test Environment Setup

### Prerequisites
- [ ] Application deployed and accessible at: `[URL]`
- [ ] Database seeded with test data
- [ ] Email testing service configured
- [ ] Payment gateway in test mode (if applicable)

### Test User Accounts

| User ID | Email | Password | Role(s) | Plan | Notes |
|---------|-------|----------|---------|------|-------|
| U1 | admin@test.com | TestPass123! | Super Admin | - | Full access |
| U2 | owner@test.com | TestPass123! | Team Owner | Pro | Team owner |
| U3 | user@test.com | TestPass123! | Member | Free | Standard user |
| U4 | viewer@test.com | TestPass123! | Viewer | - | Read-only |

### Initial Data State

| Entity | Count | Key Records |
|--------|-------|-------------|
| Users | 4 | See above |
| Teams | 2 | "Acme Corp" (U2 owner), "Beta Inc" |
| [Resource] | X | [Description] |

---

## Section 0: Navigation & Link Coverage Audit

### 0.1 Complete Navigation Registry

#### 0.1.1 Sidebar Menu Items

| Menu Item | URL Path | Visible To | Tested In | Test Actor |
|-----------|----------|------------|-----------|------------|
| Dashboard | /admin | All roles | 1.1.1 | U1 |
| Users | /admin/users | Admin only | 5.1.1 | U1 |

#### 0.1.2 Resource Action Buttons

| Resource | Action | URL/Behavior | Tested In | Test Actor |
|----------|--------|--------------|-----------|------------|
| Projects | View | /admin/projects/{id} | 2.2.3 | U2 |

#### 0.1.3 Internal Cross-Reference Links

| Source Page | Link Text/Location | Destination | Tested In |
|-------------|-------------------|-------------|-----------|
| Task Detail | "Project: [Name]" | Project detail | 2.3.2 |

### 0.2 Full Menu Traversal Tests

[Full menu traversal tests for each role...]

### 0.3 Breadcrumb Navigation Tests

[Breadcrumb navigation tests...]

### 0.4 Coverage Verification Checklist

- [ ] Every row in table 0.1.1 has been executed
- [ ] Every row in table 0.1.2 has been executed
- [ ] All restricted URLs tested for each role (403 verification)

---

## Section 1: Authentication & Access Control

### 1.1 Login Flow
[Tests...]

---

## Section 2: [Primary User Role] - Core Functionality

### 2.1 Dashboard
[Tests...]

### 2.2 [Resource] Management
[CRUD tests...]

---

## Section 3: Multi-User Interaction Flows

### 3.1 Invitation & Onboarding
[Tests...]

### 3.2 Resource Sharing & Collaboration
[Tests...]

---

## Section 4: Subscription & Billing (if applicable)
[Tests...]

---

## Section 5: Admin Panel Functions
[Tests...]

---

## Section 6: Edge Cases & Error Handling
[Tests...]

---

## Section 7: Notifications & Emails
[Tests...]

---

## Appendix A: Test Data Reset Procedure
[Commands...]

## Appendix B: Known Issues / Skip Conditions
[Table...]
```

## Update Mode Output

When updating an existing plan, include a changes summary:

```markdown
# E2E Test Plan Update Report

## Changes Since Last Update

### New Pages Discovered
- /settings/notifications (Settings page)
- /admin/reports (Admin reports)

### Pages Removed/Deprecated
- /legacy/dashboard (Route no longer exists)

### New Flows Detected
- Notification Settings Flow
- Report Generation Flow

### Updated Roles
- moderator role: Added "manage_reports" permission

### Plan Updated
- Generated: [new date]
- Previous: [old date]
```

## Post-Generation Checklist

After generating the plan, verify:

1. [ ] Section 0 Navigation Audit is complete
2. [ ] Full menu traversal test exists for each role
3. [ ] All CRUD operations covered for each resource
4. [ ] All roles have specific test scenarios
5. [ ] Cross-user interactions included
6. [ ] Permission boundaries tested (including 403 verification)
7. [ ] Validation errors tested
8. [ ] Edge cases included
9. [ ] Subscription limits tested (if applicable)
10. [ ] Email/notification verification included
11. [ ] Breadcrumb navigation tested at least 3 levels deep
12. [ ] All relation manager tabs accessed

## Important

After generating the plan:
1. The plan is saved to `docs/detailed-test-list.md` (or custom path if specified)
2. The `docs/` directory is created if it doesn't exist
3. Other E2E commands will automatically read from this location
4. In update mode, existing test credentials are preserved if still valid
