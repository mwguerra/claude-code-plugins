---
description: Test complete user flows end-to-end (login, registration, checkout, etc.)
allowed-tools: Skill(e2e-flow-test), mcp__playwright__*
argument-hint: <base-url> [--flows login,register,checkout] [--role user]
---

# Test User Flows

Test complete user flows end-to-end using Playwright MCP. Executes multi-step journeys through the application.

## Usage

```bash
/e2e-test-specialist:flows http://localhost:8000
/e2e-test-specialist:flows http://localhost:8000 --flows login,register
/e2e-test-specialist:flows http://localhost:8000 --flows checkout --role user
```

## Process

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

### Step 3: Report Generation

Generate report with:
- Flows tested
- Steps completed
- Errors found
- Screenshots at each step

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
