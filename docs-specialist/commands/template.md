---
description: List, view, and apply documentation templates
allowed-tools: Read, Write, Glob
argument-hint: "<list | show | use> [template-name] [--output path]"
---

# Documentation Templates

List, view, and apply documentation templates.

## Syntax

```
/docs-specialist:template <action> [options]
```

## Actions

- `list` - List all available templates
- `show` - View template details and structure
- `use` - Apply a template to generate documentation

---

## list

List all available documentation templates.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--detailed` | No | Show template structure and variables |

### Output

```
Documentation Templates
=======================

Built-in Templates:
───────────────────
  readme          Project README with standard sections
  api-endpoint    REST API endpoint documentation
  component       UI component (React/Vue/Livewire) docs
  model           Database model/entity documentation
  service         Service class documentation
  guide           How-to guide or tutorial
  architecture    Architecture decision record (ADR)
  changelog       Release changelog entry

Use /docs-specialist:template show <name> for details
Use /docs-specialist:template use <name> to apply
```

### Examples

```bash
# List all templates
/docs-specialist:template list

# List with structure details
/docs-specialist:template list --detailed
```

---

## show

View template details, structure, and available variables.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<name>` | Yes | Template name to show |

### Output Example

```
Template: api-endpoint
======================

Description:
  REST API endpoint documentation with request/response examples

Sections:
  1. Title & Description
  2. Endpoint Details (method, path, auth)
  3. Request Parameters
  4. Request Body Schema
  5. Response Schema
  6. Code Examples
  7. Error Responses
  8. Related Endpoints

Variables:
  {{endpoint_path}}     - The API route path
  {{http_method}}       - GET, POST, PUT, DELETE, etc.
  {{description}}       - Brief description of what it does
  {{auth_required}}     - Whether authentication is needed
  {{parameters}}        - List of URL/query parameters
  {{request_body}}      - Request body schema
  {{response_body}}     - Response body schema
  {{examples}}          - Code examples (auto-generated or custom)

Preview:
───────────────────────────────────────────────
# {{http_method}} {{endpoint_path}}

{{description}}

## Authentication

{{#if auth_required}}
Requires authentication. Include bearer token in header.
{{else}}
No authentication required.
{{/if}}

## Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
{{#each parameters}}
| {{name}} | {{type}} | {{required}} | {{description}} |
{{/each}}

## Request Body

\`\`\`json
{{request_body}}
\`\`\`

## Response

\`\`\`json
{{response_body}}
\`\`\`

## Examples

{{examples}}
───────────────────────────────────────────────
```

### Examples

```bash
# Show readme template
/docs-specialist:template show readme

# Show API endpoint template
/docs-specialist:template show api-endpoint

# Show component template
/docs-specialist:template show component
```

---

## use

Apply a template to generate documentation.

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<template>` | Yes | Template name to apply |
| `[target]` | No | File or path to document (for code-based templates) |
| `--output=<path>` | No | Output file path |
| `--vars=<json>` | No | Template variables as JSON string |
| `--interactive` | No | Prompt for missing variables (default if no target) |

### Process

1. **Load Template**
   - Get template structure and variables

2. **Gather Variables**
   - If `[target]` provided: analyze code to extract variables
   - If `--vars` provided: use provided values
   - If `--interactive`: prompt for each variable
   - Merge all sources (code analysis > provided > prompted)

3. **Generate Content**
   - Apply variables to template
   - Format according to style
   - Add code examples if applicable

4. **Output**
   - Write to `--output` path or suggest location
   - Show preview if interactive

### Examples

```bash
# Apply readme template interactively
/docs-specialist:template use readme

# Generate API doc for a specific endpoint
/docs-specialist:template use api-endpoint app/Http/Controllers/UserController.php@store

# Generate component docs
/docs-specialist:template use component src/components/Button.tsx

# Specify output location
/docs-specialist:template use model app/Models/User.php --output=docs/models/user.md

# Provide variables directly
/docs-specialist:template use guide --vars='{"title": "Getting Started", "level": "beginner"}'

# Generate architecture decision record
/docs-specialist:template use architecture --interactive
```

---

## Built-in Templates

### readme

Project README with standard sections.

**Structure:**
```markdown
# Project Name

Brief description of the project.

## Features

- Feature 1
- Feature 2

## Installation

\`\`\`bash
# Installation commands
\`\`\`

## Usage

\`\`\`bash
# Usage examples
\`\`\`

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| VAR_1 | Description | value |

## Contributing

Instructions for contributors.

## License

License information.
```

**Variables:** `project_name`, `description`, `features`, `installation`, `usage`, `config_vars`, `license`

---

### api-endpoint

REST API endpoint documentation.

**Structure:**
```markdown
# METHOD /path/to/endpoint

Brief description.

## Authentication

Required/Optional. Token type.

## Parameters

| Name | Type | In | Required | Description |
|------|------|-------|----------|-------------|
| id | string | path | Yes | Resource ID |

## Request Body

\`\`\`json
{
  "field": "value"
}
\`\`\`

## Response

### Success (200)

\`\`\`json
{
  "data": { ... }
}
\`\`\`

### Errors

| Code | Description |
|------|-------------|
| 400 | Bad request |
| 404 | Not found |

## Examples

### cURL

\`\`\`bash
curl -X METHOD https://api.example.com/path
\`\`\`

## Related

- [Other Endpoint](./other.md)
```

**Variables:** `http_method`, `endpoint_path`, `description`, `auth_required`, `auth_type`, `parameters`, `request_body`, `response_body`, `error_codes`, `examples`

---

### component

UI component documentation (React/Vue/Livewire).

