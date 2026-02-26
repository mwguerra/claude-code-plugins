#!/usr/bin/env python3
"""
Laravel Package Scaffold Script

Creates a complete Laravel package skeleton with ServiceProvider, Facade, Config,
Commands, Routes, Views, Migrations, Testbench, Workbench, and optional Playwright.

Targets: PHP 8.3, Laravel 12, Orchestra Testbench 10, Pest 4.

Usage:
    python3 scaffold_package.py vendor/package-name [options]

Options:
    --with-routes       Include route files (web.php, api.php)
    --with-views        Include views directory
    --with-migrations   Include database/migrations directory
    --with-commands     Include artisan install command
    --with-playwright   Include Playwright browser testing setup
    --all               Include routes, views, migrations, commands (NOT playwright)
    --project-root      Specify project root directory

Example:
    python3 scaffold_package.py mwguerra/my-package --all
    python3 scaffold_package.py mwguerra/my-package --all --with-playwright
"""

import json
import os
import re
import sys
import textwrap
from pathlib import Path
from datetime import datetime


# ---------------------------------------------------------------------------
# Name conversion helpers
# ---------------------------------------------------------------------------

def to_pascal_case(name: str) -> str:
    """Convert package-name to PackageName."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def to_studly_case(name: str) -> str:
    """Convert namespace to StudlyCase (for PHP namespaces)."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def to_snake_case(name: str) -> str:
    """Convert PackageName to package_name."""
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


def to_kebab(name: str) -> str:
    """Ensure name is kebab-case (passthrough if already)."""
    return name.lower().replace('_', '-')


# ---------------------------------------------------------------------------
# File content generators
# ---------------------------------------------------------------------------

def create_composer_json(namespace: str, package_name: str, php_namespace: str, options: dict) -> dict:
    """Generate the package's composer.json."""
    class_name = to_pascal_case(package_name)

    composer = {
        "name": f"{namespace}/{package_name}",
        "description": f"A Laravel package: {class_name}",
        "type": "library",
        "license": "MIT",
        "authors": [
            {
                "name": "Author Name",
                "email": "author@example.com"
            }
        ],
        "require": {
            "php": "^8.3",
            "illuminate/support": "^12.0"
        },
        "require-dev": {
            "orchestra/testbench": "^10.0",
            "pestphp/pest": "^4.0",
            "pestphp/pest-plugin-laravel": "^4.0",
            "orchestra/pest-plugin-testbench": "^4.0"
        },
        "autoload": {
            "psr-4": {
                f"{php_namespace}\\": "src/"
            }
        },
        "autoload-dev": {
            "psr-4": {
                f"{php_namespace}\\Tests\\": "tests/",
                "Workbench\\App\\": "workbench/app/",
                "Workbench\\Database\\Seeders\\": "workbench/database/seeders/",
                "Workbench\\Database\\Factories\\": "workbench/database/factories/"
            }
        },
        "extra": {
            "laravel": {
                "providers": [
                    f"{php_namespace}\\{class_name}ServiceProvider"
                ],
                "aliases": {
                    class_name: f"{php_namespace}\\Facades\\{class_name}"
                }
            }
        },
        "scripts": {
            "post-autoload-dump": [
                "@clear",
                "@prepare"
            ],
            "clear": "@php vendor/bin/testbench package:purge-skeleton --ansi",
            "prepare": "@php vendor/bin/testbench package:discover --ansi",
            "build": "@php vendor/bin/testbench workbench:build --ansi",
            "serve": [
                "Composer\\Config::disableProcessTimeout",
                "@build",
                "@php vendor/bin/testbench serve --ansi"
            ],
            "test": "pest",
            "test-coverage": "pest --coverage"
        },
        "config": {
            "allow-plugins": {
                "pestphp/pest-plugin": True
            }
        },
        "minimum-stability": "dev",
        "prefer-stable": True
    }

    return composer


