---
description: Detect and fix drift between documentation and source code
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "<check | fix> [--docs path] [--code path] [--report]"
---

# Code-Documentation Sync

Detect and fix drift between documentation and source code.

## Syntax

```
/docs-specialist:sync <action> [options]
```

## Actions

- `check` - Compare documentation against code to find discrepancies
- `fix` - Resolve identified drift issues

---

## check

Compare documentation claims against actual code implementation.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `[target]` | No | Specific area: `api`, `models`, `components`, `config`, `all` (default: all) |
| `--since=<ref>` | No | Check changes since date, tag, or commit (e.g., `v1.0.0`, `2024-01-01`, `abc123`) |
| `--ignore=<patterns>` | No | Comma-separated patterns to ignore (e.g., `tests/*,*.draft.md`) |
| `--severity=<level>` | No | Minimum severity to report: `info`, `warning`, `error` (default: warning) |

### Analysis Categories

The sync check classifies every documented item into one of four categories:

| Status | Symbol | Meaning | Action Needed |
|--------|--------|---------|---------------|
| **Implemented** | ✅ | Code matches documentation exactly | None |
| **Partial** | ⚠️ | Code exists but differs from docs | Review and update |
| **Not Implemented** | ❌ | Documented but missing in code | Remove or mark as planned |
| **Undocumented** | 📝 | In code but not documented | Add documentation |

### Process

```
1. PARSE DOCUMENTATION
   ├── Scan all documentation files
   ├── Extract documented items:
   │   ├── API Endpoints
   │   │   ├── Route path
   │   │   ├── HTTP method
   │   │   ├── Request parameters
   │   │   ├── Request body schema
   │   │   ├── Response schema
   │   │   └── Authentication requirements
   │   │
   │   ├── Models/Entities
   │   │   ├── Properties and types
   │   │   ├── Relationships
   │   │   ├── Validations
   │   │   └── Methods
   │   │
   │   ├── Components
   │   │   ├── Props and types
   │   │   ├── Events/callbacks
   │   │   ├── Slots/children
   │   │   └── Methods
   │   │
   │   ├── Functions/Services
   │   │   ├── Signature
   │   │   ├── Parameters
   │   │   ├── Return type
   │   │   └── Side effects
   │   │
   │   └── Configuration
   │       ├── Environment variables
   │       ├── Config options
   │       └── Feature flags
   │
   └── Build DOCUMENTATION INVENTORY

2. SCAN CODEBASE
   ├── Identify source files by type
   ├── Extract actual implementations:
   │   ├── Route definitions
   │   │   ├── Path patterns
   │   │   ├── Methods
   │   │   ├── Middleware
   │   │   └── Handler signatures
   │   │
   │   ├── Model definitions
   │   │   ├── Properties
   │   │   ├── Relationships
   │   │   ├── Accessors/mutators
   │   │   └── Scopes
   │   │
   │   ├── Component definitions
   │   │   ├── Props
   │   │   ├── Emits
   │   │   ├── Expose
   │   │   └── Slots
   │   │
   │   ├── Function exports
   │   │   ├── Signatures
   │   │   ├── Types
   │   │   └── JSDoc
   │   │
   │   └── Config references
   │       ├── env() calls
   │       ├── config() calls
   │       └── Feature checks
   │
   └── Build CODE INVENTORY

3. COMPARE INVENTORIES
   ├── Match documentation items to code items
   │
   ├── For each DOCUMENTED item:
   │   ├── Search for matching code item
   │   ├── If EXACT MATCH found:
   │   │   └── ✅ Implemented
   │   ├── If PARTIAL MATCH found:
   │   │   ├── ⚠️ Partial
   │   │   └── Record differences
   │   └── If NOT FOUND:
   │       └── ❌ Not Implemented
   │
   ├── For each CODE item without documentation:
   │   └── 📝 Undocumented
   │
   └── Generate comparison results

4. DETAILED ANALYSIS (for partial matches)
   ├── Parameter differences
   │   ├── Missing parameters
   │   ├── Extra parameters
   │   ├── Type mismatches
   │   └── Default value changes
   │
   ├── Schema differences
   │   ├── Missing fields
   │   ├── Extra fields
   │   ├── Type changes
   │   └── Required/optional changes
   │
   ├── Behavior differences
   │   ├── Return type changes
   │   ├── Error handling changes
   │   └── Side effect changes
   │
   └── Version/deprecation info

5. OUTPUT REPORT
```

