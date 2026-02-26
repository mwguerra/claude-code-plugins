---
description: Scaffold Laravel packages with ServiceProvider, Facade, Config, Testbench, and Workbench
allowed-tools: Bash(python3:*), Write, Read, Glob
---

# Laravel Package Scaffold Skill

Creates a complete Laravel package skeleton with Pest v4, Testbench v10, Workbench, and optional Playwright.

## Usage

When the user wants to create a Laravel package, use the scaffold script:

```bash
python3 ${SKILL_DIR}/scripts/scaffold_package.py <vendor/package-name> [options]
```

## Options

- `--with-routes` - Include route files (web.php, api.php)
- `--with-views` - Include views directory
- `--with-migrations` - Include database migrations
- `--with-commands` - Include artisan install command
- `--with-playwright` - Include Playwright browser testing
- `--all` - Include routes, views, migrations, commands (NOT playwright)
- `--project-root` - Specify project root directory

## Examples

### Basic package (with testing and workbench)
```bash
python3 ${SKILL_DIR}/scripts/scaffold_package.py mwguerra/my-package
```

### Full-featured package
```bash
python3 ${SKILL_DIR}/scripts/scaffold_package.py mwguerra/my-package --all
```

### Full-featured with Playwright
```bash
python3 ${SKILL_DIR}/scripts/scaffold_package.py mwguerra/my-package --all --with-playwright
```

## What Gets Created

### Always created
- `composer.json` — PHP 8.3, Laravel 12, Testbench 10, Pest 4
- `src/{PackageName}ServiceProvider.php` — with register/boot
- `src/{PackageName}.php` — main class
- `src/Facades/{PackageName}.php` — facade
- `config/{package-name}.php` — package config
- `lang/en/messages.php` — translations
- `testbench.yaml` — Testbench + Workbench configuration
- `workbench/` — interactive development environment
- `tests/` — Pest v4 tests with WithWorkbench trait
- `phpunit.xml` — test runner config
- `.github/workflows/tests.yml` — CI workflow
- `README.md`, `LICENSE`, `.gitignore`, `.gitattributes`

### Optional
- `routes/web.php`, `routes/api.php` (with `--with-routes`)
- `resources/views/` (with `--with-views`)
- `database/migrations/`, `database/factories/` (with `--with-migrations`)
- `src/Commands/InstallCommand.php` (with `--with-commands`)
- `playwright.config.ts`, `package.json`, `tests/Browser/` (with `--with-playwright`)

### Project Integration

The script automatically updates the host project's `composer.json`:
- Adds path repository pointing to `packages/vendor/package-name`
- Adds package to `require` block as `@dev`
- Enables symlink for development

## Key Design Decisions

1. **Testing always on** — Pest + Testbench always scaffolded, no opt-out.
2. **Workbench always on** — testbench.yaml and workbench/ always created.
3. **WithWorkbench trait** — TestCase uses `WithWorkbench` for config from testbench.yaml.
4. **No Filament** — Pure Laravel package focus.
5. **Pinned versions** — PHP 8.3, Laravel 12, Testbench 10, Pest 4.

## After Running

1. **Install dependencies**: `composer update`
2. **Run tests**: `cd packages/vendor/package-name && composer install && vendor/bin/pest`
3. **Serve workbench**: `cd packages/vendor/package-name && composer serve`
