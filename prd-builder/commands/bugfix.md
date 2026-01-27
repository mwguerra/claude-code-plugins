---
name: bugfix
description: Document a bug fix with problem analysis, root cause investigation, and regression testing strategy
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - Bash
  - Task
  - Skill
argument-hint: "[bug description or issue reference]"
---

# Bug Fix Documentation Command

Create focused documentation for bug fixes with emphasis on problem analysis, root cause, and preventing regression.

## Bug Fix PRD Structure

Unlike product/feature PRDs, bug fix documentation focuses on:
1. Problem reproduction
2. Root cause analysis
3. Fix approach
4. Regression prevention

## Execution Flow

### 1. Initialize Session

```bash
cat .taskmanager/prd-state.json 2>/dev/null
```

### 2. Capture Bug Description

If argument provided, use it. Otherwise ask:

"Describe the bug you're fixing. Include any error messages, reproduction steps, or issue references."

### 3. Generate Slug

Create slug from bug description:
- Example: "Login fails with special characters" → `login-special-chars-fix`
- Example: "Dashboard timeout on large datasets" → `dashboard-timeout-fix`

### 4. Create State File

```json
{
  "sessionId": "<uuid>",
  "prdType": "bugfix",
  "slug": "<generated-slug>",
  "startedAt": "<ISO timestamp>",
  "lastUpdatedAt": "<ISO timestamp>",
  "currentCategory": "problem-context",
  "completedCategories": [],
  "answers": {},
  "initialPrompt": "<user's description>"
}
```

### 5. Conduct Bug Analysis Interview

Load `prd-interview` skill. Focus on problem-solving categories:

**1. Problem & Context (2 rounds) - CRITICAL**

Round 1 - Symptoms:
- What is the exact error or unexpected behavior?
- When was this first reported?
- How frequently does it occur?
- What's the severity/impact?

Round 2 - Reproduction:
- What are the exact steps to reproduce?
- What environment/conditions trigger it?
- Does it happen consistently or intermittently?
- Any recent changes that might be related?

**2. Users & Customers (1 round)**
- Who is affected?
- How many users impacted?
- Any workarounds they're using?

**3. Technical Implementation (2 rounds) - CRITICAL**

Round 1 - Root Cause:
- What component/file is responsible?
- What's the suspected root cause?
- Any related code or dependencies?

Round 2 - Fix Approach:
- What's the proposed fix?
- Are there alternative approaches?
- What's the risk of the fix introducing new issues?
- Any breaking changes?

**4. Risks & Concerns (1 round)**
- Could the fix affect other features?
- Are there edge cases to consider?
- Dependencies on other fixes or releases?

**5. Testing & Quality (2 rounds) - CRITICAL**

Round 1 - Verification:
- How to verify the fix works?
- What are the acceptance criteria?
- Specific test cases needed?

Round 2 - Regression:
- What regression tests are needed?
- Should this become a permanent test case?
- Any related areas to test?

**Skip or Minimize:**
- Business & Value (not applicable)
- UX & Design (minimal, only if UI-related bug)
- Solution & Features (bug fix, not new feature)

### 6. Generate Bug Fix Document

Create bug-focused document with sections:

```markdown
# Bug Fix: {Bug Title}

## Summary
- **Severity**: Critical/High/Medium/Low
- **Reported**: {Date}
- **Fixed**: {Date}
- **Affected Versions**: {versions}

## Problem Description
{Detailed description of the bug}

## Reproduction Steps
1. {Step 1}
2. {Step 2}
3. {Step 3}

## Expected vs Actual Behavior
- **Expected**: {what should happen}
- **Actual**: {what actually happens}

## Root Cause Analysis
{Technical explanation of why the bug occurs}

## Fix Implementation
{Description of the fix approach}

### Files Changed
- `path/to/file.php` - {what changed}

### Code Changes
{Key code snippets if helpful}

## Testing Strategy

### Verification Tests
- [ ] {Test that fix works}

### Regression Tests
- [ ] {Test that nothing else broke}

## Rollback Plan
{How to revert if issues found}

## Related Issues
- {Links to related bugs or issues}
```

Save to: `docs/prd/prd-{slug}.md`

### 7. TaskManager Integration

Offer to create fix tasks:
- Implement fix
- Write tests
- Code review
- Deploy and verify

## Interview Guidelines

- 3-5 question rounds total
- Heavy focus on reproduction and root cause
- Technical depth is critical
- Testing strategy is mandatory
- Skip business/UX unless directly relevant

## Output

- Bug fix document: `docs/prd/prd-{slug}.md`
- Focused on problem → cause → fix → verify
- Ready for implementation tracking