def create_service_provider(php_namespace: str, package_name: str, options: dict) -> str:
    """Generate the ServiceProvider PHP code."""
    class_name = to_pascal_case(package_name)

    uses = ["use Illuminate\\Support\\ServiceProvider;"]
    register_lines = []
    boot_lines = []

    # Config is always included
    register_lines.append(f"""        $this->mergeConfigFrom(
            __DIR__ . '/../config/{package_name}.php', '{package_name}'
        );""")

    # Publish config
    boot_lines.append(f"""        if ($this->app->runningInConsole()) {{
            $this->publishes([
                __DIR__ . '/../config/{package_name}.php' => config_path('{package_name}.php'),
            ], '{package_name}-config');
        }}""")

    # Routes
    if options.get('with_routes'):
        boot_lines.append(f"""
        $this->loadRoutesFrom(__DIR__ . '/../routes/web.php');
        $this->loadRoutesFrom(__DIR__ . '/../routes/api.php');""")

    # Views
    if options.get('with_views'):
        boot_lines.append(f"""
        $this->loadViewsFrom(__DIR__ . '/../resources/views', '{package_name}');

        if ($this->app->runningInConsole()) {{
            $this->publishes([
                __DIR__ . '/../resources/views' => resource_path('views/vendor/{package_name}'),
            ], '{package_name}-views');
        }}""")

    # Migrations
    if options.get('with_migrations'):
        boot_lines.append(f"""
        if ($this->app->runningInConsole()) {{
            $this->publishesMigrations([
                __DIR__ . '/../database/migrations' => database_path('migrations'),
            ], '{package_name}-migrations');
        }}""")

    # Translations (always included)
    boot_lines.append(f"""
        $this->loadTranslationsFrom(__DIR__ . '/../lang', '{package_name}');
        $this->loadJsonTranslationsFrom(__DIR__ . '/../lang');""")

    # Commands
    if options.get('with_commands'):
        uses.append(f"use {php_namespace}\\Commands\\InstallCommand;")
        boot_lines.append(f"""
        if ($this->app->runningInConsole()) {{
            $this->commands([
                InstallCommand::class,
            ]);
        }}""")

    # Container binding
    register_lines.append(f"""
        $this->app->singleton('{package_name}', function ($app) {{
            return new {class_name}();
        }});""")

    uses_str = "\n".join(uses)
    register_str = "\n".join(register_lines)
    boot_str = "\n".join(boot_lines)

    return f'''<?php

namespace {php_namespace};

{uses_str}

class {class_name}ServiceProvider extends ServiceProvider
{{
    public function register(): void
    {{
{register_str}
    }}

    public function boot(): void
    {{
{boot_str}
    }}
}}
'''


def create_main_class(php_namespace: str, package_name: str) -> str:
    """Generate the main package class."""
    class_name = to_pascal_case(package_name)

    return f'''<?php

namespace {php_namespace};

class {class_name}
{{
    /**
     * The package version.
     */
    public const VERSION = '1.0.0';

    /**
     * Get the package version.
     */
    public function version(): string
    {{
        return self::VERSION;
    }}

    /**
     * Example method - replace with your package logic.
     */
    public function greet(string $name = 'World'): string
    {{
        return "Hello, {{$name}}!";
    }}
}}
'''


def create_facade(php_namespace: str, package_name: str) -> str:
    """Generate the Facade PHP code."""
    class_name = to_pascal_case(package_name)

    return f'''<?php

namespace {php_namespace}\\Facades;

use Illuminate\\Support\\Facades\\Facade;

/**
 * @see \\{php_namespace}\\{class_name}
 *
 * @method static string version()
 * @method static string greet(string $name = 'World')
 */
class {class_name} extends Facade
{{
    protected static function getFacadeAccessor(): string
    {{
        return '{package_name}';
    }}
}}
'''


def create_install_command(php_namespace: str, package_name: str) -> str:
    """Generate the install command."""
    class_name = to_pascal_case(package_name)

    return f'''<?php

namespace {php_namespace}\\Commands;

use Illuminate\\Console\\Command;

class InstallCommand extends Command
{{
    protected $signature = '{package_name}:install';

    protected $description = 'Install the {class_name} package';

    public function handle(): int
    {{
        $this->info('Installing {class_name}...');

        $this->info('Publishing configuration...');
        $this->callSilent('vendor:publish', [
            '--tag' => '{package_name}-config',
        ]);

        $this->info('{class_name} installed successfully!');

        return self::SUCCESS;
    }}
}}
'''


