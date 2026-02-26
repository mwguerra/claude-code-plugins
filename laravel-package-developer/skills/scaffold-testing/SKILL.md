---
description: Add Pest v4 + Orchestra Testbench v10 testing to an existing Laravel package
allowed-tools: Bash(python3:*), Bash(composer:*), Write, Read, Glob
---

# Pest Testing Scaffold Skill

Adds Pest v4 + Orchestra Testbench v10 testing infrastructure to an existing Laravel package that lacks testing.

## Usage

When the user wants to add testing to an existing package:

```bash
python3 ${SKILL_DIR}/scripts/scaffold_testing.py <vendor/package-name> [options]
```

## Options

- `--with-coverage` - Add code coverage configuration
- `--with-ci` - Add GitHub Actions CI workflow
- `--project-root` - Specify project root directory

## Examples

### Basic testing setup
```bash
python3 ${SKILL_DIR}/scripts/scaffold_testing.py mwguerra/my-package
```

### With CI
```bash
python3 ${SKILL_DIR}/scripts/scaffold_testing.py mwguerra/my-package --with-ci
```

### Full setup
```bash
python3 ${SKILL_DIR}/scripts/scaffold_testing.py mwguerra/my-package --with-coverage --with-ci
```

## What Gets Created/Updated

### Files Created

1. **phpunit.xml** — PHPUnit configuration with source coverage for `src/`
2. **tests/Pest.php** — Pest configuration with TestCase binding
3. **tests/TestCase.php** — Orchestra TestCase with `WithWorkbench` trait
4. **tests/Unit/ExampleTest.php** — Sample tests verifying environment and provider
5. **tests/Feature/.gitkeep** — Feature tests directory
6. **.github/workflows/tests.yml** (if `--with-ci`)

### composer.json Updates

```json
{
  "require-dev": {
    "orchestra/testbench": "^10.0",
    "pestphp/pest": "^4.0",
    "pestphp/pest-plugin-laravel": "^4.0",
    "orchestra/pest-plugin-testbench": "^4.0"
  }
}
```

## Running Tests

```bash
cd packages/vendor/package-name
composer install
./vendor/bin/pest
```
