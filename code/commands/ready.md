---
description: Comprehensive production readiness audit. Analyzes all features, tests with Pest and Playwright, fixes issues, and ensures the app is spotless and production-ready. Uses taskmanager for task tracking.
---

# Production Ready Command

Prepare this application for production deployment through comprehensive analysis, testing, and verification.

## Usage

```
/code:ready                    # Full production readiness audit
/code:ready --skip-playwright  # Skip Playwright UI testing
/code:ready --skip-fixes       # Analyze and test only, don't fix
/code:ready --focus=auth       # Focus on specific feature/area
```

## What This Command Does

### Phase 1: Safety Commit

Before doing anything, ensure no work is lost:

1. Run `git status` to check for uncommitted changes
2. If changes exist, commit them:
   ```bash
   git add -A
   git commit -m "chore: save work before production readiness audit"
   git push
   ```

### Phase 2: Comprehensive Analysis

Discover and inventory the entire application:

1. **Project Structure**
   - Identify framework (Laravel, React, Vue, Next.js, etc.)
   - Map directory structure
   - Find configuration files

2. **Feature Inventory**
   - Routes (API and web)
   - Controllers and request handlers
   - Models and database schema
   - Jobs and scheduled tasks
   - CLI commands
   - UI components
   - Services and business logic
   - Policies and middleware
   - Events and listeners

3. **Dependency Check**
   - Review package.json / composer.json
   - Check for outdated dependencies
   - Note security vulnerabilities

### Phase 3: TaskManager Integration

Create structured task tracking:

1. Initialize taskmanager if not present (`/taskmanager:init`)
2. Create comprehensive task plan with all discovered work
3. Structure tasks by phase:
   - Analysis tasks
   - Testing tasks (Pest + Playwright)
   - Fix tasks
   - Verification tasks

### Phase 4: Pest Testing

For PHP/Laravel applications:

1. Run existing test suite:
   ```bash
   php artisan test
   ```

2. Analyze coverage and identify gaps

3. Create missing tests for:
   - Untested controllers
   - Untested models
   - Untested services
   - Untested policies
   - Edge cases

4. Ensure all tests pass

### Phase 5: Playwright UI Testing

For each user-facing page and flow:

1. Navigate to the page using `browser_navigate`
2. Capture accessibility snapshot using `browser_snapshot`
3. Verify all expected elements are present
4. Test interactions (clicks, form submissions)
5. Validate complete user flows:
   - Authentication (login, logout, register)
   - CRUD operations
   - Admin features
   - Error handling

### Phase 6: Issue Resolution

For each issue found:

1. Categorize by priority (Critical, High, Medium, Low)
2. Create a taskmanager task
3. Implement the fix
4. Write/update tests for the fix
5. Commit:
   ```bash
   git add -A
   git commit -m "fix: [description]"
   git push
   ```

### Phase 7: Final Verification

1. Run complete Pest test suite
2. Re-run all Playwright flows
3. Verify production checklist:
   - [ ] All tests passing
   - [ ] No console errors
   - [ ] No PHP errors/warnings
   - [ ] Migrations up to date
   - [ ] Environment documented
   - [ ] Caching configured
   - [ ] Queue workers configured
   - [ ] Error logging configured
   - [ ] Security headers in place

### Phase 8: Final Report

Generate summary:

```markdown
## Production Readiness Report

### Statistics
- Features analyzed: X
- Tests added: X
- Issues found: X
- Issues resolved: X

### Test Results
- Pest: X passed, X failed
- Playwright flows: X validated

### Status
[READY / READY WITH NOTES / NOT READY]

### Remaining Issues (if any)
1. [Description] - Priority: [X]

### Recommendations
- [List]
```

## Commit Strategy

| Phase | Commit Message |
|-------|----------------|
| Start | `chore: save work before production readiness audit` |
| After analysis | `docs: complete feature inventory` |
| After tests | `test: add tests for [component]` |
| After fixes | `fix: [description]` |
| Final | `chore: production readiness audit complete` |

## Integration

This command works with:
- **taskmanager** - For task tracking
- **test-specialist** - For Pest test generation
- **Playwright MCP** - For UI testing

## Expected Outcome

At completion:
- All features analyzed and documented
- Comprehensive test coverage
- All issues fixed or documented
- Production checklist verified
- Clean commit history
- Ready for deployment
