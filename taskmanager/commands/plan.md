---
allowed-tools: Skill(taskmanager)
argument-hint: "[file-path-or-folder-or-prompt] [--debug]"
description: Parse a PRD file, folder, or prompt and generate hierarchical tasks with dependencies and complexity analysis
---

# Plan Command

You are implementing the `taskmanager:plan` command.

## Arguments

- `$1` (optional): path to a PRD file, a folder containing documentation files, or a prompt describing what to plan. If omitted, use `.taskmanager/docs/prd.md`.
- `--debug` or `-d`: Enable verbose debug logging to `.taskmanager/logs/debug.log`

## Behavior

### 0. Initialize logging session

1. Generate a unique session ID using timestamp: `sess-$(date +%Y%m%d%H%M%S)` (e.g., `sess-20251212103045`).
2. Check for `--debug` / `-d` flag.
3. Update `.taskmanager/state.json`:
   - Set `logging.sessionId` to the generated ID.
   - Set `logging.debugEnabled = true` if `--debug` flag present, else `false`.
4. Log to `decisions.log`:
   ```
   <timestamp> [DECISION] [<session-id>] Started plan command
   ```

### 1. Determine input type
   - If the user provided an argument, determine if `$1` is:
     1. **A folder path** - Contains multiple documentation files
     2. **A file path** - A single PRD/documentation file
     3. **A prompt** - Free-text describing what should be done
   - If nothing is provided, default to `.taskmanager/docs/prd.md`.
   - If the argument is not a valid path but looks like one, inform the user and gracefully exit.

### 1.1 Handling folder input

When `$1` is a folder (directory):

1. **Discover documentation files** - Use Glob to find all markdown files (`**/*.md`) in the folder and its subdirectories.
2. **Read all files** - Use Read to load the content of each discovered file.
3. **Aggregate content** - Combine all file contents into a single PRD context, preserving the source file names as section headers:
   ```
   # From: architecture.md
   [content of architecture.md]

   # From: features/user-auth.md
   [content of features/user-auth.md]

   # From: database.md
   [content of database.md]
   ```
4. **Pass aggregated content to the skill** - Treat the combined content as if it were a single PRD file.

**Folder input notes:**
- Files are sorted alphabetically by path for consistent ordering.
- Only `.md` (markdown) files are included by default.
- Empty files are skipped.
- The folder structure is preserved in section headers for context.
- If no markdown files are found in the folder, inform the user and gracefully exit.

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

### Using the default PRD file
- `taskmanager:plan`
  - Reads from `.taskmanager/docs/prd.md`

### Using a single file
- `taskmanager:plan docs/new-feature-prd.md`
  - Reads the specified markdown file

### Using a folder with multiple documentation files
- `taskmanager:plan docs/project-specs/`
  - Discovers and reads all `.md` files in the folder recursively
  - Example folder structure:
    ```
    docs/project-specs/
    ├── architecture.md      # System architecture overview
    ├── database.md          # Database schema and design
    ├── features/
    │   ├── user-auth.md     # User authentication feature
    │   └── dashboard.md     # Dashboard feature
    └── api/
        └── endpoints.md     # API endpoint definitions
    ```
  - All files are aggregated into a single PRD context for task generation

### Using a prompt
- `taskmanager:plan "Create a react app that has a counter button that increments one each time its clicked on an on screen counter that begins at zero"`
  - Uses the prompt text directly as PRD content

### With debug logging
- `taskmanager:plan docs/specs/ --debug`
  - Enables verbose debug logging to `.taskmanager/logs/debug.log`