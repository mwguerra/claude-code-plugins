#!/usr/bin/env python3
"""
Pest Testing Scaffold Script

Adds Pest v4 + Orchestra Testbench v10 testing infrastructure to an existing
Laravel package. Includes WithWorkbench trait and testbench.yaml integration.

Usage:
    python3 scaffold_testing.py vendor/package-name [options]

Options:
    --with-coverage  Add code coverage configuration
    --with-ci        Add GitHub Actions CI workflow
    --project-root   Specify project root directory

Example:
    python3 scaffold_testing.py mwguerra/my-package --with-ci
"""

import json
import os
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Name conversion helpers
# ---------------------------------------------------------------------------

def to_pascal_case(name: str) -> str:
    """Convert package-name to PackageName."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def to_studly_case(name: str) -> str:
    """Convert namespace to StudlyCase."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def find_service_provider(src_dir: Path) -> str | None:
    """Find the ServiceProvider class name."""
    for file in src_dir.glob('*ServiceProvider.php'):
        return file.stem
    return None


# ---------------------------------------------------------------------------
# Composer.json updater
# ---------------------------------------------------------------------------

def update_composer_json(composer_path: Path, php_namespace: str, options: dict) -> bool:
    """Update package composer.json with testing dependencies."""
    if not composer_path.exists():
        print(f"Error: composer.json not found at {composer_path}")
        return False

    with open(composer_path, 'r') as f:
        composer_data = json.load(f)

    # Add require-dev dependencies
    if 'require-dev' not in composer_data:
        composer_data['require-dev'] = {}

    composer_data['require-dev'].update({
        "orchestra/testbench": "^10.0",
        "pestphp/pest": "^4.0",
        "pestphp/pest-plugin-laravel": "^4.0",
        "orchestra/pest-plugin-testbench": "^4.0"
    })

    # Add autoload-dev
    if 'autoload-dev' not in composer_data:
        composer_data['autoload-dev'] = {}
    if 'psr-4' not in composer_data['autoload-dev']:
        composer_data['autoload-dev']['psr-4'] = {}

    test_namespace = f"{php_namespace}\\Tests\\"
    composer_data['autoload-dev']['psr-4'][test_namespace] = "tests/"

    # Add scripts
    if 'scripts' not in composer_data:
        composer_data['scripts'] = {}

    composer_data['scripts']['test'] = 'pest'
    composer_data['scripts']['test-coverage'] = 'pest --coverage'

    # Add config for pest plugin
    if 'config' not in composer_data:
        composer_data['config'] = {}
    if 'allow-plugins' not in composer_data['config']:
        composer_data['config']['allow-plugins'] = {}

    composer_data['config']['allow-plugins']['pestphp/pest-plugin'] = True

    with open(composer_path, 'w') as f:
        json.dump(composer_data, f, indent=4)

    return True


# ---------------------------------------------------------------------------
# File content generators
# ---------------------------------------------------------------------------

def create_phpunit_xml() -> str:
    """Generate phpunit.xml."""
    return '''<?xml version="1.0" encoding="UTF-8"?>
<phpunit
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
    bootstrap="vendor/autoload.php"
    colors="true"
    stopOnFailure="false"
>
    <source>
        <include>
            <directory suffix=".php">src/</directory>
        </include>
    </source>
    <testsuites>
        <testsuite name="Unit">
            <directory suffix="Test.php">./tests/Unit</directory>
        </testsuite>
        <testsuite name="Feature">
            <directory suffix="Test.php">./tests/Feature</directory>
        </testsuite>
    </testsuites>
    <php>
        <env name="APP_KEY" value="base64:2fl+Ktvkfl+Fuz4Qp/A75G2RTiWVA/ZoKZvp6fiiM10="/>
        <env name="DB_CONNECTION" value="testing"/>
        <env name="CACHE_DRIVER" value="array"/>
        <env name="SESSION_DRIVER" value="array"/>
        <env name="QUEUE_DRIVER" value="sync"/>
    </php>
</phpunit>
'''


