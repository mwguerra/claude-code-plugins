---
description: Log a new error and its solution to the error memory database
---

# Error Memory Log

Log a new error and its solution to build up the error memory database.

## Usage

```
/error-memory:log
```

This command is interactive - Claude will gather the required information from the current context and ask for any missing details.

## Process

1. **Gather Error Information** - Extract from the current conversation context:
   - The error message (required)
   - What was happening when the error occurred
   - The source of the error (bash, playwright, read, user, build, api, other)

2. **Document the Analysis**:
   - What caused the error (required)
   - How it was solved (required)
   - Why the solution works

3. **Capture Code Changes** (if applicable):
   - Which file was changed
   - Code before the fix
   - Code after the fix

4. **Add Metadata**:
   - Project name (from current working directory or conversation)
   - Project path
   - Relevant tags for categorization

5. **Log the Error**:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/log-error.sh --json '{
  "errorMessage": "<error message>",
  "project": "<project name>",
  "projectPath": "<path>",
  "source": "<source>",
  "whatHappened": "<context>",
  "cause": "<why it happened>",
  "solution": "<how it was fixed>",
  "rationale": "<why the solution works>",
  "fileChanged": "<file path>",
  "codeBefore": "<code before>",
  "codeAfter": "<code after>",
  "tags": ["tag1", "tag2"]
}'
```

## Tag Guidelines

Use consistent, meaningful tags:
- **Technology**: laravel, react, node, php, python, docker
- **Framework**: filament, livewire, vue, nextjs
- **Domain**: database, api, auth, forms, validation
- **Type**: configuration, dependency, syntax, runtime

## Example

After solving a database connection error:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/log-error.sh --json '{
  "errorMessage": "SQLSTATE[HY000] [2002] Connection refused",
  "project": "my-laravel-app",
  "projectPath": "/home/user/projects/my-laravel-app",
  "source": "bash",
  "whatHappened": "Running php artisan migrate",
  "cause": "Database container was not running",
  "solution": "Start the database container with docker-compose up -d db",
  "rationale": "Laravel needs an active database connection to run migrations",
  "tags": ["laravel", "database", "docker", "connection"]
}'
```