def create_config_file(package_name: str) -> str:
    """Generate the config file."""
    class_name = to_pascal_case(package_name)
    env_key = to_snake_case(class_name).upper()

    return f'''<?php

return [
    /*
    |--------------------------------------------------------------------------
    | {class_name} Configuration
    |--------------------------------------------------------------------------
    |
    | Configure your package settings here.
    |
    */

    'enabled' => env('{env_key}_ENABLED', true),

    // Add your configuration options here
];
'''


def create_lang_messages(package_name: str) -> str:
    """Generate language file."""
    class_name = to_pascal_case(package_name)
    return f'''<?php

return [
    'welcome' => 'Welcome to {class_name}!',
];
'''


def create_routes_web(php_namespace: str, package_name: str) -> str:
    """Generate web routes file."""
    return f'''<?php

use Illuminate\\Support\\Facades\\Route;

Route::prefix('{package_name}')->group(function () {{
    // Define your web routes here
}});
'''


def create_routes_api(php_namespace: str, package_name: str) -> str:
    """Generate api routes file."""
    return f'''<?php

use Illuminate\\Support\\Facades\\Route;

Route::prefix('api/{package_name}')->group(function () {{
    // Define your API routes here
}});
'''


def create_phpunit_xml() -> str:
    """Generate phpunit.xml for testing."""
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
| Add custom expectations here.
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
| Add helper functions here.
|
*/

// function something()
// {{
//     // ..
// }}
'''


def create_test_case(php_namespace: str, package_name: str) -> str:
    """Generate the TestCase class using WithWorkbench."""
    class_name = to_pascal_case(package_name)

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


def create_example_test(php_namespace: str, package_name: str) -> str:
    """Generate an example unit test."""
    class_name = to_pascal_case(package_name)

    return f'''<?php

use {php_namespace}\\{class_name};

test('environment is set to testing', function () {{
    expect(config('app.env'))->toBe('testing');
}});

test('package is registered', function () {{
    expect(app()->bound('{package_name}'))->toBeTrue();
}});

test('main class can be instantiated', function () {{
    $instance = new {class_name}();

    expect($instance)->toBeInstanceOf({class_name}::class);
}});

test('version is returned correctly', function () {{
    $instance = new {class_name}();

    expect($instance->version())->toBe({class_name}::VERSION);
}});

test('greet method works', function () {{
    $instance = new {class_name}();

    expect($instance->greet('Laravel'))->toBe('Hello, Laravel!');
    expect($instance->greet())->toBe('Hello, World!');
}});
'''


def create_testbench_yaml(package_name: str, options: dict) -> str:
    """Generate testbench.yaml configuration."""
    discovers_web = "true" if options.get('with_routes') else "false"
    discovers_views = "true" if options.get('with_views') else "false"
    discovers_commands = "true" if options.get('with_commands') else "false"

    build_steps = "    - create-sqlite-db\n    - migrate:fresh"

    return f'''providers:
  - Workbench\\App\\Providers\\WorkbenchServiceProvider

migrations:
  - workbench/database/migrations

seeders:
  - Workbench\\Database\\Seeders\\DatabaseSeeder

workbench:
  start: "/"
  install: true
  health: "/up"
  discovers:
    web: {discovers_web}
    api: false
    commands: {discovers_commands}
    components: false
    views: {discovers_views}
  build:
{build_steps}
'''


def create_workbench_service_provider() -> str:
    """Generate workbench service provider."""
    return '''<?php

namespace Workbench\\App\\Providers;

use Illuminate\\Support\\ServiceProvider;

class WorkbenchServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        //
    }
}
'''


def create_workbench_database_seeder() -> str:
    """Generate workbench database seeder."""
    return '''<?php

namespace Workbench\\Database\\Seeders;

use Illuminate\\Database\\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        //
    }
}
'''


def create_workbench_welcome_view(package_name: str) -> str:
    """Generate workbench welcome blade view."""
    class_name = to_pascal_case(package_name)
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{class_name} - Workbench</title>
    <style>
        body {{ font-family: system-ui, -apple-system, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f8fafc; }}
        .container {{ text-align: center; }}
        h1 {{ color: #1e293b; font-size: 2rem; }}
        p {{ color: #64748b; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>{class_name}</h1>
        <p>Workbench development server is running.</p>
    </div>
</body>
</html>
'''


