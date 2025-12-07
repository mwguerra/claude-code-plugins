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
│   │   ├── article-tasks.schema.json    # Validates article_tasks.json
│   │   ├── authors.schema.json          # Validates authors.json
│   │   └── settings.schema.json         # Validates settings.json
│   ├── article_tasks.json               # Empty article queue
│   ├── authors.json                     # Empty (add authors next)
│   └── settings.json                    # Pre-configured example defaults
├── content/
│   └── articles/                        # Output folder for articles
└── docs/                                # Documentation folder
```

## Default Settings

The `settings.json` file comes pre-configured with defaults for each example type:

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
- ✅ Creates any missing files/folders
- ⏭️ Skips existing files (won't overwrite your data)
- 📝 Reports what was created vs what already existed

## Files Reference

After init, these files are available:

| File | Purpose | View Command |
|------|---------|--------------|
| `.article_writer/authors.json` | Author profiles | `/article-writer:author list` |
| `.article_writer/settings.json` | Example defaults | `/article-writer:settings show` |
| `.article_writer/article_tasks.json` | Article queue | `/article-writer:queue status` |