### Report Format

```
Sync Check Report
=================
Target: all | Since: HEAD~10
Analyzed: 45 documented items | 52 code items

SUMMARY
───────
  ✅ Implemented:     32 (71%)
  ⚠️ Partial:          5 (11%)
  ❌ Not Implemented:  8 (18%)
  📝 Undocumented:     7

═══════════════════════════════════════════════════════════════

⚠️ PARTIAL IMPLEMENTATIONS (5)
   Code exists but differs from documentation
───────────────────────────────────────────────────────────────

1. POST /api/users
   ├── Doc:  docs/api/users.md:34
   ├── Code: app/Http/Controllers/UserController.php:45
   └── Issues:
       • Parameter mismatch:
         - Doc says: "role" is required
         - Code has: "role" is optional (default: "user")
       • Missing in docs:
         - "email_verified" (required, boolean)
       • Response difference:
         - Doc shows: { user: {...} }
         - Code returns: { data: { user: {...} }, meta: {...} }

2. User Model
   ├── Doc:  docs/models/user.md:12
   ├── Code: app/Models/User.php:1
   └── Issues:
       • Missing property in docs:
         - preferences (json, nullable)
       • Documented but not in code:
         - hasMany(Post) relationship
       • Type mismatch:
         - Doc: email_verified (boolean)
         - Code: email_verified_at (timestamp, nullable)

═══════════════════════════════════════════════════════════════

❌ NOT IMPLEMENTED (8)
   Documented features not found in code
───────────────────────────────────────────────────────────────

1. DELETE /api/users/:id/avatar
   ├── Doc:  docs/api/users.md:78
   └── Status: Route not defined in any route file
   └── Action: Remove from docs OR implement feature

2. User.softDeletes
   ├── Doc:  docs/models/user.md:45
   └── Status: SoftDeletes trait not used in model
   └── Action: Remove from docs OR add trait to model

3. GET /api/reports/export
   ├── Doc:  docs/api/reports.md:23
   └── Status: ReportsController has no export method
   └── Action: Remove from docs OR implement method

[... more items ...]

═══════════════════════════════════════════════════════════════

📝 UNDOCUMENTED (7)
   Code features without documentation
───────────────────────────────────────────────────────────────

1. GET /api/users/export
   ├── Code: routes/api.php:45
   ├── Handler: UserController@export
   └── Suggested doc: docs/api/users.md

2. User::getPreferencesAttribute()
   ├── Code: app/Models/User.php:89
   └── Suggested doc: docs/models/user.md

3. CACHE_DRIVER environment variable
   ├── Code: config/cache.php:15
   └── Suggested doc: docs/configuration.md

[... more items ...]

═══════════════════════════════════════════════════════════════

RECOMMENDATIONS
───────────────
Priority 1 (Errors - misleading docs):
  • Update POST /api/users documentation with correct parameters
  • Remove DELETE /api/users/:id/avatar or implement it

Priority 2 (Warnings - incomplete docs):
  • Document GET /api/users/export endpoint
  • Update User model documentation

Priority 3 (Info - minor gaps):
  • Add CACHE_DRIVER to configuration docs

═══════════════════════════════════════════════════════════════

Next Steps:
  /docs-specialist:sync fix              # Fix interactively
  /docs-specialist:sync fix --auto       # Auto-fix all
  /docs-specialist:docs generate api     # Regenerate API docs
```

### Examples

```bash
# Full sync check
/docs-specialist:sync check

# Check only API documentation
/docs-specialist:sync check api

# Check only models
/docs-specialist:sync check models

# Check changes since last release
/docs-specialist:sync check --since=v1.0.0

# Check changes in last week
/docs-specialist:sync check --since=2024-01-01

# Ignore test files
/docs-specialist:sync check --ignore="tests/*,*.test.ts,*.spec.ts"

# Only show errors (hide warnings and info)
/docs-specialist:sync check --severity=error

# Full check with all details
/docs-specialist:sync check all --severity=info
```

---

## fix

