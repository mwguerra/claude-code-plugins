---
description: Run PestPHP tests for a Laravel/Filament package with various options
argument-hint: <vendor/package-name> [--coverage] [--filter <test-name>] [--parallel]
allowed-tools: Bash(./vendor/bin/pest:*), Bash(composer:*), Bash(php:*), Bash(cd:*), Read
---

# Run Package Tests

Execute PestPHP tests for a Laravel or Filament package.

## Input Format

Specify the package: `vendor/package-name`

## Options

- `--coverage` - Generate code coverage report
- `--filter <name>` - Run only tests matching the filter
- `--parallel` - Run tests in parallel (requires pest-plugin-parallel)
- `--bail` - Stop on first failure

## Process

1. Navigate to `packages/vendor/package-name/`
2. Ensure dependencies are installed (`composer install`)
3. Run Pest with the specified options
4. Display test results

## Commands Executed

```bash
cd packages/vendor/package-name

# Basic test run
./vendor/bin/pest

# With coverage
./vendor/bin/pest --coverage

# Filtered
./vendor/bin/pest --filter="test name"

# Parallel
./vendor/bin/pest --parallel
```

## Common Test Patterns

### Test a specific file
```bash
./vendor/bin/pest tests/Unit/MyTest.php
```

### Test a specific method
```bash
./vendor/bin/pest --filter="it can do something"
```

### Run only unit tests
```bash
./vendor/bin/pest --testsuite=Unit
```

### Run with minimum coverage
```bash
./vendor/bin/pest --coverage --min=80
```

## Troubleshooting

If tests fail to run:

1. **Check dependencies**:
   ```bash
   composer install
   ```

2. **Verify Pest installation**:
   ```bash
   ./vendor/bin/pest --version
   ```

3. **Check phpunit.xml exists** and has correct configuration

4. **Verify autoloading**:
   ```bash
   composer dump-autoload
   ```
