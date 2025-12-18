#!/usr/bin/env python3
"""
Laravel Package Scaffold Script

Creates a complete Laravel package skeleton with ServiceProvider, Facade, Config,
Commands, and optional PestPHP testing setup.

Usage:
    python3 scaffold_laravel_package.py vendor/package-name [options]

Options:
    --with-pest     Include PestPHP testing setup
    --with-facade   Include Facade class
    --with-config   Include config file
    --with-command  Include artisan command
    --all           Include all optional features

Example:
    python3 scaffold_laravel_package.py mwguerra/filament-pages --with-pest --with-facade
"""

import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime


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


def create_composer_json(namespace: str, package_name: str, php_namespace: str, options: dict) -> dict:
    """Generate the package's composer.json content."""
    composer = {
        "name": f"{namespace}/{package_name}",
        "description": f"A Laravel package: {to_pascal_case(package_name)}",
        "type": "library",
        "license": "MIT",
        "authors": [
            {
                "name": "Author Name",
                "email": "author@example.com"
            }
        ],
        "require": {
            "php": "^8.2",
            "illuminate/support": "^11.0|^12.0"
        },
        "autoload": {
            "psr-4": {
                f"{php_namespace}\\": "src/"
            }
        },
        "extra": {
            "laravel": {
                "providers": [
                    f"{php_namespace}\\{to_pascal_case(package_name)}ServiceProvider"
                ]
            }
        },
        "minimum-stability": "dev",
        "prefer-stable": True
    }
    
    if options.get('with_facade'):
        composer["extra"]["laravel"]["aliases"] = {
            to_pascal_case(package_name): f"{php_namespace}\\Facades\\{to_pascal_case(package_name)}"
        }
    
    if options.get('with_pest'):
        composer["require-dev"] = {
            "orchestra/testbench": "^10.0|^11.0",
            "pestphp/pest": "^3.0|^4.0",
            "pestphp/pest-plugin-laravel": "^3.0|^4.0"
        }
        composer["autoload-dev"] = {
            "psr-4": {
                f"{php_namespace}\\Tests\\": "tests/"
            }
        }
        composer["scripts"] = {
            "test": "pest",
            "test-coverage": "pest --coverage"
        }
        composer["config"] = {
            "allow-plugins": {
                "pestphp/pest-plugin": True
            }
        }
    
    return composer


def create_service_provider(php_namespace: str, package_name: str, options: dict) -> str:
    """Generate the ServiceProvider PHP code."""
    class_name = to_pascal_case(package_name)
    
    uses = ["use Illuminate\\Support\\ServiceProvider;"]
    boot_content = []
    register_content = []
    
    if options.get('with_command'):
        uses.append(f"use {php_namespace}\\Commands\\InstallCommand;")
        boot_content.append("""
        if ($this->app->runningInConsole()) {
            $this->commands([
                InstallCommand::class,
            ]);
        }""")
    
    if options.get('with_config'):
        boot_content.append(f"""
        $this->mergeConfigFrom(
            __DIR__ . '/../config/{package_name}.php', '{package_name}'
        );

        if ($this->app->runningInConsole()) {{
            $this->publishes([
                __DIR__ . '/../config/{package_name}.php' => config_path('{package_name}.php'),
            ], '{package_name}-config');
        }}""")
    
    register_content.append(f"""
        $this->app->singleton('{package_name}', function ($app) {{
            return new {class_name}();
        }});""")
    
    uses_str = "\n".join(uses)
    boot_str = "\n".join(boot_content) if boot_content else "        //"
    register_str = "\n".join(register_content) if register_content else "        //"
    
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
    return f'''<?php

return [
    /*
    |--------------------------------------------------------------------------
    | {to_pascal_case(package_name)} Configuration
    |--------------------------------------------------------------------------
    |
    | Configure your package settings here.
    |
    */

    'enabled' => env('{to_snake_case(package_name).upper()}_ENABLED', true),

    // Add your configuration options here
];
'''


def create_phpunit_xml(php_namespace: str) -> str:
    """Generate phpunit.xml for testing."""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<phpunit
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
    bootstrap="vendor/autoload.php"
    colors="true"
    verbose="true"
    stopOnFailure="false"