Resolve identified drift issues between docs and code.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--severity=<level>` | No | Fix issues of this severity and above: `info`, `warning`, `error` (default: warning) |
| `--interactive` | No | Confirm each fix before applying (default: true) |
| `--auto` | No | Apply all fixes without confirmation |
| `--dry-run` | No | Show what would be fixed without making changes |

### Fix Strategies by Category

| Category | Default Fix Strategy | Alternative Actions |
|----------|---------------------|---------------------|
| ⚠️ **Partial** | Update docs to match code | Mark as intentional, Flag code issue |
| ❌ **Not Implemented** | Remove from docs | Mark as "planned", Flag for implementation |
| 📝 **Undocumented** | Generate documentation | Mark as internal/private, Skip |

### Process

```
1. LOAD SYNC RESULTS
   ├── Run sync check if not recent
   └── Load issues by category

2. FOR EACH ISSUE (interactive mode)
   ├── Display issue details
   ├── Show current doc content
   ├── Show current code content
   ├── Present options:
   │   │
   │   ├── [U] Update docs to match code
   │   │   └── Generate updated documentation
   │   │
   │   ├── [R] Remove from docs
   │   │   └── Delete the documented item
   │   │
   │   ├── [P] Mark as planned
   │   │   └── Add "Planned" or "Coming Soon" marker
   │   │
   │   ├── [G] Generate new docs
   │   │   └── Create documentation for code item
   │   │
   │   ├── [I] Mark as intentional
   │   │   └── Add comment noting intentional difference
   │   │
   │   ├── [F] Flag for code change
   │   │   └── Create TODO in code or issue tracker
   │   │
   │   ├── [S] Skip
   │   │   └── Leave as-is for now
   │   │
   │   └── [Q] Quit
   │       └── Stop processing
   │
   └── Apply selected action

3. APPLY FIXES
   ├── Make documentation changes
   ├── Track what was modified
   └── Verify changes

4. REPORT RESULTS
   ├── Summary of fixes applied
   ├── Remaining issues
   └── Files modified
```

### Interactive Session Example

```
Sync Fix - Issue 1 of 15
════════════════════════

⚠️ PARTIAL: POST /api/users

Documentation (docs/api/users.md:34):
┌─────────────────────────────────────────────
│ ### Create User
│ POST /api/users
│
│ Parameters:
│ - name (string, required)
│ - email (string, required)
│ - role (string, required)
│
│ Response: { user: {...} }
└─────────────────────────────────────────────

Code (UserController.php:45):
┌─────────────────────────────────────────────
│ public function store(Request $request)
│ {
│     $validated = $request->validate([
│         'name' => 'required|string',
│         'email' => 'required|email',
│         'role' => 'string',  // optional!
│         'email_verified' => 'required|boolean',
│     ]);
│     ...
│     return response()->json([
│         'data' => ['user' => $user],
│         'meta' => ['created_at' => now()]
│     ]);
│ }
└─────────────────────────────────────────────

Differences:
  • role: required → optional (default: "user")
  • email_verified: missing in docs (required)
  • Response wrapper: { user } → { data: { user }, meta }

Actions:
  [U] Update docs to match code
  [I] Mark as intentional difference
  [F] Flag for code review
  [S] Skip for now
  [Q] Quit

Choice [U/I/F/S/Q]: U

✓ Updated docs/api/users.md
  - Changed role to optional
  - Added email_verified parameter
  - Updated response format

Press Enter to continue...
```

### Examples

```bash
# Interactive fix (recommended)
/docs-specialist:sync fix

# Preview what would be fixed
/docs-specialist:sync fix --dry-run

# Auto-fix all issues (update docs to match code)
/docs-specialist:sync fix --auto

# Fix only errors (skip warnings)
/docs-specialist:sync fix --severity=error

# Fix everything including minor issues
/docs-specialist:sync fix --severity=info
```

---

## Common Workflows

### After Code Changes
```bash
/docs-specialist:sync check           # See what's out of sync
/docs-specialist:sync fix             # Fix the issues
```

### Before Release
```bash
/docs-specialist:sync check --severity=error    # Check for critical issues
/docs-specialist:docs validate                  # Full quality check
```

### Regular Maintenance
```bash
/docs-specialist:sync check --since=v1.0.0     # Check since last release
/docs-specialist:sync fix --severity=warning   # Fix important issues
```

### CI/CD Integration
```bash
# Fail build if critical sync issues exist
/docs-specialist:sync check --severity=error --report=json
# Exit code non-zero if errors found
```

---

## Notes

- Run `sync check` before `sync fix` to see the full picture
- Use `--dry-run` first when using `--auto`
- Partial matches are often the most important to review
- Undocumented items may be intentionally internal - review before documenting
- Use `--since` to focus on recent changes during active development
