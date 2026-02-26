---
description: Validate and prepare a Laravel package for Packagist publishing
argument-hint: <vendor/package-name>
allowed-tools: Bash(composer:*), Bash(php:*), Bash(vendor/bin/pest:*), Bash(cd:*), Read, Write, Edit, Glob, Grep
---

# Publish Package

Validate and prepare a Laravel package for Packagist publishing.

## Input Format

Specify the package: `vendor/package-name`

## Process

### 1. Composer Validation

```bash
cd packages/vendor/package-name
composer validate --strict
```

Checks:
- Valid composer.json schema
- Required fields: name, description, license, authors
- Autoloading configuration
- Package discovery configuration

### 2. Required Files Check

Verify these files exist:
- `composer.json`
- `LICENSE`
- `README.md`
- `.gitignore`
- `.gitattributes`
- `src/` directory with ServiceProvider
- `config/` directory (if applicable)

### 3. .gitattributes Generation

Ensure `.gitattributes` excludes non-essential files from distribution:

```
/.github            export-ignore
/tests              export-ignore
/workbench          export-ignore
.editorconfig       export-ignore
.gitattributes      export-ignore
.gitignore          export-ignore
phpunit.xml         export-ignore
testbench.yaml      export-ignore
CHANGELOG.md        export-ignore
```

### 4. Test Verification

```bash
cd packages/vendor/package-name
composer install
vendor/bin/pest
```

All tests must pass before publishing.

### 5. Version Check

- Verify version tag convention (semver)
- Suggest creating a git tag if none exists

## Publishing Checklist

```
Publish Readiness: vendor/package-name
========================================

[ok] composer.json valid
[ok] LICENSE present
[ok] README.md present
[ok] .gitattributes configured
[ok] ServiceProvider found
[ok] Package discovery configured
[ok] All tests passing (5 passed)
[ok] No composer.lock in repo
[!!] No git tag found — create one with: git tag v1.0.0

Ready to publish!

Next steps:
  1. Push to GitHub: git push origin main --tags
  2. Submit to Packagist: https://packagist.org/packages/submit
  3. Enter your repository URL
```

## Examples

```
/laravel-package-developer:publish mwguerra/my-package
```
