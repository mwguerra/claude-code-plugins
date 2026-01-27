---
name: show
description: Show full details of a specific error by ID
arguments:
  - name: id
    description: The error ID to show (e.g., err-abc123)
    required: true
---

# Error Memory Show

Display the full details of a specific error from the database.

## Usage

```
/error:show <error-id>
```

## Process

1. Run the show script with the provided ID:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/show-error.sh <error-id>
```

2. Present all available information in a well-structured format:
   - Error information (type, message, keywords)
   - Context (project, source, what happened)
   - Analysis (cause, solution, rationale)
   - Code changes (if available)
   - Tags
   - Usage statistics

## Output Sections

### Error Information
- Original error message
- Normalized version (for matching)
- Error type classification
- Extracted keywords

### Context
- Project name and path
- Error source (bash, playwright, etc.)
- What was happening when it occurred

### Analysis
- Root cause explanation
- Solution that worked
- Rationale for why it works

### Code Changes (if recorded)
- File that was modified
- Code before the fix
- Code after the fix

### Metadata
- Tags for categorization
- Times this solution was used
- Last used date
- Success rate

## Example

```
/error:show err-abc123def
```