def create_pest_php(php_namespace: str) -> str:
    """Generate Pest.php configuration."""
    return f'''<?php

use {php_namespace}\\Tests\\TestCase;

uses(TestCase::class)->in(__DIR__);

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
|
| Custom expectations can be defined here.
|
*/

// expect()->extend('toBeOne', function () {{
//     return $this->toBe(1);
// }});

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
|
| Helper functions for tests.
|
*/

// function something()
// {{
//     // ..
// }}
'''


def create_test_case(php_namespace: str, service_provider: str) -> str:
    """Generate TestCase class with WithWorkbench."""
    return f'''<?php

namespace {php_namespace}\\Tests;

use Orchestra\\Testbench\\Concerns\\WithWorkbench;
use Orchestra\\Testbench\\TestCase as Orchestra;

abstract class TestCase extends Orchestra
{{
    use WithWorkbench;

    protected function setUp(): void
    {{
        parent::setUp();

        // Additional setup if needed
    }}
}}
'''


def create_example_test(php_namespace: str, package_name: str, service_provider: str) -> str:
    """Generate example test."""
    return f'''<?php

test('environment is set to testing', function () {{
    expect(config('app.env'))->toBe('testing');
}});

test('package service provider is registered', function () {{
    $providers = $this->app->getLoadedProviders();

    expect(array_key_exists(
        \\{php_namespace}\\{service_provider}::class,
        $providers
    ))->toBeTrue();
}});

test('database connection is testing', function () {{
    expect(config('database.default'))->toBe('testing');
}});

// Add more tests specific to your package functionality below
'''


def create_github_workflow(options: dict) -> str:
    """Generate GitHub Actions workflow."""
    coverage_step = ""
    if options.get('with_coverage'):
        coverage_step = """
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage.xml
          fail_ci_if_error: false"""

    coverage_flag = ""
    if options.get('with_coverage'):
        coverage_flag = " --coverage --coverage-clover coverage.xml"

    return f'''name: Tests

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ${{{{ matrix.os }}}}
    strategy:
      fail-fast: true
      matrix:
        os: [ubuntu-latest]
        php: ['8.3', '8.4']
        stability: [prefer-stable]

    name: P${{{{ matrix.php }}}} - ${{{{ matrix.stability }}}} - ${{{{ matrix.os }}}}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{{{ matrix.php }}}}
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite
          coverage: xdebug

      - name: Install dependencies
        run: composer update --${{{{ matrix.stability }}}} --prefer-dist --no-interaction

      - name: Execute tests
        run: vendor/bin/pest --ci{coverage_flag}
{coverage_step}
'''


# ---------------------------------------------------------------------------
# File writing helper
# ---------------------------------------------------------------------------