def create_workbench_routes() -> str:
    """Generate workbench web routes."""
    return '''<?php

use Illuminate\\Support\\Facades\\Route;

Route::get('/', function () {
    return view('welcome');
});
'''


def create_github_workflow(package_name: str) -> str:
    """Generate GitHub Actions workflow."""
    return '''name: Tests

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: true
      matrix:
        os: [ubuntu-latest]
        php: ['8.3', '8.4']
        stability: [prefer-stable]

    name: P${{ matrix.php }} - ${{ matrix.stability }} - ${{ matrix.os }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php }}
          extensions: dom, curl, libxml, mbstring, zip, pcntl, pdo, sqlite, pdo_sqlite
          coverage: xdebug

      - name: Install dependencies
        run: composer update --${{ matrix.stability }} --prefer-dist --no-interaction

      - name: Execute tests
        run: vendor/bin/pest --ci
'''


def create_gitignore() -> str:
    """Generate .gitignore content."""
    return '''/vendor/
/node_modules/
.phpunit.result.cache
.phpunit.cache/
.php-cs-fixer.cache
.idea/
.vscode/
.DS_Store
*.swp
*.swo
composer.lock
coverage/
'''


def create_gitattributes() -> str:
    """Generate .gitattributes for Packagist distribution."""
    return '''# Auto-detect text files and normalize line endings
* text=auto

# Exclude from distribution archive
/.github            export-ignore
/tests              export-ignore
/workbench          export-ignore
.editorconfig       export-ignore
.gitattributes      export-ignore
.gitignore          export-ignore
phpunit.xml         export-ignore
testbench.yaml      export-ignore
CHANGELOG.md        export-ignore
'''


def create_license() -> str:
    """Generate MIT LICENSE content."""
    year = datetime.now().year
    return f'''MIT License

Copyright (c) {year} Author Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'''


def create_readme(namespace: str, package_name: str, php_namespace: str, options: dict) -> str:
    """Generate README.md content for the generated package."""
    class_name = to_pascal_case(package_name)

    testing_section = """
## Testing

```bash
composer test
```

With coverage:

```bash
composer test-coverage
```
"""

    workbench_section = """
## Development with Workbench

Start the interactive development server:

```bash
composer serve
```

This boots a real Laravel application with your package loaded, powered by
[Orchestra Workbench](https://packages.tools/workbench).
"""

    playwright_section = ""
    if options.get('with_playwright'):
        playwright_section = """
## Browser Testing (Playwright)

Install Playwright dependencies:

```bash
npm install
npx playwright install --with-deps chromium
```

Run browser tests:

```bash
npx playwright test
```
"""

    return f'''# {class_name}

[![Latest Version on Packagist](https://img.shields.io/packagist/v/{namespace}/{package_name}.svg?style=flat-square)](https://packagist.org/packages/{namespace}/{package_name})
[![Tests](https://github.com/{namespace}/{package_name}/actions/workflows/tests.yml/badge.svg)](https://github.com/{namespace}/{package_name}/actions)
[![Total Downloads](https://img.shields.io/packagist/dt/{namespace}/{package_name}.svg?style=flat-square)](https://packagist.org/packages/{namespace}/{package_name})

A Laravel package: {class_name}

## Installation

You can install the package via composer:

```bash
composer require {namespace}/{package_name}
```

## Configuration

Publish the configuration file:

```bash
php artisan vendor:publish --tag={package_name}-config
```

## Usage

```php
use {php_namespace}\\Facades\\{class_name};

{class_name}::greet('Laravel'); // Hello, Laravel!
```
{testing_section}{workbench_section}{playwright_section}
## Changelog

Please see [CHANGELOG](CHANGELOG.md) for more information on what has changed recently.

## Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md) for details.

## Security Vulnerabilities

Please review [our security policy](../../security/policy) on how to report security vulnerabilities.

## Credits

- [Author Name](https://github.com/author)
- [All Contributors](../../contributors)

## License

The MIT License (MIT). Please see [License File](LICENSE) for more information.
'''


# ---------------------------------------------------------------------------
# Playwright files
# ---------------------------------------------------------------------------

def create_playwright_config(package_name: str) -> str:
    """Generate playwright.config.ts."""
    return '''import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/Browser',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://127.0.0.1:8001',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'vendor/bin/testbench serve --port=8001',
    url: 'http://127.0.0.1:8001/up',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
'''


