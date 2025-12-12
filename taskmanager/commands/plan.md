---
allowed-tools: Skill(taskmanager)
argument-hint: "[file-path-or-prompt] [--debug]"
description: Read a PRD (default .taskmanager/docs/prd.md) and update .taskmanager/tasks.json with a hierarchical plan.
---

# Plan Command

You are implementing the `/mwguerra:taskmanager:plan` command.

## Arguments

- `$1` (optional): path to a PRD file or a prompt describing what to plan. If omitted, use `.taskmanager/docs/prd.md`.
- `--debug` or `-d`: Enable verbose debug logging to `.taskmanager/logs/debug.log`

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID (e.g., `sess-<8-random-chars>`).
2. Check for `--debug` / `-d` flag.
3. Update `.taskmanager/state.json`:
   - Set `logging.sessionId` to the generated ID.
   - Set `logging.debugEnabled = true` if `--debug` flag present, else `false`.
4. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started plan command
   ```

### 1. Determine which file to use
   - If the user provided an argument, treat `$1` as a path to a file
     relative to the project root.
   - If nothing is provided, default to `.taskmanager/docs/prd.md`.
   - If the argument is not a path for a valid readable file, but it looks like a path, say that to the user so a new path could be provided or gacefully exit.
   - If the argument is a prompt from the user explaining what should be done, use that to generate the tasks.

2. Call the `taskmanager` skill with instructions to:
   - Read the chosen file or use the prompt if provided.
   - Update `.taskmanager/tasks.json` with a realistic, hierarchical plan
     as described in the skill and its examples.
   - Optionally update `.taskmanager/state.json` and `.taskmanager/logs/decisions.log`
     to reflect what changed.

### 3. After the skill finishes, summarize for the user
   - How many new tasks/subtasks were created.
   - Whether any existing tasks were updated.
   - The IDs and titles of the most important top-level tasks.

### 4. Cleanup logging session

1. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Completed plan command: N tasks created
   ```
2. Reset `.taskmanager/state.json`:
   - Set `logging.debugEnabled = false`
   - Set `logging.sessionId = null`

## Logging Requirements

This command MUST log to `.taskmanager/logs/`:

**To errors.log** (ALWAYS):
- File not found errors
- Parse errors
- Validation errors

**To decisions.log** (ALWAYS):
- Command start and completion
- Task creation summaries

**To debug.log** (ONLY when `--debug` enabled):
- PRD parsing details
- Task generation algorithm steps
- Complexity analysis details

## Usage examples

- `/mwguerra:taskmanager:plan`
- `/mwguerra:taskmanager:plan docs/new-feature-prd.md`
- `/mwguerra:taskmanager:plan "Create a react app that has a counter button that increments one each time its clicked on an on screen couter that begins at zero"`