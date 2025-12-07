---
description: View and manage global settings including example defaults for each example type
allowed-tools: Bash(bun:*)
argument-hint: <show [type] | set <path> <value> | reset | reset-type <type>>
---

# Settings - Global Configuration

Manage global settings for the article-writer plugin.

**File location:** `.article_writer/settings.json`
**Schema:** `.article_writer/schemas/settings.schema.json`
**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writersettings)

## Commands

### Show all settings

```bash
/article-writer:settings show
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings`

Shows summary table of all example types with technologies and test settings.

### Show specific example type

```bash
/article-writer:settings show code
/article-writer:settings show document
/article-writer:settings show diagram
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings <type>`

Shows full details: technologies, scaffold command, setup commands, run instructions, file structure.

### Set a value

```bash
/article-writer:settings set <path> <value>
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts set <path> <value>`

**Common paths:**

| Path | Example Value |
|------|---------------|
| `code.technologies` | `'["Laravel 11", "Pest 3", "SQLite"]'` |
| `code.has_tests` | `true` |
| `code.scaffold_command` | `"composer create-project laravel/laravel:^11.0 code"` |
| `code.run_command` | `"php artisan serve"` |
| `code.test_command` | `"vendor/bin/pest"` |
| `document.technologies` | `'["Markdown", "AsciiDoc"]'` |

### Reset all settings

```bash
/article-writer:settings reset
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts reset`

Resets all settings to plugin defaults.

### Reset one example type

```bash
/article-writer:settings reset-type code
/article-writer:settings reset-type document
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts reset-type <type>`

## Example Types

| Type | Default Technologies | Has Tests | Use For |
|------|---------------------|-----------|---------|
| `code` | Laravel 12, Pest 4, SQLite | Yes | Full application examples |
| `document` | Markdown | No | Templates, guides |
| `diagram` | Mermaid | No | Architecture diagrams |
| `template` | Markdown, YAML | No | Reusable file templates |
| `dataset` | JSON, CSV, SQL | No | Sample data + schemas |
| `config` | Docker, YAML | No | Docker/infrastructure |
| `script` | Bash, Shell | No | Automation scripts |
| `spreadsheet` | Excel, CSV | No | Spreadsheets with formulas |
| `other` | (none) | No | Anything else |

## Configurable Fields Per Type

| Field | Type | Description |
|-------|------|-------------|
| `technologies` | array | Default tech stack |
| `has_tests` | boolean | Include tests by default |
| `path` | string | Default example folder |
| `scaffold_command` | string | Command to create base project |
| `post_scaffold` | array | Commands after scaffolding |
| `setup_commands` | array | User setup commands |
| `run_command` | string | Command to run example |
| `run_instructions` | string | Full run instructions |
| `test_command` | string | Command to run tests |
| `file_structure` | array | Expected files/folders |
| `env_setup` | object | Environment variables |
| `notes` | string | Notes for this type |

## How Defaults Are Merged

When creating an example:

1. System reads article's `example.type` (e.g., "code")
2. Loads defaults for that type from `settings.json`
3. Merges with article-specific values
4. **Article values always override defaults**

```
settings.json defaults    +    article example    =    final example
──────────────────────         ────────────────        ─────────────
technologies: [Laravel 12]     technologies: [L11]     technologies: [L11]
has_tests: true                (not specified)         has_tests: true
run_instructions: "..."        run_instructions: "X"   run_instructions: "X"
```

## Examples

### View code defaults

```bash
/article-writer:settings show code
```

### Change Laravel version

```bash
/article-writer:settings set code.technologies '["Laravel 11", "Pest 3", "SQLite"]'
```

### Use PostgreSQL instead of SQLite

```bash
/article-writer:settings set code.technologies '["Laravel 12", "Pest 4", "PostgreSQL"]'
```

### Disable tests by default

```bash
/article-writer:settings set code.has_tests false
```

### Custom scaffold command

```bash
/article-writer:settings set code.scaffold_command "composer create-project laravel/laravel:^11.0 code"
```

### Reset code defaults only

```bash
/article-writer:settings reset-type code
```