>
    <coverage>
        <include>
            <directory suffix=".php">src/</directory>
        </include>
    </coverage>
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
    """Generate the TestCase class."""
    class_name = to_pascal_case(package_name)
    
    return f'''<?php

namespace {php_namespace}\\Tests;

use {php_namespace}\\{class_name}ServiceProvider;
use Orchestra\\Testbench\\TestCase as Orchestra;

class TestCase extends Orchestra
{{
    protected function setUp(): void
    {{
        parent::setUp();

        // Additional setup if needed
    }}

    protected function getPackageProviders($app): array
    {{
        return [
            {class_name}ServiceProvider::class,
        ];
    }}

    protected function getEnvironmentSetUp($app): void
    {{
        // Configure the testing environment
        $app['config']->set('database.default', 'testing');
        $app['config']->set('database.connections.testing', [
            'driver' => 'sqlite',
            'database' => ':memory:',
            'prefix' => '',
        ]);
    }}

    protected function defineDatabaseMigrations(): void
    {{
        // Load package migrations if any
        // $this->loadMigrationsFrom(__DIR__ . '/../database/migrations');
    }}
}}
'''


def create_example_test(php_namespace: str, package_name: str) -> str:
    """Generate an example test."""
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


def create_readme(namespace: str, package_name: str, php_namespace: str, options: dict) -> str:
    """Generate README.md content."""
    class_name = to_pascal_case(package_name)
    
    facade_example = ""
    if options.get('with_facade'):
        facade_example = f"""
## Using the Facade

```php
use {php_namespace}\\Facades\\{class_name};

// Get version
{class_name}::version();

// Use methods
{class_name}::greet('World');
```
"""
    
    testing_section = ""
    if options.get('with_pest'):
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
    
    return f'''# {class_name}

[![Latest Version on Packagist](https://img.shields.io/packagist/v/{namespace}/{package_name}.svg?style=flat-square)](https://packagist.org/packages/{namespace}/{package_name})
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
use {php_namespace}\\{class_name};

$package = new {class_name}();
echo $package->greet('Laravel'); // Hello, Laravel!
```
{facade_example}{testing_section}
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


def create_gitignore() -> str:
    """Generate .gitignore content."""
    return '''/vendor/
/node_modules/
.phpunit.result.cache
.php-cs-fixer.cache
.idea/
.vscode/
.DS_Store
*.swp
*.swo
composer.lock
coverage/
.phpunit.cache/
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


