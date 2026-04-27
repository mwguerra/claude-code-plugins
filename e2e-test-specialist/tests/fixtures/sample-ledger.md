# Sample E2E Ledger (CI fixture)

## Directives

### Sample Blocking Directive
- **Enforcement**: blocking
- This is a sample directive used by CI to verify directive import.

## VPS Infrastructure & Credentials

### Worker 1 — App Server
- **Hostname**: w1.example.test
- **IP**: 10.0.0.1
- **SSH Port**: 22

### Sample API Token
- **Token**: ghp_SAMPLE0000000000000000000000000000

## Test App Matrix (1 app)

| App ID  | Name        | Repo                        | Domain               |
|---------|-------------|-----------------------------|----------------------|
| APP-001 | sample-todo | mwguerra/sample-todo        | todo.example.test    |

## E2E Test Phases

### Phase 0: Clean Slate
- Verify VPS in known-good state.

**0.1 SSH reachable**
1. SSH to w1.example.test on port 22
2. Confirm `uname -a` returns Linux

### Phase 1: Site Creation
- Create one site for the sample app.

**1.1 Create site via panel**
1. Navigate to https://panel.example.test/admin/sites/create
2. Fill form for APP-001
3. Click "Create"
4. Verify site row appears

**1.2 Verify site is reachable**
1. Navigate to https://todo.example.test
2. Confirm 200 response

## Test Results Log

### 2026-04-26 — R-001 — First sample run
- All steps passed.

## Test Count Summary

| Phase | Tests |
|-------|-------|
| 0     | 1     |
| 1     | 2     |
