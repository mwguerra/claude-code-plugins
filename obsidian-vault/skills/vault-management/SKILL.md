---
name: vault-management
description: This skill should be used when the user asks to "manage notes", "update vault", "add to obsidian", "document in vault", "search my notes", "find related notes", or when working with Obsidian vault files. Also triggers when discussing knowledge management, note organization, or when Claude Code auto-captures commits, tasks, or component creation.
version: 1.0.0
---

# Obsidian Vault Management

Manage the Obsidian vault as a developer knowledge base and automatic work journal.

## When to Use

Activate this skill when:
- User requests note operations (add, search, update, import, link, archive)
- Working with project documentation that should be stored in the vault
- Auto-capturing commits, tasks, or Claude Code components
- User asks about their notes, documentation, or knowledge base
- Organizing or finding information in the vault

## Vault Structure

```
~/guerra_vault/
├── projects/              # Project-specific documentation
├── technologies/          # Technology knowledge (Laravel, React, etc.)
├── claude-code/           # Claude Code components
│   ├── agents/
│   ├── hooks/
│   ├── skills/
│   └── tools/
├── ideas/                 # Feature ideas and experiments
├── personal/              # Career and learning goals
├── todo/                  # Tasks and checklists
├── references/            # Bookmarks, snippets, cheatsheets
├── journal/               # Auto-captured events
│   ├── commits/           # Git commit documentation
│   ├── tasks/             # Completed task summaries
│   └── creations/         # Component creation logs
└── _archive/              # Archived notes
```

## Frontmatter Standard

All notes MUST include this YAML frontmatter:

```yaml
---
title: "Note Title"
description: "Brief description of the content"
tags: [tag1, tag2, category]
related: [[path/to/related-note]]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

**Rules:**
- `title`: Descriptive, matches the main heading
- `description`: One sentence explaining the content
- `tags`: Always include the category as a tag
- `related`: Wiki-link format, add related notes when relevant
- `created`: Set once when created
- `updated`: Update whenever the note changes

## Available Commands

| Command | Purpose |
|---------|---------|
| `/obsidian:init` | Set up vault configuration and structure |
| `/obsidian:add <category> <title>` | Create a new note |
| `/obsidian:search <query>` | Find notes by title, content, or tags |
| `/obsidian:update <note>` | Edit note frontmatter or append content |
| `/obsidian:import <file>` | Import external files with frontmatter |
| `/obsidian:list [category]` | List notes, optionally by category |
| `/obsidian:tags [--stats]` | View tags and usage statistics |
| `/obsidian:link <note1> <note2>` | Create bidirectional related links |
| `/obsidian:archive <note>` | Move note to archive |

## Auto-Capture Behavior

The plugin automatically captures:

### Git Commits
- Creates `journal/commits/YYYY-MM-DD-<slug>.md`
- Includes: commit message, date, project, branch, files changed
- Placeholder sections for "What" and "Why" (fill in with context)

### Task Completions
- Creates `journal/tasks/YYYY-MM-DD-<slug>.md`
- Captures subagent summaries
- Includes: summary, what was done, decisions made

### Claude Code Components
- Creates `claude-code/<type>s/<name>.md`
- Tracks: agents, hooks, skills, tools
- Also logs to `journal/creations/`

## Best Practices

### Creating Notes
1. Choose the appropriate category
2. Use descriptive titles
3. Add relevant tags immediately
4. Link to related notes when obvious

### Updating Notes
1. Update the `updated` date (done automatically by scripts)
2. Add new related links as connections emerge
3. Keep descriptions current

### Searching
1. Start broad, narrow with `--title`, `--content`, or `--tag`
2. Use `--category` to focus on specific areas
3. Check related notes for additional context

### Organization
1. Use consistent naming within categories
2. Archive rather than delete
3. Maintain bidirectional links

## Integration with Workflows

### After Completing Features
When finishing a feature or fix:
1. Ensure commit is captured
2. Add/update project documentation
3. Link new notes to project README

### When Learning Technologies
1. Create note in `technologies/`
2. Link to projects that use it
3. Add code snippets as needed

### For Ideas and Experiments
1. Start in `ideas/`
2. Move to `projects/` when starting implementation
3. Archive if abandoned

## Additional Resources

### Reference Files
- **`references/frontmatter-spec.md`** - Detailed frontmatter specification

### Configuration
- Config: `~/.claude/obsidian-vault.json`
- Vault path: `~/guerra_vault`
