---
allowed-tools: Skill(taskmanager-memory)
description: Manage project memories - add, list, show, update, deprecate, or check conflicts
argument-hint: "<action> [args] [--debug]"
---

# Memory Command

You are implementing `/mwguerra:taskmanager:memory`.

This command provides direct access to the project memory system, allowing users to manage global memories outside of task execution.

## Global Options

- `--debug` or `-d`: Enable verbose debug logging to `.taskmanager/logs/debug.log`

When `--debug` is provided:
1. Generate a unique session ID using timestamp: `sess-$(date +%Y%m%d%H%M%S)` (e.g., `sess-20251212103045`).
2. Update `.taskmanager/state.json`:
   - Set `logging.sessionId` to the generated ID.
   - Set `logging.debugEnabled = true`.
3. Write verbose debug information during the operation.
4. Reset `logging.debugEnabled = false` and `logging.sessionId = null` at completion.

## Actions

### `add "description"` - Add a new global memory

Usage: `/memory add "Always use TypeScript strict mode"`

1. Parse the description from `$2` onwards.
2. Use `AskUserQuestion` to gather additional details:
   - **Kind**: What type of memory is this?
     - Options: constraint, decision, bugfix, workaround, convention, architecture, process, integration, anti-pattern, other
   - **Importance**: How critical is this? (1-5)
     - Options: 1 (low), 2, 3 (medium), 4, 5 (critical)
   - **Domains**: What areas does this apply to?
     - Free text, comma-separated (e.g., "testing, architecture")
3. Use the `taskmanager-memory` skill to create the memory:
   - Generate next ID (M-0001, M-0002, etc.)
   - Set `source.type = "user"`, `source.via = "memory command"`.
   - Set `status = "active"`.
   - Set `autoUpdatable = false` (user-created).
   - Set timestamps.
4. Confirm creation with the memory ID.

### `list [--active|--all|--deprecated]` - List memories

Usage:
- `/memory list` - List active memories (default)
- `/memory list --active` - List active memories
- `/memory list --all` - List all memories including deprecated
- `/memory list --deprecated` - List only deprecated memories

1. Load `.taskmanager/memories.json`.
2. Filter by status based on flag:
   - Default or `--active`: `status == "active"`
   - `--all`: No filter
   - `--deprecated`: `status == "deprecated" || status == "superseded"`
3. Display as table:
   ```
   ID       | Kind       | Title                          | Importance | Uses
   ---------|------------|--------------------------------|------------|-----
   M-0001   | constraint | Always use Pest for tests      | 5          | 12
   M-0002   | decision   | Use TypeScript strict mode     | 4          | 3
   ```

### `show <id>` - Show memory details

Usage: `/memory show M-0001`

1. Load `.taskmanager/memories.json`.
2. Find memory with matching ID.
3. Display full details:
   ```
   Memory: M-0001
   Title: Always use Pest for tests in Laravel apps
   Kind: constraint
   Status: active
   Importance: 5/5
   Confidence: 0.95

   Why Important:
   Ensures consistency across all test suites and aligns with team standard.

   Body:
   For any Laravel project in this monorepo, always create tests in Pest.
   Do not mix PHPUnit-style tests unless migrating legacy code.

   Scope:
   - Files: tests/, app/
   - Domains: testing, architecture

   Source: user (mwguerra) via cli

   Timestamps:
   - Created: 2025-11-22T10:00:00Z
   - Updated: 2025-11-22T10:00:00Z
   - Last Used: 2025-12-10T14:30:00Z

   Usage: 12 times

   Conflict History: (none)
   ```

### `update <id> "new description"` - Update memory content

Usage: `/memory update M-0001 "Always use Pest for tests, including feature and unit tests"`

1. Load `.taskmanager/memories.json`.
2. Find memory with matching ID.
3. Check ownership:
   - If `source.type == "user"`: Proceed (user can update their own memories).
   - If `source.type != "user"`: Ask for confirmation since this is a system memory.
4. Use `AskUserQuestion` to confirm the update and ask if any other fields should change.
5. Update the memory:
   - Update `body` with new description.
   - Bump `updatedAt`.
   - Do NOT change `id`, `createdAt`, or `source`.
6. Write back to `memories.json`.
7. Confirm the update.

### `deprecate <id> [reason]` - Mark memory as deprecated

Usage:
- `/memory deprecate M-0001`
- `/memory deprecate M-0001 "No longer using Pest, switched to PHPUnit"`

1. Load `.taskmanager/memories.json`.
2. Find memory with matching ID.
3. If reason provided, use it. Otherwise, ask for reason using `AskUserQuestion`.
4. Update the memory:
   - Set `status = "deprecated"`.
   - Bump `updatedAt`.
   - Add to `conflictResolutions[]`:
     ```json
     {
       "timestamp": "<now>",
       "resolution": "deprecated",
       "reason": "<the reason>"
     }
     ```
5. Write back to `memories.json`.
6. Confirm deprecation.

### `supersede <old-id> "new description"` - Supersede with new memory

Usage: `/memory supersede M-0001 "Use PHPUnit for all tests instead of Pest"`

1. Load `.taskmanager/memories.json`.
2. Find old memory with matching ID.
3. Create new memory (similar to `add`):
   - Generate next ID.
   - Inherit relevant fields from old memory (kind, tags, scope, importance).
   - Set new `body` from the description.
   - Set `source.type = "user"`, `source.via = "memory command (supersede)"`.
4. Update old memory:
   - Set `status = "superseded"`.
   - Set `supersededBy = "<new-id>"`.
   - Bump `updatedAt`.
   - Add to `conflictResolutions[]`:
     ```json
     {
       "timestamp": "<now>",
       "resolution": "superseded",
       "reason": "Superseded by <new-id>"
     }
     ```
5. Write back to `memories.json`.
6. Confirm: "Memory M-0001 superseded by M-0002".

### `conflicts` - Check all memories for conflicts

Usage: `/memory conflicts`

1. Load `.taskmanager/memories.json`.
2. Filter for active memories.
3. For each active memory, run conflict detection:
   - Check `scope.files` - do referenced files still exist?
   - Check for implementation divergence where possible.
4. Display results:
   ```
   Checking 5 active memories for conflicts...

   Conflicts found:

   [WARNING] M-0003: API validation rules
   - File not found: app/Services/OldValidator.php
   - Suggested action: Update scope or deprecate

   [INFO] M-0005: Test coverage requirements
   - Referenced domain "e2e-testing" has failing tests

   No conflicts: M-0001, M-0002, M-0004
   ```
5. For each conflict found, offer resolution options using `AskUserQuestion`.

### `search "query"` - Search memories by content

Usage: `/memory search "testing"`

1. Load `.taskmanager/memories.json`.
2. Search for query in:
   - `title`
   - `body`
   - `tags`
   - `scope.domains`
3. Display matching memories (similar to `list` format).

## Error Handling

- If memory ID not found: "Memory '<id>' not found. Use `/memory list` to see available memories."
- If action not recognized: "Unknown action '<action>'. Available actions: add, list, show, update, deprecate, supersede, conflicts, search"
- If memories.json doesn't exist: "No memories file found. Initialize with `/init` first."

## Logging Requirements

This command MUST log to `.taskmanager/logs/`:

**To errors.log** (ALWAYS):
- Memory not found errors
- Parse/validation errors
- Conflict detection errors

**To decisions.log** (ALWAYS):
- Memory creation (add)
- Memory updates
- Memory deprecation/supersession
- Conflict resolutions

**To debug.log** (ONLY when `--debug` enabled):
- Memory file loading details
- Search algorithm steps
- Conflict detection intermediate results
