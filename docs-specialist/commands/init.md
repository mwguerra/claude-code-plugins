---
description: Initialize documentation folder structure for a project
allowed-tools: Read, Write, Glob
argument-hint: "[--check] [--structure minimal|standard|full] [--force]"
---

# Initialize Documentation Structure

Set up a recommended documentation folder structure for a project.

## Syntax

```
/docs-specialist:init [options]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--check` | No | Preview what would be created without making changes |
| `--structure=<type>` | No | Structure type: `minimal`, `standard`, `full` (default: standard) |
| `--force` | No | Overwrite existing docs folder |

## Structure Types

### minimal

Basic documentation structure for small projects.

```
docs/
├── README.md           # Documentation index
└── api.md              # API reference (if applicable)
```

### standard (default)

Recommended structure for most projects.

```
docs/
├── README.md           # Documentation index and navigation
├── api/
│   └── README.md       # API documentation overview
├── guides/
│   ├── README.md       # Guides index
│   └── getting-started.md
└── architecture/
    └── README.md       # Architecture overview
```

### full

Comprehensive structure for larger projects.

```
docs/
├── README.md           # Documentation hub
├── api/
│   ├── README.md       # API overview
│   ├── authentication.md
│   └── endpoints/
│       └── README.md   # Endpoints index
├── guides/
│   ├── README.md       # Guides index
│   ├── getting-started.md
│   ├── tutorials/
│   │   └── README.md
│   └── how-to/
│       └── README.md
├── architecture/
│   ├── README.md       # Architecture overview
│   ├── decisions/
│   │   └── README.md   # ADR index
│   └── diagrams/
│       └── README.md
├── development/
│   ├── README.md       # Developer guide
│   ├── setup.md        # Development setup
│   ├── contributing.md
│   ├── testing.md
│   └── code-style.md
└── deployment/
    ├── README.md
    └── environments.md
```

## Process

1. **Check Existing Structure**
   - Look for existing `docs/` folder
   - Identify what already exists
   - If exists and no `--force`: report and exit

2. **Analyze Project**
   - Detect project type (Laravel, Node, React, etc.)
   - Check for existing documentation files
   - Identify what documentation might be needed

3. **Create Structure**
   - Create directories
   - Generate README files with navigation
   - Add placeholder content with TODOs

4. **Report**
   - List created files
   - Suggest next steps

## Generated Content

### docs/README.md (Documentation Hub)

```markdown
# Project Documentation

Welcome to the project documentation.

## Quick Links

- [Getting Started](./guides/getting-started.md)
- [API Reference](./api/README.md)
- [Architecture](./architecture/README.md)

## Documentation Structure

| Directory | Contents |
|-----------|----------|
| `api/` | API reference documentation |
| `guides/` | User guides and tutorials |
| `architecture/` | System architecture and decisions |

## Contributing to Docs

To contribute to this documentation:

1. Follow the existing structure
2. Use markdown formatting
3. Include code examples where helpful
4. Keep content up to date with code changes

---

*Last updated: [date]*
```

### guides/getting-started.md

```markdown
# Getting Started

This guide will help you get up and running with [Project Name].

## Prerequisites

Before you begin, ensure you have:

- [ ] Prerequisite 1
- [ ] Prerequisite 2

## Installation

\`\`\`bash
# TODO: Add installation commands
\`\`\`

## Quick Start

\`\`\`bash
# TODO: Add quick start commands
\`\`\`

## Next Steps

- [Tutorial 1](./tutorials/tutorial-1.md)
- [API Reference](../api/README.md)

---

*TODO: Complete this guide based on actual project setup*
```

## Examples

```bash
# Preview what would be created
/docs-specialist:init --check

# Create standard structure (default)
/docs-specialist:init

# Create minimal structure
/docs-specialist:init --structure=minimal

# Create full structure
/docs-specialist:init --structure=full

# Recreate docs folder (overwrites existing)
/docs-specialist:init --force
```

## Output

```
Documentation Structure Created
===============================

Structure: standard
Location: ./docs/

Created:
  ✓ docs/README.md
  ✓ docs/api/README.md
  ✓ docs/guides/README.md
  ✓ docs/guides/getting-started.md
  ✓ docs/architecture/README.md

Next Steps:
  1. Edit docs/README.md with project overview
  2. Complete docs/guides/getting-started.md
  3. Run /docs-specialist:docs generate api to populate API docs
  4. Run /docs-specialist:docs status to check progress
```

## Notes

- This command creates the folder structure, not plugin configuration
- Generated files include TODO markers for content that needs completion
- Use `/docs-specialist:docs generate` to populate from code
- Existing files are not overwritten unless `--force` is used
- Tool-specific files (CLAUDE.md, .cursorrules) remain in their locations
