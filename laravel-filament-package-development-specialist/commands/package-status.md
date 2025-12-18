---
description: Check the status and configuration of a Laravel/Filament package
argument-hint: <vendor/package-name>
allowed-tools: Bash(cat:*), Bash(ls:*), Bash(composer:*), Bash(php:*), Read, Glob
---

# Package Status

Display comprehensive status information about a Laravel or Filament package.

## Input Format

Specify the package: `vendor/package-name`

## Information Displayed

### Package Identity
- Name and version from composer.json
- Description
- License
- Authors

### Structure Analysis
- Directory structure verification
- Missing required files
- Extra directories/files found

### Dependencies
- PHP version requirement
- Laravel/Filament version compatibility
- Dev dependencies (testing)

### Configuration
- Service Provider registration
- Config file presence
- Facades configured
- Commands registered

### Testing Status
- PestPHP/PHPUnit presence
- Test file count
- Last test run (if available)
- Coverage configuration

### Integration Status
- Is package in project's composer.json?
- Path repository configured?
- Is it installed (symlinked)?

## Output Format

```
╔══════════════════════════════════════════════════════════════╗
║               Laravel Package Status Report                   ║
╠══════════════════════════════════════════════════════════════╣
║ Package: vendor/package-name                                  ║
║ Version: 1.0.0                                                ║
║ Path: packages/vendor/package-name                            ║
╠══════════════════════════════════════════════════════════════╣
║ Structure:                                                    ║
║   ✓ composer.json                                             ║
║   ✓ src/ServiceProvider.php                                   ║
║   ✓ config/package.php                                        ║
║   ✗ tests/ (missing)                                          ║
╠══════════════════════════════════════════════════════════════╣
║ Testing:                                                      ║
║   ✗ PestPHP not configured                                    ║
║   Run: /setup-pest-testing vendor/package-name                ║
╠══════════════════════════════════════════════════════════════╣
║ Project Integration:                                          ║
║   ✓ Path repository configured                                ║
║   ✓ Package in require block                                  ║
║   ✓ Symlink active                                            ║
╚══════════════════════════════════════════════════════════════╝
```

## Follow-up Actions

Based on status, suggests next steps like:
- Setting up testing
- Publishing config
- Fixing structure issues
- Running tests
