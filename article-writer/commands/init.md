---
description: Initialize article-writer plugin - creates config folder, schemas, and default settings
allowed-tools: Bash(bun:*), Skill(author-profile)
argument-hint: [--check]
---

# Initialize Article Writer

Set up the article-writer plugin in your project.

**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writerinit) | [docs/PROCESS.md](../docs/PROCESS.md)

## Usage

```bash
# Full initialization
/article-writer:init

# Check what's missing without creating
/article-writer:init --check
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/init.ts [--check]`

## What It Creates

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json    # Article schema reference
│   │   ├── authors.schema.json          # Author schema reference
│   │   └── settings.schema.json         # Settings schema reference
│   └── article_writer.db                # SQLite database (authors, articles, settings)
├── content/
│   └── articles/                        # Output folder for articles
└── docs/                                # Documentation folder
```

## Default Settings

The database comes pre-configured with defaults for each companion project type:

| Type | Technologies | Has Tests |
|------|-------------|-----------|
| `code` | Laravel 12, Pest 4, SQLite | Yes |
| `document` | Markdown | No |
| `diagram` | Mermaid | No |
| `config` | Docker, Docker Compose | No |

To view/customize: `/article-writer:settings show`

## After Initialization

### Step 1: Create Your First Author

**Option A - Manual questionnaire:**
```bash
/article-writer:author add
```

**Option B - Extract from transcripts (recommended if you have recordings):**
```bash
/article-writer:author analyze --speaker "Your Name" podcast.txt
```

### Step 2: Review Settings (Optional)

```bash
/article-writer:settings show
```

### Step 3: Create Your First Article

```bash
/article-writer:article implementing rate limiting in Laravel
```

## Re-running Init

Running `/article-writer:init` again is safe:
- Creates any missing files/folders
- Skips existing files (won't overwrite your data)
- Reports what was created vs what already existed

## Migration from JSON

If you have existing JSON files (`article_tasks.json`, `authors.json`, `settings.json`), run:

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/migrate.ts
```

This migrates all data to SQLite and renames JSON files to `.json.migrated`.

## Files Reference

After init, these resources are available:

| Resource | Purpose | View Command |
|----------|---------|--------------|
| `.article_writer/article_writer.db` | All data (authors, articles, settings) | `/article-writer:queue status` |
| `.article_writer/schemas/` | Schema documentation | `/article-writer:doctor` |
| `content/articles/` | Output folder | (check after creation) |
