---
name: search
description: Search for similar errors in the error memory database
arguments:
  - name: query
    description: Error message or keywords to search for
    required: true
---

# Error Memory Search

Search the error memory database for similar errors and their solutions.

## Usage

```
/error:search <error message or keywords>
```

## Process

1. Run the search script with the provided query:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/search.sh "<query>" --max 5
```

2. Review the results:
   - **BEST MATCH** (100%): Exact same error - apply the solution directly
   - **HIGH CONFIDENCE** (70-99%): Very similar error - solution likely applies
   - **MEDIUM CONFIDENCE** (50-69%): Related error - review solution for applicability
   - **LOW CONFIDENCE** (30-49%): Loosely related - use as reference only

3. If a good match is found, present the solution to the user and explain how it applies to their current error.

4. If no match is found, inform the user this appears to be a new error and suggest logging it after it's solved with `/error:log`.

## Output Format

Present results clearly showing:
- Confidence level and match type
- Project and tags for context
- The cause of the original error
- The solution that worked
- Any code changes if available

## Example

```
/error:search SQLSTATE[HY000]: Connection refused
```