**Structure:**
```markdown
# ComponentName

Brief description of the component.

## Usage

\`\`\`jsx
import { ComponentName } from './ComponentName';

<ComponentName prop="value" />
\`\`\`

## Props

| Prop | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| name | string | - | Yes | Description |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| onChange | value: string | Fired when... |

## Slots / Children

| Slot | Description |
|------|-------------|
| default | Main content |

## Examples

### Basic Usage

\`\`\`jsx
<ComponentName>Content</ComponentName>
\`\`\`

### With Options

\`\`\`jsx
<ComponentName variant="primary" size="lg">
  Content
</ComponentName>
\`\`\`

## Accessibility

- ARIA attributes
- Keyboard navigation

## Related

- [Similar Component](./similar.md)
```

**Variables:** `component_name`, `description`, `framework`, `props`, `events`, `slots`, `examples`, `accessibility`

---

### model

Database model/entity documentation.

**Structure:**
```markdown
# ModelName

Brief description of what this model represents.

## Table

`table_name`

## Properties

| Property | Type | Nullable | Default | Description |
|----------|------|----------|---------|-------------|
| id | bigint | No | auto | Primary key |
| name | string | No | - | User's name |

## Relationships

| Relationship | Type | Model | Foreign Key |
|--------------|------|-------|-------------|
| posts | hasMany | Post | user_id |
| profile | hasOne | Profile | user_id |

## Scopes

| Scope | Description | Example |
|-------|-------------|---------|
| active() | Only active records | `User::active()->get()` |

## Accessors & Mutators

| Attribute | Type | Description |
|-----------|------|-------------|
| full_name | accessor | First + last name |

## Validation Rules

\`\`\`php
[
    'name' => 'required|string|max:255',
    'email' => 'required|email|unique:users',
]
\`\`\`

## Events

| Event | Description |
|-------|-------------|
| creating | Before record is created |
| created | After record is created |

## Example Usage

\`\`\`php
// Create
$user = User::create(['name' => 'John']);

// Query
$users = User::active()->where('role', 'admin')->get();

// Relationships
$posts = $user->posts;
\`\`\`
```

**Variables:** `model_name`, `table_name`, `description`, `properties`, `relationships`, `scopes`, `accessors`, `validation`, `events`

---

### service

Service class documentation.

**Structure:**
```markdown
# ServiceName

Brief description of the service's purpose.

## Dependencies

| Dependency | Purpose |
|------------|---------|
| Repository | Data access |
| CacheService | Caching |

## Methods

### methodName

Description of what this method does.

**Signature:**
\`\`\`php
public function methodName(Type $param): ReturnType
\`\`\`

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| $param | Type | What it's for |

**Returns:** `ReturnType` - Description

**Throws:**
- `ExceptionType` - When condition

**Example:**
\`\`\`php
$result = $service->methodName($value);
\`\`\`

## Configuration

| Config Key | Description | Default |
|------------|-------------|---------|
| services.name.option | What it does | value |

## Events Dispatched

| Event | When |
|-------|------|
| ServiceEvent | After action |
```

**Variables:** `service_name`, `description`, `dependencies`, `methods`, `config_options`, `events`

---

### guide

How-to guide or tutorial.

**Structure:**
```markdown
# How to [Do Something]

Brief description of what this guide covers.

## Prerequisites

Before you begin, ensure you have:

- [ ] Requirement 1
- [ ] Requirement 2

## Overview

Brief explanation of the process.

## Steps

### Step 1: First Thing

Explanation of what to do.

\`\`\`bash
# Commands or code
\`\`\`

Expected result or output.

### Step 2: Second Thing

Continue with next step...

## Verification

How to verify it worked:

\`\`\`bash
# Verification command
\`\`\`

## Troubleshooting

### Common Issue 1

**Symptom:** What you see
**Cause:** Why it happens
**Solution:** How to fix it

## Next Steps

- [Related Guide 1](./guide1.md)
- [Related Guide 2](./guide2.md)

## Related Resources

- [External Link](https://example.com)
```

**Variables:** `title`, `description`, `prerequisites`, `steps`, `verification`, `troubleshooting`, `next_steps`

---

### architecture

Architecture Decision Record (ADR).

**Structure:**
```markdown
# ADR-001: Decision Title

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Deprecated | Superseded
**Deciders:** Names of people involved

## Context

What is the issue that we're seeing that is motivating this decision?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

### Positive

- Benefit 1
- Benefit 2

### Negative

- Drawback 1
- Drawback 2

### Neutral

- Side effect 1

## Alternatives Considered

### Alternative 1

Description and why it was rejected.

### Alternative 2

Description and why it was rejected.

## Related

- [ADR-000: Previous Decision](./adr-000.md)
- [External Reference](https://example.com)
```

**Variables:** `adr_number`, `title`, `date`, `status`, `deciders`, `context`, `decision`, `consequences`, `alternatives`

---

### changelog

Release changelog entry.

**Structure:**
```markdown
## [Version] - YYYY-MM-DD

### Added

- New feature 1
- New feature 2

### Changed

- Changed behavior 1
- Updated dependency X to version Y

### Deprecated

- Feature X (will be removed in version Y)

### Removed

- Removed feature 1

### Fixed

- Fixed bug 1 (#123)
- Fixed bug 2 (#456)

### Security

- Security fix 1
```

**Variables:** `version`, `date`, `added`, `changed`, `deprecated`, `removed`, `fixed`, `security`

---

## Notes

- Templates are guidelines - customize output as needed
- Code analysis extracts as many variables as possible automatically
- Use `--interactive` when variables can't be inferred
- Templates follow common documentation standards
