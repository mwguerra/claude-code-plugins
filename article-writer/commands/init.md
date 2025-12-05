---
description: Initialize article-writer in the current project - creates .article_writer folder and guides first author setup
allowed-tools: Bash(bun:*), Skill(author-profile)
argument-hint: [--check]
---

# Initialize Article Writer

Set up the article-writer plugin in your project.

## Usage

```
/article-writer:init           # Initialize and create first author
/article-writer:init --check   # Only check what's missing
```

## What It Creates

```
your-project/
├── .article_writer/
│   ├── schemas/
│   │   ├── article-tasks.schema.json
│   │   └── authors.schema.json
│   ├── article_tasks.json              # Empty task queue
│   └── authors.json                    # Authors list
├── docs/                               # For documentation
└── content/
    └── articles/                       # Output directory
```

## Process

1. Run init script to create/complete folder structure:
   ```bash
   bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/init.ts
   ```

2. If no authors exist, guide through first author creation:
   - Ask about identity (name, role, experience)
   - Ask about languages (primary + translations)
   - Ask about tone (formality, opinionated)
   - Ask about vocabulary and phrases
   - Ask about opinions and positions
   - Create author profile in authors.json

3. Report next steps

## First Author Setup Questions

Ask these in conversational groups (2-3 at a time):

### Identity
- What name should be used for this author profile?
- What's your professional role/title?
- What are your main areas of expertise?

### Languages
- What's your primary writing language? (e.g., pt_BR, en_US)
- Should articles be translated to other languages? Which ones?

### Tone (1-10 scale)
- How casual vs formal should your writing be? (1=very casual, 10=very formal)
- How opinionated vs neutral? (1=always hedge, 10=strong opinions)

### Vocabulary
- What technical terms can you use freely (readers know them)?
- What terms should always be explained on first use?

### Style
- Any signature phrases you like to use?
- Any phrases or words to avoid?

### Positions
- Any strong opinions on technologies or approaches?
- Any topics where you prefer to stay neutral?

## Non-Destructive

If `.article_writer/` already exists:
- Missing files are created
- Existing files are preserved
- Existing authors are kept

## Next Steps After Init

1. Add more authors if needed: `/article-writer:author add`
2. Add article tasks: `/article-writer:queue add`
3. Start writing: `/article-writer:article <topic>`