def write_file(path: Path, content: str) -> None:
    """Write content to a file, creating parent directories if needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)
    print(f"✓ Created: {path}")


def scaffold_package(input_name: str, project_root: Path = None, options: dict = None) -> bool:
    """
    Main function to scaffold a Laravel package.
    
    Args:
        input_name: Package name in format 'vendor/package-name'
        project_root: Root directory of the Laravel project (defaults to current directory)
        options: Dictionary of options (with_pest, with_facade, with_config, with_command)
    
    Returns:
        True if successful, False otherwise
    """
    options = options or {}
    
    # Parse input
    if '/' not in input_name:
        print("Error: Input must be in format 'vendor/package-name'")
        return False
    
    namespace, package_name = input_name.split('/', 1)
    
    # Validate
    if not namespace or not package_name:
        print("Error: Both vendor and package-name are required")
        return False
    
    # Set project root
    if project_root is None:
        project_root = Path.cwd()
    
    # Generate PHP namespace
    php_namespace = f"{to_studly_case(namespace)}\\{to_pascal_case(package_name)}"
    class_name = to_pascal_case(package_name)
    
    # Create package directory
    package_dir = project_root / 'packages' / namespace / package_name
    
    print(f"\n🚀 Creating Laravel Package: {namespace}/{package_name}")
    print(f"   PHP Namespace: {php_namespace}")
    print(f"   Package directory: {package_dir}")
    print(f"   Options: {', '.join(k for k, v in options.items() if v) or 'none'}")
    print()
    
    # Create directories
    (package_dir / 'src' / 'Facades').mkdir(parents=True, exist_ok=True)
    (package_dir / 'src' / 'Commands').mkdir(parents=True, exist_ok=True)
    
    if options.get('with_config'):
        (package_dir / 'config').mkdir(parents=True, exist_ok=True)
    
    if options.get('with_pest'):
        (package_dir / 'tests' / 'Unit').mkdir(parents=True, exist_ok=True)
        (package_dir / 'tests' / 'Feature').mkdir(parents=True, exist_ok=True)
    
    # Generate files
    print("📁 Creating package files...")
    
    # Core files
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
    
    write_file(package_dir / 'README.md', create_readme(namespace, package_name, php_namespace, options))
    write_file(package_dir / '.gitignore', create_gitignore())
    write_file(package_dir / 'LICENSE', create_license())
    
    # Optional: Facade
    if options.get('with_facade'):
        write_file(
            package_dir / 'src' / 'Facades' / f'{class_name}.php',
            create_facade(php_namespace, package_name)
        )
    
    # Optional: Config
    if options.get('with_config'):
        write_file(
            package_dir / 'config' / f'{package_name}.php',
            create_config_file(package_name)
        )
    
    # Optional: Command
    if options.get('with_command'):
        write_file(
            package_dir / 'src' / 'Commands' / 'InstallCommand.php',
            create_install_command(php_namespace, package_name)
        )
    
    # Optional: Testing
    if options.get('with_pest'):
        print("\n🧪 Setting up PestPHP testing...")
        write_file(package_dir / 'phpunit.xml', create_phpunit_xml(php_namespace))
        write_file(package_dir / 'tests' / 'Pest.php', create_pest_php(php_namespace))
        write_file(package_dir / 'tests' / 'TestCase.php', create_test_case(php_namespace, package_name))
        write_file(package_dir / 'tests' / 'Unit' / 'ExampleTest.php', create_example_test(php_namespace, package_name))
    
    # Update project composer.json
    print("\n📦 Updating project composer.json...")
    if update_project_composer(project_root, namespace, package_name):
        print("✓ Project composer.json updated")
    else:
        print("⚠ Could not update project composer.json (file not found)")
    
    # Success message
    print(f"\n✅ Package '{namespace}/{package_name}' created successfully!")
    print("\n📋 Next steps:")
    print("   1. Run: composer update")
    
    if options.get('with_command'):
        print(f"   2. Run: php artisan {package_name}:install")
    
    if options.get('with_config'):
        print(f"   3. Publish config: php artisan vendor:publish --tag={package_name}-config")
    
    if options.get('with_pest'):
        print(f"   4. Run tests:")
        print(f"      cd packages/{namespace}/{package_name}")
        print(f"      composer install")
        print(f"      ./vendor/bin/pest")
    
    return True


def parse_args(args: list) -> tuple:
    """Parse command line arguments."""
    options = {
        'with_pest': False,
        'with_facade': False,
        'with_config': False,
        'with_command': False,
    }
    
    input_name = None
    project_root = None
    
    i = 0
    while i < len(args):
        arg = args[i]
        
        if arg == '--with-pest':
            options['with_pest'] = True
        elif arg == '--with-facade':
            options['with_facade'] = True
        elif arg == '--with-config':
            options['with_config'] = True
        elif arg == '--with-command':
            options['with_command'] = True
        elif arg == '--all':
            options = {k: True for k in options}
        elif arg == '--project-root' and i + 1 < len(args):
            i += 1
            project_root = Path(args[i])
        elif not arg.startswith('--') and input_name is None:
            input_name = arg
        
        i += 1
    
    return input_name, project_root, options


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_laravel_package.py vendor/package-name [options]")
        print("\nOptions:")
        print("  --with-pest     Include PestPHP testing setup")
        print("  --with-facade   Include Facade class")
        print("  --with-config   Include config file")
        print("  --with-command  Include install command")
        print("  --all           Include all optional features")
        print("  --project-root  Specify project root directory")
        print("\nExample:")
        print("  python3 scaffold_laravel_package.py mwguerra/my-package --with-pest --with-facade")
        sys.exit(1)
    
    input_name, project_root, options = parse_args(sys.argv[1:])
    
    if not input_name:
        print("Error: Package name required in format 'vendor/package-name'")
        sys.exit(1)
    
    success = scaffold_package(input_name, project_root, options)
    sys.exit(0 if success else 1)