def write_file(path: Path, content: str) -> None:
    """Write file with directory creation."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)
    print(f"  Created: {path}")


# ---------------------------------------------------------------------------
# Main function
# ---------------------------------------------------------------------------

def setup_testing(input_name: str, project_root: Path = None, options: dict = None) -> bool:
    """Main function to set up Pest testing."""
    options = options or {}

    if '/' not in input_name:
        print("Error: Input must be in format 'vendor/package-name'")
        return False

    namespace, package_name = input_name.split('/', 1)

    if project_root is None:
        project_root = Path.cwd()

    package_dir = project_root / 'packages' / namespace / package_name

    if not package_dir.exists():
        print(f"Error: Package directory not found at {package_dir}")
        return False

    # Check for composer.json
    composer_path = package_dir / 'composer.json'
    if not composer_path.exists():
        print(f"Error: composer.json not found in {package_dir}")
        return False

    # Read existing composer.json to get namespace
    with open(composer_path, 'r') as f:
        composer_data = json.load(f)

    # Extract PHP namespace from autoload
    php_namespace = None
    if 'autoload' in composer_data and 'psr-4' in composer_data['autoload']:
        for ns, path in composer_data['autoload']['psr-4'].items():
            if path == 'src/' or path == 'src':
                php_namespace = ns.rstrip('\\')
                break

    if not php_namespace:
        php_namespace = f"{to_studly_case(namespace)}\\{to_pascal_case(package_name)}"

    # Find service provider
    src_dir = package_dir / 'src'
    service_provider = find_service_provider(src_dir)
    if not service_provider:
        service_provider = f"{to_pascal_case(package_name)}ServiceProvider"
        print(f"Warning: Could not find ServiceProvider, using {service_provider}")

    print(f"\n  Setting up Pest v4 + Testbench v10 for: {namespace}/{package_name}")
    print(f"  PHP Namespace: {php_namespace}")
    print(f"  Service Provider: {service_provider}")
    print(f"  Package directory: {package_dir}")
    print()

    # Create test directories
    (package_dir / 'tests' / 'Unit').mkdir(parents=True, exist_ok=True)
    (package_dir / 'tests' / 'Feature').mkdir(parents=True, exist_ok=True)

    print("  Creating test files...")

    # Update composer.json
    if update_composer_json(composer_path, php_namespace, options):
        print("  Updated: composer.json")
    else:
        return False

    # Create test files
    write_file(package_dir / 'phpunit.xml', create_phpunit_xml())
    write_file(package_dir / 'tests' / 'Pest.php', create_pest_php(php_namespace))
    write_file(package_dir / 'tests' / 'TestCase.php',
               create_test_case(php_namespace, service_provider))
    write_file(package_dir / 'tests' / 'Unit' / 'ExampleTest.php',
               create_example_test(php_namespace, package_name, service_provider))
    write_file(package_dir / 'tests' / 'Feature' / '.gitkeep', '')

    # Create CI workflow if requested
    if options.get('with_ci'):
        print("\n  Creating GitHub Actions workflow...")
        workflow_dir = package_dir / '.github' / 'workflows'
        write_file(workflow_dir / 'tests.yml', create_github_workflow(options))

    print(f"\n  Pest v4 + Testbench v10 testing setup complete!")
    print("\n  Next steps:")
    print(f"  1. Navigate to package:")
    print(f"     cd packages/{namespace}/{package_name}")
    print(f"  2. Install dependencies:")
    print(f"     composer install")
    print(f"  3. Run tests:")
    print(f"     ./vendor/bin/pest")

    if options.get('with_coverage'):
        print(f"  4. Run with coverage:")
        print(f"     ./vendor/bin/pest --coverage")

    return True


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(args: list) -> tuple:
    """Parse command line arguments."""
    options = {
        'with_coverage': False,
        'with_ci': False,
    }

    input_name = None
    project_root = None

    i = 0
    while i < len(args):
        arg = args[i]

        if arg == '--with-coverage':
            options['with_coverage'] = True
        elif arg == '--with-ci':
            options['with_ci'] = True
        elif arg == '--project-root' and i + 1 < len(args):
            i += 1
            project_root = Path(args[i])
        elif not arg.startswith('--') and input_name is None:
            input_name = arg

        i += 1

    return input_name, project_root, options


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_testing.py vendor/package-name [options]")
        print("\nOptions:")
        print("  --with-coverage  Add code coverage configuration")
        print("  --with-ci        Add GitHub Actions CI workflow")
        print("  --project-root   Specify project root directory")
        print("\nExample:")
        print("  python3 scaffold_testing.py mwguerra/my-package --with-ci")
        sys.exit(1)

    input_name, project_root, options = parse_args(sys.argv[1:])

    if not input_name:
        print("Error: Package name required in format 'vendor/package-name'")
        sys.exit(1)

    success = setup_testing(input_name, project_root, options)
    sys.exit(0 if success else 1)
