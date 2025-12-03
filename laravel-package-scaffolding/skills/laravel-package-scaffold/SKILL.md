---
name: laravel-package-scaffold
description: |
  Creates a new Laravel Composer package skeleton. Use when user wants to:
  - Create a new Laravel package
  - Scaffold a Laravel package structure
  - Generate a package skeleton with ServiceProvider and test command
  
  Trigger: "create package", "scaffold package", "new laravel package", "package skeleton"
  Input format: namespace/package-name (e.g., mwguerra/my-package)
---

# Laravel Package Scaffold

Creates a complete Laravel package skeleton with proper structure, ServiceProvider, and test command.

## Usage

Run the scaffold script with namespace/package-name:

```bash
python3 scripts/scaffold_laravel_package.py <namespace/package-name>
```

Example:
```bash
python3 scripts/scaffold_laravel_package.py mwguerra/filament-pages
```

## What Gets Created

### Directory Structure
```
packages/
└── {namespace}/
    └── {package-name}/
        ├── composer.json
        └── src/
            ├── {PackageName}ServiceProvider.php
            └── Commands/
                └── TestCommand.php
```

### Files Generated

1. **composer.json** - Package definition with:
   - PSR-4 autoloading
   - Laravel service provider auto-discovery
   - PHP ^8.2 and Laravel framework dependencies

2. **ServiceProvider** - Registers the test command

3. **TestCommand** - Artisan command `{package-name}:test` to verify installation

### Project Updates

The script automatically updates the project's `composer.json`:
- Adds path repository with symlink option
- Adds package to require as `@dev`

## After Running

Execute these commands to complete setup:

```bash
composer update
php artisan package-name:test
```

## Script Location

`scripts/scaffold_laravel_package.py` - Main scaffold script
