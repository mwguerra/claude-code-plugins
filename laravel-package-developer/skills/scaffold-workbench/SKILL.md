---
description: Add Orchestra Workbench (testbench.yaml + workbench/) to an existing Laravel package
allowed-tools: Bash(python3:*), Bash(composer:*), Write, Read, Glob
---

# Workbench Scaffold Skill

Adds Orchestra Workbench to an existing Laravel package for interactive development.

## Usage

When the user wants to add workbench to an existing package:

```bash
python3 ${SKILL_DIR}/scripts/scaffold_workbench.py <vendor/package-name> [options]
```

## Options

- `--project-root` - Specify project root directory

## Examples

```bash
python3 ${SKILL_DIR}/scripts/scaffold_workbench.py mwguerra/my-package
```

## What Gets Created

### Files

1. **testbench.yaml** — Testbench + Workbench configuration
2. **workbench/app/Providers/WorkbenchServiceProvider.php** — Workbench provider
3. **workbench/database/seeders/DatabaseSeeder.php** — Workbench seeder
4. **workbench/resources/views/welcome.blade.php** — Welcome page
5. **workbench/routes/web.php** — Workbench routes

### Directories

- `workbench/app/Models/`
- `workbench/database/factories/`
- `workbench/database/migrations/`

### composer.json Updates

Adds workbench autoload namespaces and serve/build scripts.

## Using Workbench

```bash
cd packages/vendor/package-name
composer update
composer serve
```

This starts a real Laravel application at `http://127.0.0.1:8000` with your package loaded, powered by [Orchestra Workbench](https://packages.tools/workbench).

## Testbench vs Workbench

- **Testbench** = automated testing framework (boots Laravel for PHPUnit/Pest tests)
- **Workbench** = interactive development environment (serves a real Laravel app)
- Both share `testbench.yaml` for configuration
- The `WithWorkbench` trait in TestCase bridges both worlds
