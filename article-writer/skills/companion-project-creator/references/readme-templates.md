# Companion Project README Templates

## Code Companion Project (Laravel)

```markdown
# Companion Project: [Article Topic]

Complete Laravel application demonstrating [concept].

## Requirements

- PHP 8.2+
- Composer

## Quick Start

\`\`\`bash
# Install dependencies
composer install

# Setup environment
cp .env.example .env
php artisan key:generate

# Setup database (SQLite)
touch database/database.sqlite
php artisan migrate --seed

# Start the application
php artisan serve
\`\`\`

Visit **http://localhost:8000** to see the companion project in action.

## Run Tests

\`\`\`bash
php artisan test
\`\`\`

## What This Demonstrates

1. **[Concept 1]** - See `app/Models/Example.php`
2. **[Concept 2]** - See `app/Http/Controllers/ExampleController.php`
3. **[Concept 3]** - See `tests/Feature/ExampleTest.php`

## Project Structure

\`\`\`
code/
├── app/
│   ├── Http/Controllers/
│   │   └── ExampleController.php    # Main controller
│   └── Models/
│       └── Example.php              # Example model
├── database/
│   ├── migrations/
│   │   └── 2025_01_15_create_examples_table.php
│   └── seeders/
│       └── ExampleSeeder.php
├── resources/views/
│   └── examples/
│       └── index.blade.php
├── routes/
│   └── web.php                      # Routes for this example
└── tests/Feature/
    └── ExampleTest.php              # Feature tests
\`\`\`

## Key Files

| File | Purpose | Article Section |
|------|---------|-----------------|
| `app/Models/Example.php` | [Description] | "Section Name" |
| `app/Http/Controllers/ExampleController.php` | [Description] | "Section Name" |
| `tests/Feature/ExampleTest.php` | [Description] | "Section Name" |

## Try It Out

1. Start the server: `php artisan serve`
2. Open http://localhost:8000/examples
3. [Describe what to do/see]

## Article Reference

This companion project accompanies the article: **"[Article Title]"**

Author: [Author Name]
```

## Code Companion Project (Node.js)

```markdown
# Companion Project: [Article Topic]

Complete Node.js application demonstrating [concept].

## Requirements

- Node.js 18+
- npm or yarn

## Quick Start

\`\`\`bash
# Install dependencies
npm install

# Start the application
npm start
\`\`\`

Visit **http://localhost:3000** to see the companion project.

## Run Tests

\`\`\`bash
npm test
\`\`\`

## Project Structure

\`\`\`
code/
├── src/
│   ├── index.js           # Entry point
│   ├── routes/
│   │   └── example.js     # Example routes
│   └── controllers/
│       └── exampleController.js
├── tests/
│   └── example.test.js    # Tests
├── package.json
└── README.md
\`\`\`

## Article Reference

This companion project accompanies: **"[Article Title]"**
```

## Document Companion Project

```markdown
# Document Templates: [Topic]

Complete document templates for [purpose].

## Contents

### Templates (Empty)
- `templates/[name]-template.md` - [Description]

### Examples (Filled)
- `examples/[name]-example.md` - [Description]

## How to Use

1. Copy the template you need from `templates/`
2. Rename it for your project
3. Fill in the sections (look for `[PLACEHOLDER]` markers)
4. Refer to the examples in `examples/` for guidance

## Template: [Name]

**Purpose:** [What this template is for]

**Sections:**
1. [Section 1] - [Purpose]
2. [Section 2] - [Purpose]
3. [Section 3] - [Purpose]

**When to use:** [Guidance]

## Article Reference

These templates accompany: **"[Article Title]"**
```

## Diagram Companion Project

```markdown
# Diagrams: [Topic]

Mermaid diagrams illustrating [concept].

## Viewing the Diagrams

These diagrams use [Mermaid](https://mermaid.js.org/) syntax. You can view them:

1. **GitHub** - Renders automatically in `.md` files
2. **VS Code** - Install "Markdown Preview Mermaid Support" extension
3. **Online** - Paste into https://mermaid.live

## Diagrams

### 1. [Diagram Name]

**File:** `diagrams/[name].mermaid`

**Purpose:** [What this diagram shows]

\`\`\`mermaid
flowchart TD
    A[Start] --> B[Process]
    B --> C[End]
\`\`\`

### 2. [Diagram Name]

**File:** `diagrams/[name].mermaid`

**Purpose:** [What this diagram shows]

## Article Reference

These diagrams accompany: **"[Article Title]"**
```

## Configuration Companion Project

```markdown
# Configuration: [Topic]

Complete Docker/configuration setup for [purpose].

## Requirements

- Docker
- Docker Compose

## Quick Start

\`\`\`bash
# Copy environment file
cp .env.example .env

# Start services
docker-compose up -d

# Check status
docker-compose ps
\`\`\`

## Services

| Service | Port | Description |
|---------|------|-------------|
| app | 8080 | [Description] |
| db | 5432 | [Description] |

## Configuration Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Service definitions |
| `docker/Dockerfile` | App container |
| `.env.example` | Environment variables |

## Customization

[Explain what can be customized and how]

## Article Reference

This configuration accompanies: **"[Article Title]"**
```

## Script Companion Project

```markdown
# Scripts: [Topic]

Executable scripts for [purpose].

## Requirements

- Bash 4+
- [Other requirements]

## Quick Start

\`\`\`bash
# Make scripts executable
chmod +x scripts/*.sh

# Run main script
./scripts/main.sh
\`\`\`

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/main.sh` | [Purpose] | `./scripts/main.sh [args]` |
| `scripts/setup.sh` | [Purpose] | `./scripts/setup.sh` |

## Usage Examples

\`\`\`bash
# Example 1
./scripts/main.sh --option value

# Example 2
./scripts/setup.sh
\`\`\`

## Article Reference

These scripts accompany: **"[Article Title]"**
```

## Dataset Companion Project

```markdown
# Dataset: [Topic]

Sample data for [purpose].

## Files

### Data Files
- `data/sample.json` - [Description]
- `data/sample.csv` - [Description]

### Schema
- `schemas/schema.json` - JSON Schema definition

## Importing the Data

### JSON
\`\`\`javascript
const data = require('./data/sample.json');
\`\`\`

### CSV
\`\`\`javascript
// Use csv-parser or similar
\`\`\`

### SQL
\`\`\`bash
# For SQLite
sqlite3 database.db < data/seed.sql
\`\`\`

## Schema

[Describe the data structure]

| Field | Type | Description |
|-------|------|-------------|
| id | integer | [Description] |
| name | string | [Description] |

## Article Reference

This dataset accompanies: **"[Article Title]"**
```