def create_package_json(package_name: str) -> dict:
    """Generate package.json for Playwright."""
    return {
        "private": True,
        "scripts": {
            "test:browser": "playwright test"
        },
        "devDependencies": {
            "@playwright/test": "^1.50"
        }
    }


def create_browser_example_test() -> str:
    """Generate example Playwright test."""
    return '''import { test, expect } from '@playwright/test';

test('workbench welcome page loads', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Workbench/);
});

test('health check responds', async ({ page }) => {
  const response = await page.goto('/up');
  expect(response?.status()).toBe(200);
});
'''


# ---------------------------------------------------------------------------
# Project composer.json updater
# ---------------------------------------------------------------------------

def update_project_composer(project_root: Path, namespace: str, package_name: str) -> bool:
    """Update the project's composer.json with the new package."""
    composer_path = project_root / 'composer.json'

    if not composer_path.exists():
        print(f"Warning: Project composer.json not found at {composer_path}")
        return False

    with open(composer_path, 'r') as f:
        composer_data = json.load(f)

    # Add repositories array if it doesn't exist
    if 'repositories' not in composer_data:
        composer_data['repositories'] = []

    # Check if this package is already in repositories
    package_url = f"packages/{namespace}/{package_name}"
    repo_exists = any(
        repo.get('url') == package_url
        for repo in composer_data['repositories']
        if isinstance(repo, dict)
    )

    if not repo_exists:
        composer_data['repositories'].append({
            "type": "path",
            "url": package_url,
            "options": {
                "symlink": True
            }
        })

    # Add to require if not already present
    package_full_name = f"{namespace}/{package_name}"
    if 'require' not in composer_data:
        composer_data['require'] = {}

    if package_full_name not in composer_data['require']:
        composer_data['require'][package_full_name] = "@dev"

    # Write back with proper formatting
    with open(composer_path, 'w') as f:
        json.dump(composer_data, f, indent=4)

    return True


# ---------------------------------------------------------------------------
# File writing helper
# ---------------------------------------------------------------------------

