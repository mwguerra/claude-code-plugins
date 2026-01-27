---
name: list
description: List all errors in the error memory database with optional filtering
arguments:
  - name: filters
    description: "Optional filters: --project <name>, --tag <tag>, --source <source>"
    required: false
---

# Error Memory List

List all errors stored in the error memory database with optional filtering.

## Usage

```
/error:list [--project <name>] [--tag <tag>] [--source <source>] [--max <n>]
```

## Process

1. Parse any filter arguments provided by the user.

2. Run the list script:

```bash
# List all (default max 20)
bash $CLAUDE_PLUGIN_ROOT/scripts/list-errors.sh

# With filters
bash $CLAUDE_PLUGIN_ROOT/scripts/list-errors.sh --project "my-app" --tag "laravel" --max 10
```

3. Present the results in a clear, scannable format.

## Filter Options

- **--project, -p**: Filter by project name (partial match)
- **--tag, -t**: Filter by tag (partial match)
- **--source, -s**: Filter by error source (bash, playwright, read, user, build, api, other)
- **--max, -n**: Maximum number of results (default: 20)

## Output

For each error, display:
- Error ID
- Error type
- Project name
- Source
- Tags
- Brief message excerpt
- Creation date
- Usage count

## Examples

```
/error:list
/error:list --project task-manager
/error:list --tag database
/error:list --source playwright --max 5
```
