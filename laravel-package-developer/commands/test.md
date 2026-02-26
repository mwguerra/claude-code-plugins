---
description: Run Pest v4 tests for a Laravel package with coverage, filter, parallel, and browser options
argument-hint: <vendor/package-name> [--coverage] [--filter <name>] [--parallel] [--browser] [--bail]
allowed-tools: Bash(./vendor/bin/pest:*), Bash(vendor/bin/pest:*), Bash(composer:*), Bash(php:*), Bash(cd:*), Bash(npx:*), Bash(vendor/bin/testbench:*), Read
---

# Run Package Tests

Execute Pest v4 tests for a Laravel package.

## Input Format

Specify the package: `vendor/package-name`

## Options

- `--coverage` - Generate code coverage report
- `--filter <name>` - Run only tests matching the filter
- `--parallel` - Run tests in parallel
- `--browser` - Run Playwright browser tests (starts testbench serve, runs Playwright, stops server)
- `--bail` - Stop on first failure

## Process

### Unit/Feature Tests

1. Navigate to `packages/vendor/package-name/`
2. Ensure dependencies are installed (`composer install`)
3. Run Pest with the specified options
4. Display test results

```bash
cd packages/vendor/package-name

# Basic run
./vendor/bin/pest

# With coverage
./vendor/bin/pest --coverage

# Filtered
./vendor/bin/pest --filter="test name"

# Parallel
./vendor/bin/pest --parallel

# Stop on first failure
./vendor/bin/pest --bail
```

### Browser Tests (--browser)

1. Navigate to `packages/vendor/package-name/`
2. Ensure npm dependencies are installed (`npm install`)
3. Run Playwright tests (webServer config auto-starts testbench serve)

```bash
cd packages/vendor/package-name
npx playwright test
```

## Common Patterns

### Test a specific file
```bash
./vendor/bin/pest tests/Unit/MyTest.php
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

1. **Check dependencies**: `composer install`
2. **Verify Pest**: `./vendor/bin/pest --version`
3. **Check phpunit.xml**: ensure it exists and has correct configuration
4. **Verify autoloading**: `composer dump-autoload`
5. **Browser tests**: ensure `npm install && npx playwright install --with-deps chromium`
