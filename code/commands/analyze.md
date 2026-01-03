---
description: Read-only analysis of codebase - discover features, check test coverage, identify issues, and generate report
allowed-tools: Read, Glob, Grep
argument-hint: "[--focus api|ui|tests] [--output path]"
---

# Analyze Command

Perform a read-only analysis of the application to assess production readiness.

## Usage

```
/code:analyze                  # Full analysis
/code:analyze --focus=api      # Focus on API endpoints
/code:analyze --focus=ui       # Focus on UI components
/code:analyze --focus=tests    # Focus on test coverage
/code:analyze --output=report  # Generate markdown report
```

## What This Command Does

This command analyzes without modifying any files. It provides a comprehensive report of:
- What exists
- What's missing
- What needs attention
- Estimated effort to reach production readiness

## Analysis Areas

### 1. Project Structure

Discover:
- Framework and version
- Directory organization
- Configuration files
- Environment setup

### 2. Feature Inventory

Map all components:

| Category | What to Find |
|----------|--------------|
| Routes | All defined routes (API + web) |
| Controllers | Handler classes and methods |
| Models | Database entities and relationships |
| Migrations | Schema definitions |
| Jobs | Queue and scheduled jobs |
| Commands | CLI commands |
| Components | UI components |
| Services | Business logic |
| Policies | Authorization rules |
| Middleware | Request handlers |
| Events | Event system |

### 3. Test Coverage Analysis

Evaluate testing:
- Existing test files
- Test to code ratio
- Untested components
- Test quality assessment

### 4. Code Quality

Check for:
- Debug statements left in code
- TODO/FIXME comments
- Deprecated function usage
- Security concerns (hardcoded secrets, SQL injection risks)
- Error handling gaps

### 5. Dependencies

Review:
- Package versions
- Outdated dependencies
- Security vulnerabilities
- Unused dependencies

### 6. Configuration

Verify:
- Environment variables usage
- Missing configuration
- Hardcoded values that should be configurable

### 7. Documentation

Check:
- README completeness
- API documentation
- Inline code comments
- Setup instructions

## Output Format

### Console Summary

```
=== Production Readiness Analysis ===

Project: [name]
Framework: [framework] v[version]
Analysis Date: [date]

FEATURES DISCOVERED:
  Routes:       42 (35 API, 7 web)
  Controllers:  15
  Models:       12
  Jobs:         5
  Commands:     3
  Components:   28

TEST COVERAGE:
  Test Files:   18
  Coverage:     ~45% (estimated)
  Missing:      Controllers (3), Models (4), Services (2)

ISSUES FOUND:
  Critical:     2
  High:         5
  Medium:       12
  Low:          8

ESTIMATED EFFORT:
  To production ready: Medium (2-3 days)

See detailed report for specifics.
```

### Detailed Report (--output=report)

Generates `ANALYSIS-REPORT.md` with:

```markdown
# Production Readiness Analysis Report

Generated: [timestamp]
Project: [name]

## Executive Summary
[High-level overview]

## Feature Inventory
### Routes
| Method | Path | Controller | Has Tests |
|--------|------|------------|-----------|
| GET | /api/users | UserController@index | Yes |
| POST | /api/users | UserController@store | No |
...

### Models
| Model | Relationships | Factory | Tests |
|-------|---------------|---------|-------|
| User | hasMany Posts | Yes | Partial |
...

## Test Coverage Analysis
[Detailed test coverage breakdown]

## Issues Found

### Critical
1. [Issue description]
   - Location: [file:line]
   - Impact: [description]
   - Recommended fix: [suggestion]

### High
...

## Recommendations
1. [Priority recommendation]
2. [Second recommendation]
...

## Next Steps
[Suggested action plan]
```

## Integration

This command can be followed by:
- `/code:ready` - To fix all issues
- `/taskmanager:plan` - To create tasks from findings
- `/test-specialist:generate-pest-test` - To create missing tests

## Notes

- This command makes NO changes to the codebase
- Safe to run at any time
- Provides input for planning phase
- Can be re-run to verify improvements
