---
description: Post-development toolkit - orchestrate all launch preparation tasks (SEO, screenshots, personas, ads, articles, landing pages)
argument-hint: [init|run|status|seo|screenshots|personas|ads|articles|landing] [options]
allowed-tools: Bash, Read, Write, Glob, Grep, Task
---

# Post-Development Command

Master command to orchestrate all post-development tasks for app launch preparation.

## Subcommands

### `init` - Initialize post-development
Creates the `.post-development` folder structure and master plan.

```
/post-dev init [--base-url http://localhost:3000] [--project-type saas|ecommerce|blog|portfolio]
```

### `run` - Execute all pending tasks
Runs all tasks in dependency order.

```
/post-dev run [--task seo|screenshots|personas|ads|articles|landing] [--parallel] [--force]
```

### `status` - Check task status
Shows progress of all post-development tasks.

```
/post-dev status [--verbose] [--task <task-id>]
```

### Individual Task Commands

```
/post-dev seo          # Run SEO analysis only
/post-dev screenshots  # Capture screenshots only
/post-dev personas     # Create personas only
/post-dev ads          # Generate ads only
/post-dev articles     # Write articles only
/post-dev landing      # Create landing pages only
```

## Instructions

1. Parse the subcommand from `$ARGUMENTS`
2. Load or create the master plan at `.post-development/post-development.json`
3. Execute the appropriate action

### For `init`:

1. Create directory structure:
   ```
   .post-development/
   ├── seo/
   │   ├── pages/
   │   └── assets/
   │       ├── favicons/
   │       └── og-images/
   ├── screenshots/
   ├── personas/
   │   ├── strategies/
   │   └── cta/
   ├── ads/
   │   ├── instagram/
   │   ├── facebook/
   │   ├── linkedin/
   │   └── twitter/
   ├── articles/
   │   ├── article-1/
   │   ├── article-2/
   │   └── article-3/
   ├── landing-pages/
   └── post-development.json
   ```

2. Analyze project to determine:
   - Project name and type
   - Tech stack
   - Available routes/pages
   - Existing documentation

3. Create master plan with all tasks

### For `run`:

1. Load master plan
2. Build dependency graph:
   - `seo` → no dependencies
   - `screenshots` → no dependencies
   - `personas` → depends on `seo`
   - `ads` → depends on `personas`, `screenshots`
   - `articles` → depends on `personas`, `screenshots`
   - `landing` → depends on `personas`, `screenshots`

3. Execute tasks in topological order
4. Update status after each task
5. Report results

### For `status`:

Display progress table:
```
📦 Post-Development Status
===========================
Project: MyApp (SaaS)
Started: 2025-01-15

Tasks:
  ✅ seo          SEO Analysis           Done     2025-01-15 10:30
  ✅ screenshots  Screenshot Capture     Done     2025-01-15 10:35
  🔄 personas     Persona Creation       Running  -
  ⏳ ads          Ad Generation          Pending  -
  ⏳ articles     Article Writing        Pending  -
  ⏳ landing      Landing Pages          Pending  -

Progress: [████░░░░░░] 33% (2/6 tasks)
```

### For individual tasks:

Delegate to the appropriate agent:
- `seo` → Use SEO Analyst agent
- `screenshots` → Use Screenshot Planner agent
- `personas` → Use Persona Strategist agent
- `ads` → Use Ad Creator agent
- `articles` → Use Content Writer agent
- `landing` → Use Landing Page Designer agent

## Task Dependencies

```
        ┌─────────────┐
        │    seo      │
        └──────┬──────┘
               │
        ┌──────▼──────┐     ┌─────────────┐
        │  personas   │     │ screenshots │
        └──────┬──────┘     └──────┬──────┘
               │                   │
    ┌──────────┼───────────────────┤
    │          │                   │
┌───▼───┐  ┌───▼───┐         ┌────▼────┐
│  ads  │  │articles│         │ landing │
└───────┘  └───────┘         └─────────┘
```

## Output

After each operation, report:
- Tasks completed
- Tasks pending
- Any errors encountered
- Next steps

## Quick Start Example

```bash
# Initialize
/post-dev init --base-url http://localhost:3000

# Run everything
/post-dev run

# Check progress
/post-dev status
```
