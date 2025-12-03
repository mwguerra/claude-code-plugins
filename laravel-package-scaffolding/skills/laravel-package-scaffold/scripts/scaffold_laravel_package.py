#!/usr/bin/env python3
"""
Laravel Package Scaffold Script

Creates a complete Laravel package skeleton with ServiceProvider and test command.
Also updates the project's composer.json to include the package as a path repository.

Usage:
    python3 scaffold_laravel_package.py namespace/package-name

Example:
    python3 scaffold_laravel_package.py mwguerra/filament-pages
"""

import json
import os
import re
import sys
from pathlib import Path


def to_pascal_case(name: str) -> str:
    """Convert package-name to PackageName."""
    return ''.join(word.capitalize() for word in name.split('-'))


def to_studly_case(name: str) -> str:
    """Convert namespace to StudlyCase (for PHP namespaces)."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def create_composer_json(namespace: str, package_name: str, php_namespace: str) -> dict:
    """Generate the package's composer.json content."""
    return {
        "name": f"{namespace}/{package_name}",
        "description": f"A Laravel package: {package_name}",
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
            "illuminate/support": "^10.0|^11.0|^12.0"
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


def create_service_provider(php_namespace: str, package_name: str) -> str:
    """Generate the ServiceProvider PHP code."""
    class_name = to_pascal_case(package_name)
    return f'''<?php

namespace {php_namespace};

use Illuminate\\Support\\ServiceProvider;
use {php_namespace}\\Commands\\TestCommand;

class {class_name}ServiceProvider extends ServiceProvider
{{
    public function register(): void
    {{
        //
    }}

    public function boot(): void
    {{
        if ($this->app->runningInConsole()) {{
            $this->commands([
                TestCommand::class,
            ]);
        }}
    }}
}}
'''


def create_test_command(php_namespace: str, package_name: str) -> str:
    """Generate the TestCommand PHP code."""
    class_name = to_pascal_case(package_name)
    return f'''<?php

namespace {php_namespace}\\Commands;

use Illuminate\\Console\\Command;

class TestCommand extends Command
{{
    protected $signature = '{package_name}:test';

    protected $description = 'Test command to verify the package is working';

    public function handle(): int
    {{
        $this->info('{class_name} package is working correctly!');
        $this->info('Command executed from: ' . __DIR__);

        return self::SUCCESS;
    }}
}}
'''


def update_project_composer(project_root: Path, namespace: str, package_name: str) -> bool:
    """Update the project's composer.json with the new package."""
    composer_path = project_root / 'composer.json'
    
    if not composer_path.exists():
        print(f"Error: Project composer.json not found at {composer_path}")
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


def scaffold_package(input_name: str, project_root: Path = None) -> bool:
    """
    Main function to scaffold a Laravel package.
    
    Args:
        input_name: Package name in format 'namespace/package-name'
        project_root: Root directory of the Laravel project (defaults to current directory)
    
    Returns:
        True if successful, False otherwise
    """
    # Parse input
    if '/' not in input_name:
        print("Error: Input must be in format 'namespace/package-name'")
        return False
    
    namespace, package_name = input_name.split('/', 1)
    
    # Validate
    if not namespace or not package_name:
        print("Error: Both namespace and package-name are required")
        return False
    
    # Set project root
    if project_root is None:
        project_root = Path.cwd()
    
    # Generate PHP namespace (StudlyCase for both parts)
    php_namespace = f"{to_studly_case(namespace)}\\{to_pascal_case(package_name)}"
    
    # Create package directory
    package_dir = project_root / 'packages' / namespace / package_name
    src_dir = package_dir / 'src'
    commands_dir = src_dir / 'Commands'
    
    print(f"Creating package: {namespace}/{package_name}")
    print(f"PHP Namespace: {php_namespace}")
    print(f"Package directory: {package_dir}")
    
    # Create directories
    commands_dir.mkdir(parents=True, exist_ok=True)
    
    # Create composer.json
    composer_content = create_composer_json(namespace, package_name, php_namespace)
    with open(package_dir / 'composer.json', 'w') as f:
        json.dump(composer_content, f, indent=4)
    print(f"✓ Created: {package_dir / 'composer.json'}")
    
    # Create ServiceProvider
    service_provider_content = create_service_provider(php_namespace, package_name)
    service_provider_file = src_dir / f"{to_pascal_case(package_name)}ServiceProvider.php"
    with open(service_provider_file, 'w') as f:
        f.write(service_provider_content)
    print(f"✓ Created: {service_provider_file}")
    
    # Create TestCommand
    test_command_content = create_test_command(php_namespace, package_name)
    test_command_file = commands_dir / 'TestCommand.php'
    with open(test_command_file, 'w') as f:
        f.write(test_command_content)
    print(f"✓ Created: {test_command_file}")
    
    # Update project composer.json
    print("\nUpdating project composer.json...")
    if update_project_composer(project_root, namespace, package_name):
        print("✓ Updated project composer.json")
    else:
        print("✗ Failed to update project composer.json")
        return False
    
    print(f"\n✅ Package '{namespace}/{package_name}' created successfully!")
    print("\nNext steps:")
    print("  1. Run: composer update")
    print(f"  2. Test: php artisan {package_name}:test")
    
    return True


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_laravel_package.py namespace/package-name")
        print("Example: python3 scaffold_laravel_package.py mwguerra/filament-pages")
        sys.exit(1)
    
    input_name = sys.argv[1]
    project_root = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    
    success = scaffold_package(input_name, project_root)
    sys.exit(0 if success else 1)
