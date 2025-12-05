---
description: View and manage global settings including example defaults for each example type
allowed-tools: Bash(bun:*)
argument-hint: [show | defaults | set <type> <key> <value>]
---

# Settings - Global Configuration

Manage global settings for the article-writer plugin.

## Usage

```bash
# Show all settings
/article-writer:settings show

# Show example defaults only
/article-writer:settings defaults

# Show defaults for a specific type
/article-writer:settings defaults code
/article-writer:settings defaults document

# Update a default value
/article-writer:settings set code technologies '["Laravel 12", "Pest 4", "MySQL"]'
/article-writer:settings set code has_tests true
/article-writer:settings set document technologies '["Markdown", "AsciiDoc"]'
```

## Example Defaults

Global defaults are applied to all examples of a given type unless overridden in the article task.

### Default Types

| Type | Default Technologies | Has Tests |
|------|---------------------|-----------|
| `code` | Laravel 12, Pest 4, SQLite | Yes |
| `document` | Markdown | No |
| `diagram` | Mermaid | No |
| `template` | Markdown, YAML | No |
| `dataset` | JSON, CSV | No |
| `config` | Docker, YAML | No |
| `other` | (none) | No |

### Configurable Fields

Each example type can have these defaults:

| Field | Type | Description |
|-------|------|-------------|
| `technologies` | array | Default tech stack |
| `has_tests` | boolean | Include tests by default |
| `path` | string | Default example folder |
| `run_instructions` | string | How to run the example |
| `setup_commands` | array | Setup command list |
| `test_command` | string | Command to run tests |
| `file_structure` | array | Expected files/folders |
| `template_repo` | string | Git repo to clone (optional) |
| `notes` | string | Notes for this type |

## How Defaults Are Merged

When creating an example:

1. System reads article's `example.type`
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

## File Location

Settings are stored in `.article_writer/settings.json`

## Examples

### Change default PHP framework version

```bash
/article-writer:settings set code technologies '["Laravel 11", "Pest 3", "SQLite"]'
```

### Use PostgreSQL instead of SQLite

```bash
/article-writer:settings set code technologies '["Laravel 12", "Pest 4", "PostgreSQL"]'
```

### Disable tests by default for document examples

```bash
/article-writer:settings set document has_tests false
```

### Add custom run instructions

```bash
/article-writer:settings set code run_instructions "make setup && make test"
```
