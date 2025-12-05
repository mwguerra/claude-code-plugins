# Example Templates

## Global Example Defaults

Example defaults are configured in `.article_writer/settings.json`. These provide default values for each example type that can be overridden per-article.

### Default Settings Structure

```json
{
  "example_defaults": {
    "code": {
      "technologies": ["Laravel 12", "Pest 4", "SQLite"],
      "has_tests": true,
      "path": "code/",
      "run_instructions": "composer install && ...",
      "setup_commands": ["composer install", "..."],
      "test_command": "php artisan test",
      "file_structure": ["app/", "tests/", "..."]
    },
    "document": { ... },
    "diagram": { ... },
    ...
  }
}
```

### How Defaults Are Merged

When creating an example, the system:

1. Reads the article's `example.type` (e.g., `code`)
2. Loads defaults for that type from `settings.json`
3. Merges with article-specific example values
4. **Article values always override defaults**

Example:

```
settings.json (defaults)          article_tasks.json (specific)
─────────────────────────         ─────────────────────────────
code:                             example:
  technologies:                     type: "code"
    - Laravel 12                    technologies:      ← OVERRIDES
    - Pest 4                          - Laravel 11
    - SQLite                          - MySQL
  has_tests: true                   description: "..." ← ADDS
  run_instructions: "..."
                                  
Result:
  type: "code"
  technologies: ["Laravel 11", "MySQL"]  ← from article
  has_tests: true                        ← from defaults
  run_instructions: "..."                ← from defaults
  description: "..."                     ← from article
```

### Customizing Defaults

Edit `.article_writer/settings.json` to change defaults:

```json
{
  "example_defaults": {
    "code": {
      "technologies": ["Laravel 12", "Pest 4", "PostgreSQL"],
      "has_tests": true,
      "test_command": "vendor/bin/pest"
    }
  }
}
```

### Per-Article Overrides

Override any default in the article task:

```json
{
  "id": 1,
  "title": "Legacy App Migration",
  "example": {
    "type": "code",
    "technologies": ["Laravel 10", "PHPUnit", "MySQL"],
    "has_tests": true,
    "run_instructions": "Custom setup instructions..."
  }
}
```

## Laravel Project (Default)

For Laravel-related articles, create a minimal project:

```
code/
├── app/
│   ├── Http/
│   │   └── Controllers/
│   │       └── ExampleController.php
│   ├── Models/
│   │   └── Example.php
│   └── Providers/
│       └── AppServiceProvider.php
├── database/
│   ├── migrations/
│   │   └── 2025_01_15_000000_create_examples_table.php
│   └── seeders/
│       └── ExampleSeeder.php
├── routes/
│   ├── api.php
│   └── web.php
├── tests/
│   └── Feature/
│       └── ExampleTest.php
├── .env.example
├── composer.json
└── README.md
```

### composer.json (Minimal)

```json
{
    "name": "example/article-demo",
    "type": "project",
    "require": {
        "php": "^8.2",
        "laravel/framework": "^11.0"
    },
    "require-dev": {
        "pestphp/pest": "^3.0",
        "pestphp/pest-plugin-laravel": "^3.0"
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/"
        }
    },
    "scripts": {
        "test": "pest"
    }
}
```

### .env.example (SQLite)

```env
APP_NAME="Article Example"
APP_ENV=local
APP_KEY=
APP_DEBUG=true

DB_CONNECTION=sqlite
DB_DATABASE=database/database.sqlite
```

### Pest Test Template

```php
<?php
// tests/Feature/ExampleTest.php
// ARTICLE: [Article Title]
// SECTION: [Relevant Section]

use App\Models\Example;

describe('Example Feature', function () {
    
    beforeEach(function () {
        // Setup for each test
    });

    it('demonstrates the main concept', function () {
        // Arrange
        $example = Example::factory()->create();
        
        // Act
        $result = $example->someMethod();
        
        // Assert
        expect($result)->toBeTrue();
    });

    it('handles edge case', function () {
        // Test edge case mentioned in article
    });

    it('shows error handling', function () {
        // Test error scenario
    });
});
```

## Node.js Project (Minimal)

```
code/
├── src/
│   └── index.js
├── tests/
│   └── example.test.js
├── package.json
└── README.md
```

### package.json

