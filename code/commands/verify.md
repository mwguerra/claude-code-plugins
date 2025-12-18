---
description: Run final verification checks for production readiness. Executes all tests, validates UI flows with Playwright, and checks the production checklist.
---

# Verify Command

Run comprehensive verification to confirm production readiness.

## Usage

```
/code:verify                   # Full verification
/code:verify --tests-only      # Only run test suites
/code:verify --playwright-only # Only run Playwright UI tests
/code:verify --checklist-only  # Only verify production checklist
```

## What This Command Does

This command runs all verification steps to confirm the application is production-ready. It's the final gate before deployment.

## Verification Steps

### Step 1: Test Suite Execution

Run all automated tests:

```bash
# PHP/Laravel
php artisan test

# JavaScript/Node
npm test

# Python
pytest
```

**Pass criteria**: ALL tests must pass (100% green)

### Step 2: Playwright UI Verification

Test all major user flows visually:

#### Authentication Flows
- [ ] Login page loads correctly
- [ ] Login with valid credentials works
- [ ] Login with invalid credentials shows error
- [ ] Logout works correctly
- [ ] Registration flow works (if applicable)
- [ ] Password reset flow works (if applicable)

#### Core Feature Flows
- [ ] Dashboard/home page loads
- [ ] Main navigation works
- [ ] CRUD operations work for key entities
- [ ] Forms validate correctly
- [ ] Data displays correctly

#### Admin Flows (if applicable)
- [ ] Admin dashboard loads
- [ ] User management works
- [ ] Settings pages work

#### Error Handling
- [ ] 404 page displays correctly
- [ ] Error messages are user-friendly
- [ ] Form validation errors display

### Step 3: Production Checklist

Verify each item:

#### Code Quality
- [ ] No debug statements in code
- [ ] No console.log() left behind
- [ ] No TODO comments for resolved issues
- [ ] No hardcoded development values

#### Tests
- [ ] All unit tests pass
- [ ] All feature tests pass
- [ ] All integration tests pass
- [ ] Test coverage is adequate

#### Security
- [ ] No secrets in codebase
- [ ] Environment variables documented
- [ ] CSRF protection enabled
- [ ] XSS protection in place
- [ ] SQL injection prevented
- [ ] Authentication secure
- [ ] Authorization policies complete

#### Performance
- [ ] Database queries optimized
- [ ] Caching configured
- [ ] Assets minified/optimized
- [ ] No N+1 query problems

#### Infrastructure
- [ ] Migrations up to date
- [ ] Seeders work correctly
- [ ] Queue workers documented
- [ ] Scheduled tasks documented
- [ ] Backup strategy defined

#### Documentation
- [ ] README is complete
- [ ] Installation steps documented
- [ ] Configuration documented
- [ ] API documentation (if applicable)

## Output Format

### Console Output

```
=== PRODUCTION VERIFICATION ===

[1/3] Running Test Suite...
  ✓ Unit tests: 45 passed
  ✓ Feature tests: 23 passed
  ✓ Integration tests: 8 passed
  Total: 76 passed, 0 failed

[2/3] Running Playwright Verification...
  ✓ Login flow
  ✓ Dashboard
  ✓ User CRUD
  ✓ Admin panel
  ✓ Error pages
  Total: 12 flows verified

[3/3] Checking Production Checklist...
  ✓ Code quality (5/5)
  ✓ Tests (4/4)
  ✓ Security (6/6)
  ⚠ Performance (3/4) - Review database queries
  ✓ Infrastructure (4/4)
  ✓ Documentation (3/3)

=== RESULT ===

Status: READY WITH NOTES

Notes:
- Performance: Some database queries could be optimized
  Location: app/Services/ReportService.php
  Recommendation: Add eager loading for user relationships

Verification completed at: [timestamp]
```

### Verification Report

If issues are found, generates detailed report:

```markdown
# Verification Report

## Summary
- Tests: PASS
- Playwright: PASS
- Checklist: PARTIAL

## Issues Requiring Attention

### Performance
1. N+1 query detected in ReportService
   - File: app/Services/ReportService.php:45
   - Impact: Slow page loads on reports
   - Fix: Add `with('user')` to query

## Recommendation
The application is ready for production with the noted performance optimization recommended but not blocking.
```

## Exit Codes (for CI/CD)

| Code | Meaning |
|------|---------|
| 0 | All checks passed - READY |
| 1 | Tests failed |
| 2 | Playwright verification failed |
| 3 | Critical checklist items failed |
| 4 | Warnings present but passable |

## Integration

This command is typically run:
1. After `/code:ready` to confirm all fixes worked
2. Before deployment as final gate
3. In CI/CD pipeline for automated checks

## Notes

- This command makes NO changes
- Run it as many times as needed
- Fix any failures before proceeding to production
- Document any acceptable warnings
