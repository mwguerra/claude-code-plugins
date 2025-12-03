# mwguerra Claude Code Plugins

A collection of Claude Code plugins for development workflows.

## Installation

```bash
# Add the marketplace
/plugin marketplace add mwguerra/claude-code-plugins

# Browse and install plugins
/plugin
```

## Available Plugins

### technical-content

Create high-quality technical articles with full research, documentation, and quality checks.

```bash
/plugin install technical-content@mwguerra
```

**Commands:**
- `/technical-content:article <topic>` - Create a new article
- `/technical-content:voice setup` - Set up your voice profile

**Skills:**
- `technical-content` - Full article creation workflow
- `timestamp` - Cross-platform timestamp generation

## Requirements

- Claude Code
- Bun runtime (for scripts)

## After Installation

```bash
# Set up your voice profile first
/technical-content:voice setup

# Then create articles
/technical-content:article implementing rate limiting in Laravel
```

## License

MIT