```json
{
  "name": "article-example",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "node src/index.js",
    "test": "node --test tests/"
  },
  "devDependencies": {}
}
```

## Docker/DevOps Example

```
code/
├── docker/
│   ├── Dockerfile
│   └── nginx.conf
├── docker-compose.yml
├── scripts/
│   ├── setup.sh
│   └── deploy.sh
└── README.md
```

### docker-compose.yml Template

```yaml
# ARTICLE: [Article Title]
# Demonstrates: [What this shows]

services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8080:80"
    volumes:
      - ./src:/var/www/html
    # See article section: "[Section Name]"
```

## Document/Template Example

For non-code articles:

```
code/
├── templates/
│   ├── template-1.md
│   └── template-2.md
├── examples/
│   ├── filled-example-1.md
│   └── filled-example-2.md
└── README.md
```

### Project Plan Template

```markdown
# Project Plan: [Project Name]

<!-- ARTICLE: [Article Title] -->
<!-- This template demonstrates concepts from the article -->

## 1. Project Overview

**Objective**: [Clear statement of what the project achieves]

**Scope**: 
- In scope: [Items]
- Out of scope: [Items]

## 2. Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Planning | 1 week | Requirements doc |
| Development | 4 weeks | MVP |
| Testing | 1 week | Test report |

## 3. Resources

[Resource allocation as discussed in article section X]

## 4. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk 1] | High | [Mitigation] |
```

## README Template for Examples

```markdown
# Example: [Topic Name]

> Demonstrates [concept] from the article "[Article Title]"

## What This Shows

- [Key concept 1]
- [Key concept 2]
- [Key concept 3]

## Requirements

- [Requirement 1]
- [Requirement 2]

## Quick Start

\`\`\`bash
# Install dependencies
composer install  # or npm install

# Setup
cp .env.example .env
php artisan key:generate

# Run migrations (SQLite)
touch database/database.sqlite
php artisan migrate --seed

# Run tests
php artisan test
\`\`\`

## Project Structure

| File/Folder | Purpose |
|-------------|---------|
| `app/Models/` | Eloquent models demonstrating [concept] |
| `tests/Feature/` | Tests covering [scenarios] |

## Key Code Sections

### [Concept 1]

See `app/Services/ExampleService.php`:
- Lines 10-25: [What it shows]

### [Concept 2]

See `app/Http/Controllers/ExampleController.php`:
- Lines 30-45: [What it shows]

## Running the Example

\`\`\`bash
# Start the server
php artisan serve

# In another terminal, test the endpoint
curl http://localhost:8000/api/example
\`\`\`

## Tests

The example includes [N] tests:

1. `tests/Feature/ExampleTest.php`
   - `it demonstrates the main concept` - [What it tests]
   - `it handles errors gracefully` - [What it tests]

## Article Reference

This example accompanies:
- **Article**: [Title]
- **Author**: [Author Name]
- **Main Sections**: [List relevant sections]
```

## Comment Styles

### PHP/Laravel

```php
<?php
// ===========================================
// ARTICLE: [Article Title]
// SECTION: [Section Name]
// ===========================================

/**
 * Demonstrates [concept].
 * 
 * See article section "[Section Name]" for full explanation.
 */
class ExampleClass
{
    // This implements the pattern discussed in "Pattern Overview"
    public function exampleMethod(): void
    {
        // Step 1: [Brief description]
        // (See article for detailed explanation)
    }
}
```

### JavaScript

```javascript
/**
 * ARTICLE: [Article Title]
 * SECTION: [Section Name]
 * 
 * Demonstrates [concept] as explained in the article.
 */

// See article section: "Implementation Details"
function exampleFunction() {
    // Implementation following article guidelines
}
```

### YAML/Config

```yaml
# ===========================================
# ARTICLE: [Article Title]
# SECTION: [Section Name]
# ===========================================

# This configuration demonstrates [concept]
# See article for full explanation of each option

setting:
  option: value  # Explained in "Configuration Options" section
```

## Checklist for Examples

Before finalizing:

- [ ] Example is minimal (no unnecessary code)
- [ ] Example is complete (runs without errors)
- [ ] Example uses SQLite (for database examples)
- [ ] Example includes tests (Pest for PHP)
- [ ] Comments reference article sections
- [ ] README explains how to run
- [ ] Key files are documented
- [ ] Example matches code snippets in article
