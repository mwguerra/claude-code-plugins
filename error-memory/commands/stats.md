---
description: Show statistics about the error memory database
---

# Error Memory Statistics

Display statistics and insights about the error memory database.

## Usage

```
/error:stats
```

## Process

1. Run the stats script:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/stats.sh
```

2. Present the statistics in a clear, informative format.

## Statistics Displayed

### Overview
- Total errors in database
- Total searches performed
- Total matches found
- Match rate (successful searches)
- Total times solutions were used
- Average success rate of solutions

### Breakdown by Error Type
- SQLSTATE, TypeError, Exception, Fatal, etc.
- Count for each type

### Breakdown by Source
- bash, playwright, read, user, build, api, other
- Count for each source

### Breakdown by Project
- Top projects with most errors
- Count for each project

### Top Tags
- Most frequently used tags
- Helps identify common problem areas

### Most Used Solutions
- Errors whose solutions have been applied most often
- Indicates valuable knowledge

## Insights

Use this information to:
- Identify recurring problem areas
- See which projects have the most issues
- Track how effective the error memory system is
- Find the most valuable solutions in the database

## Example Output

```
Error Memory Statistics
========================

OVERVIEW
--------
Total Errors:     25
Total Searches:   142
Total Matches:    89
Match Rate:       62.68%

BY ERROR TYPE
-------------
  SQLSTATE: 8
  TypeError: 5
  Exception: 12

...
```
