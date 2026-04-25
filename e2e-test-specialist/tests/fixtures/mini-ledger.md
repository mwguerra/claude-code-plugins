# Mini E2E Ledger Fixture

Used by `tests/cases/test_11_import_fixture.sh`. Covers every section type the
importer recognizes, in miniature.

## Directives

### No SSH writes during E2E

**Enforcement**: blocking
**Rationale**: A red flag the agent must investigate, not paper over.

Don't ssh into a server to fix state mid-run; the E2E suite must reflect the
deployed system, not a hand-patched copy.

### Capture every bug

**Enforcement**: warning

Every observed defect goes into the bugs table; no silent skipping.

## VPS Infrastructure & Credentials

### Worker 1 (do-syd-1)

**Provider**: DigitalOcean | **Region**: SYD1 | **IP**: 159.0.0.1
**SSH user**: root | **Auth**: ssh-key (`~/.ssh/id_ed25519`)

### DigitalOcean API

- **kind**: api-key
- **token**: dop_v1_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
- **scope**: read-write

## Test App Matrix

| App   | Type    | DB | Redis | Notes |
|-------|---------|----|-------|-------|
| todo  | laravel | pg | yes   | base test app |
| note  | laravel | pg | no    | second test app |

## E2E Test Phases

### Phase 0: Smoke

Sanity checks before any heavy testing.

**0.1 Homepage loads**
1. Navigate to https://todo.example.com/
2. Verify HTTP 200 and the app title is visible.

**0.2 Login form renders**
1. Navigate to /login.
2. Verify the email and password fields are present.

### Phase 1: CRUD per app (R5+)

For each app, verify create/edit/delete on the primary resource.

**1.1 Create item**
1. Navigate to /items/new.
2. Fill the form and submit; verify the item appears in the list.

**1.2 Edit item**
1. Open an existing item.
2. Change the title and save; verify the new title shows.

## Test Count Summary

| Phase | Expected tests |
|-------|----------------|
| P00   | 2 |
| P01   | 2 |

## Test Results Log

### 2026-01-15 — R-001 — Smoke pass

**Context**: First clean run after package upgrade.
**Final state**: green.

**Bugs**: none.

**Memories**:
- Phase 0 always runs in under 30 seconds; safe to run on every commit.
