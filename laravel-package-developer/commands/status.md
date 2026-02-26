---
description: Check the health, structure, and integration status of a Laravel package
argument-hint: <vendor/package-name>
allowed-tools: Bash(composer:*), Bash(php:*), Read, Glob, Grep
---

# Package Status

Display comprehensive status information about a Laravel package.

## Input Format

Specify the package: `vendor/package-name`

## Information Checked

### Package Identity
- Name and version from composer.json
- Description, license, authors

### Structure Analysis
- Required files: composer.json, ServiceProvider, config, testbench.yaml
- Optional files: routes, views, migrations, commands
- workbench/ directory presence

### Dependencies
- PHP version requirement (expected: ^8.3)
- Laravel version compatibility (expected: ^12.0)
- Testbench version (expected: ^10.0)
- Pest version (expected: ^4.0)

### Testing Status
- Pest/PHPUnit presence
- Test file count (Unit, Feature, Browser)
- phpunit.xml configuration
- tests/TestCase.php with WithWorkbench trait

### Workbench Status
- testbench.yaml presence and validity
- workbench/ directory and contents
- WorkbenchServiceProvider presence

### Host Integration
- Package in project's composer.json?
- Path repository configured?
- Is it installed (symlinked)?

## Output Format

```
Package Status: vendor/package-name
======================================

Structure:
  [ok] composer.json
  [ok] src/PackageNameServiceProvider.php
  [ok] config/package-name.php
  [ok] testbench.yaml
  [ok] workbench/
  [ok] tests/
  [!!] routes/ (missing)

Dependencies:
  [ok] php: ^8.3
  [ok] illuminate/support: ^12.0
  [ok] orchestra/testbench: ^10.0
  [ok] pestphp/pest: ^4.0

Testing:
  [ok] Pest v4 configured
  [ok] WithWorkbench trait in TestCase
  Tests: 5 unit, 0 feature

Integration:
  [ok] Path repository configured
  [ok] Package in require block
  [ok] Symlink active
```

## Examples

```
/laravel-package-developer:status mwguerra/my-package
```
