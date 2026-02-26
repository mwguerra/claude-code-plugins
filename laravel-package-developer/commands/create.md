---
description: Scaffold a complete new Laravel package with Pest v4, Testbench v10, and Workbench
argument-hint: <vendor/package-name> [--with-routes] [--with-views] [--with-migrations] [--with-commands] [--with-playwright] [--all]
allowed-tools: Bash(python3:*), Bash(php:*), Bash(composer:*), Read, Write, Glob
---

# Create Laravel Package

Scaffold a complete new package under `packages/vendor/package-name/`.

## Input Format

The package name must be in the format: `vendor/package-name`

Example: `mwguerra/my-awesome-package`

## Options

- `--with-routes` - Include route files (web.php, api.php)
- `--with-views` - Include views directory
- `--with-migrations` - Include database/migrations directory
- `--with-commands` - Include artisan install command
- `--with-playwright` - Include Playwright browser testing setup
- `--all` - Include routes, views, migrations, commands (NOT playwright)

## Process

1. Parse the vendor and package name from the input
2. Use the scaffold-package skill to generate the full package
3. The script always creates: composer.json, ServiceProvider, Facade, config, testbench.yaml, workbench/, tests/, phpunit.xml, .github/workflows/tests.yml, README, LICENSE, .gitignore, .gitattributes
4. Optional features are added based on flags
5. The host project's composer.json is updated with a path repository

## Technology Stack

| Dependency | Version |
|---|---|
| PHP | ^8.3 |
| illuminate/support | ^12.0 |
| orchestra/testbench | ^10.0 |
| pestphp/pest | ^4.0 |
| pestphp/pest-plugin-laravel | ^4.0 |
| orchestra/pest-plugin-testbench | ^4.0 |

## After Creation

```bash
# Install dependencies
composer update

# Run tests
cd packages/vendor/package-name
composer install
vendor/bin/pest

# Serve workbench for interactive development
composer serve
```

## Examples

### Basic package
```
/laravel-package-developer:create mwguerra/my-package
```

### Full-featured package
```
/laravel-package-developer:create mwguerra/my-package --all
```

### Full-featured with browser testing
```
/laravel-package-developer:create mwguerra/my-package --all --with-playwright
```
