---
description: Create a new Laravel package skeleton with ServiceProvider, Facade, Config, and test setup
argument-hint: <vendor/package-name> [--with-pest] [--with-filament]
allowed-tools: Bash(python3:*), Bash(php:*), Bash(composer:*), Read, Write, Glob
---

# Create Laravel Package

Create a new Laravel package with a complete directory structure.

## Input Format

The package name should be in the format: `vendor/package-name`

Example: `mwguerra/my-awesome-package`

## Options

- `--with-pest` - Include PestPHP testing setup
- `--with-filament` - Include Filament plugin structure

## Process

1. Parse the vendor and package name from the input
2. Create the package directory structure under `packages/vendor/package-name/`
3. Generate the following files:
   - `composer.json` with proper PSR-4 autoloading
   - `src/{PackageName}ServiceProvider.php`
   - `src/Facades/{PackageName}.php` (optional Facade)
   - `config/{package-name}.php` (config file)
   - `README.md` with usage instructions
   - `.gitignore`
4. If `--with-pest` is specified, also set up PestPHP testing
5. Update the project's `composer.json` with path repository

## After Creation

Run these commands to complete setup:

```bash
composer update
php artisan vendor:publish --tag={package-name}-config
php artisan {package-name}:test
```

## Directory Structure Created

```
packages/
└── vendor/
    └── package-name/
        ├── composer.json
        ├── README.md
        ├── .gitignore
        ├── config/
        │   └── package-name.php
        └── src/
            ├── PackageNameServiceProvider.php
            ├── Facades/
            │   └── PackageName.php
            └── Commands/
                └── TestCommand.php
```