def write_file(path: Path, content: str) -> None:
    """Write content to a file, creating parent directories if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)
    print(f"  Created: {path}")


def write_gitkeep(path: Path) -> None:
    """Create an empty .gitkeep file."""
    write_file(path / '.gitkeep', '')


# ---------------------------------------------------------------------------
# Main scaffold function
# ---------------------------------------------------------------------------

def scaffold_package(input_name: str, project_root: Path = None, options: dict = None) -> bool:
    """
    Main function to scaffold a Laravel package.

    Args:
        input_name: Package name in format 'vendor/package-name'
        project_root: Root directory of the Laravel project (defaults to cwd)
        options: Dictionary of options

    Returns:
        True if successful, False otherwise
    """
    options = options or {}

    # Parse input
    if '/' not in input_name:
        print("Error: Input must be in format 'vendor/package-name'")
        return False

    namespace, package_name = input_name.split('/', 1)
    package_name = to_kebab(package_name)

    if not namespace or not package_name:
        print("Error: Both vendor and package-name are required")
        return False

    if project_root is None:
        project_root = Path.cwd()

    # Generate names
    php_namespace = f"{to_studly_case(namespace)}\\{to_pascal_case(package_name)}"
    class_name = to_pascal_case(package_name)

    # Package directory
    package_dir = project_root / 'packages' / namespace / package_name

    if package_dir.exists():
        print(f"Error: Package directory already exists at {package_dir}")
        return False

    print(f"\n  Creating Laravel Package: {namespace}/{package_name}")
    print(f"  PHP Namespace: {php_namespace}")
    print(f"  Package directory: {package_dir}")
    active_opts = [k for k, v in options.items() if v]
    print(f"  Options: {', '.join(active_opts) or 'none'}")
    print()

    # ------------------------------------------------------------------
    # Create directories
    # ------------------------------------------------------------------
    (package_dir / 'src' / 'Facades').mkdir(parents=True, exist_ok=True)

    if options.get('with_commands'):
        (package_dir / 'src' / 'Commands').mkdir(parents=True, exist_ok=True)

    (package_dir / 'config').mkdir(parents=True, exist_ok=True)
    (package_dir / 'lang' / 'en').mkdir(parents=True, exist_ok=True)

    if options.get('with_routes'):
        (package_dir / 'routes').mkdir(parents=True, exist_ok=True)

    if options.get('with_views'):
        (package_dir / 'resources' / 'views').mkdir(parents=True, exist_ok=True)

    if options.get('with_migrations'):
        (package_dir / 'database' / 'factories').mkdir(parents=True, exist_ok=True)
        (package_dir / 'database' / 'migrations').mkdir(parents=True, exist_ok=True)

    # Tests
    (package_dir / 'tests' / 'Unit').mkdir(parents=True, exist_ok=True)
    (package_dir / 'tests' / 'Feature').mkdir(parents=True, exist_ok=True)

    if options.get('with_playwright'):
        (package_dir / 'tests' / 'Browser').mkdir(parents=True, exist_ok=True)

    # Workbench
    (package_dir / 'workbench' / 'app' / 'Models').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'app' / 'Providers').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'database' / 'factories').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'database' / 'migrations').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'database' / 'seeders').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'resources' / 'views').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'routes').mkdir(parents=True, exist_ok=True)

    # GitHub Actions
    (package_dir / '.github' / 'workflows').mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # Generate files
    # ------------------------------------------------------------------
    print("  Creating package files...")

    # Core package files
    composer_content = create_composer_json(namespace, package_name, php_namespace, options)
    write_file(package_dir / 'composer.json', json.dumps(composer_content, indent=4))

    write_file(
        package_dir / 'src' / f'{class_name}ServiceProvider.php',
        create_service_provider(php_namespace, package_name, options)
    )

    write_file(
        package_dir / 'src' / f'{class_name}.php',
        create_main_class(php_namespace, package_name)
    )

    write_file(
        package_dir / 'src' / 'Facades' / f'{class_name}.php',
        create_facade(php_namespace, package_name)
    )

    # Config
    write_file(
        package_dir / 'config' / f'{package_name}.php',
        create_config_file(package_name)
    )

    # Translations
    write_file(
        package_dir / 'lang' / 'en' / 'messages.php',
        create_lang_messages(package_name)
    )

    # Routes (optional)
    if options.get('with_routes'):
        write_file(package_dir / 'routes' / 'web.php', create_routes_web(php_namespace, package_name))
        write_file(package_dir / 'routes' / 'api.php', create_routes_api(php_namespace, package_name))

    # Views (optional)
    if options.get('with_views'):
        write_gitkeep(package_dir / 'resources' / 'views')

    # Migrations (optional)
    if options.get('with_migrations'):
        write_gitkeep(package_dir / 'database' / 'factories')
        write_gitkeep(package_dir / 'database' / 'migrations')

    # Commands (optional)
    if options.get('with_commands'):
        write_file(
            package_dir / 'src' / 'Commands' / 'InstallCommand.php',
            create_install_command(php_namespace, package_name)
        )

    # ------------------------------------------------------------------
    # Testing files (always created)
    # ------------------------------------------------------------------
    print("\n  Setting up Pest v4 + Testbench v10...")

    write_file(package_dir / 'phpunit.xml', create_phpunit_xml())
    write_file(package_dir / 'tests' / 'Pest.php', create_pest_php(php_namespace))
    write_file(package_dir / 'tests' / 'TestCase.php', create_test_case(php_namespace, package_name))
    write_file(package_dir / 'tests' / 'Unit' / 'ExampleTest.php', create_example_test(php_namespace, package_name))
    write_gitkeep(package_dir / 'tests' / 'Feature')

    # ------------------------------------------------------------------
    # Workbench files (always created)
    # ------------------------------------------------------------------
    print("\n  Setting up Workbench...")

    write_file(package_dir / 'testbench.yaml', create_testbench_yaml(package_name, options))
    write_file(
        package_dir / 'workbench' / 'app' / 'Providers' / 'WorkbenchServiceProvider.php',
        create_workbench_service_provider()
    )
    write_file(
        package_dir / 'workbench' / 'database' / 'seeders' / 'DatabaseSeeder.php',
        create_workbench_database_seeder()
    )
    write_file(
        package_dir / 'workbench' / 'resources' / 'views' / 'welcome.blade.php',
        create_workbench_welcome_view(package_name)
    )
    write_file(package_dir / 'workbench' / 'routes' / 'web.php', create_workbench_routes())
    write_gitkeep(package_dir / 'workbench' / 'app' / 'Models')
    write_gitkeep(package_dir / 'workbench' / 'database' / 'factories')
    write_gitkeep(package_dir / 'workbench' / 'database' / 'migrations')

    # ------------------------------------------------------------------
    # Playwright (optional)
    # ------------------------------------------------------------------
    if options.get('with_playwright'):
        print("\n  Setting up Playwright browser testing...")
        write_file(package_dir / 'playwright.config.ts', create_playwright_config(package_name))
        write_file(package_dir / 'package.json', json.dumps(create_package_json(package_name), indent=2))
        write_file(package_dir / 'tests' / 'Browser' / 'example.spec.ts', create_browser_example_test())

    # ------------------------------------------------------------------
    # Meta files
    # ------------------------------------------------------------------
    print("\n  Creating meta files...")

    write_file(package_dir / '.github' / 'workflows' / 'tests.yml', create_github_workflow(package_name))
    write_file(package_dir / 'README.md', create_readme(namespace, package_name, php_namespace, options))
    write_file(package_dir / '.gitignore', create_gitignore())
    write_file(package_dir / '.gitattributes', create_gitattributes())
    write_file(package_dir / 'LICENSE', create_license())

    # ------------------------------------------------------------------
    # Update project composer.json
    # ------------------------------------------------------------------
    print("\n  Updating project composer.json...")
    if update_project_composer(project_root, namespace, package_name):
        print("  Project composer.json updated")
    else:
        print("  Could not update project composer.json (file not found)")

    # ------------------------------------------------------------------
    # Done
    # ------------------------------------------------------------------
    print(f"\n  Package '{namespace}/{package_name}' created successfully!")
    print("\n  Next steps:")
    print("  1. Run: composer update")

    if options.get('with_commands'):
        print(f"  2. Install: php artisan {package_name}:install")

    print(f"  3. Run tests: cd packages/{namespace}/{package_name} && composer install && vendor/bin/pest")
    print(f"  4. Serve workbench: cd packages/{namespace}/{package_name} && composer serve")

    if options.get('with_playwright'):
        print(f"  5. Browser tests: cd packages/{namespace}/{package_name} && npm install && npx playwright test")

    return True


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(args: list) -> tuple:
    """Parse command line arguments."""
    options = {
        'with_routes': False,
        'with_views': False,
        'with_migrations': False,
        'with_commands': False,
        'with_playwright': False,
    }

    input_name = None
    project_root = None

    i = 0
    while i < len(args):
        arg = args[i]

        if arg == '--with-routes':
            options['with_routes'] = True
        elif arg == '--with-views':
            options['with_views'] = True
        elif arg == '--with-migrations':
            options['with_migrations'] = True
        elif arg == '--with-commands':
            options['with_commands'] = True
        elif arg == '--with-playwright':
            options['with_playwright'] = True
        elif arg == '--all':
            options['with_routes'] = True
            options['with_views'] = True
            options['with_migrations'] = True
            options['with_commands'] = True
            # NOTE: --all does NOT enable playwright; use --with-playwright explicitly
        elif arg == '--project-root' and i + 1 < len(args):
            i += 1
            project_root = Path(args[i])
        elif not arg.startswith('--') and input_name is None:
            input_name = arg

        i += 1

    return input_name, project_root, options


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_package.py vendor/package-name [options]")
        print("\nOptions:")
        print("  --with-routes       Include route files")
        print("  --with-views        Include views directory")
        print("  --with-migrations   Include database migrations")
        print("  --with-commands     Include artisan install command")
        print("  --with-playwright   Include Playwright browser testing")
        print("  --all               Include routes, views, migrations, commands")
        print("  --project-root      Specify project root directory")
        print("\nExamples:")
        print("  python3 scaffold_package.py mwguerra/my-package --all")
        print("  python3 scaffold_package.py mwguerra/my-package --all --with-playwright")
        sys.exit(1)

    input_name, project_root, options = parse_args(sys.argv[1:])

    if not input_name:
        print("Error: Package name required in format 'vendor/package-name'")
        sys.exit(1)

    success = scaffold_package(input_name, project_root, options)
    sys.exit(0 if success else 1)
