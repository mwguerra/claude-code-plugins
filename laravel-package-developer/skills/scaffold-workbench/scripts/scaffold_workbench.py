#!/usr/bin/env python3
"""
Workbench Scaffold Script

Adds Orchestra Workbench (testbench.yaml + workbench/) to an existing Laravel
package for interactive development.

Usage:
    python3 scaffold_workbench.py vendor/package-name [options]

Options:
    --project-root   Specify project root directory

Example:
    python3 scaffold_workbench.py mwguerra/my-package
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


# ---------------------------------------------------------------------------
# File content generators
# ---------------------------------------------------------------------------

def create_testbench_yaml(package_name: str) -> str:
    """Generate testbench.yaml configuration."""
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
    web: true
    api: false
    commands: false
    components: false
    views: false
  build:
    - create-sqlite-db
    - migrate:fresh
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


def create_database_seeder() -> str:
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


def create_welcome_view(package_name: str) -> str:
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


# ---------------------------------------------------------------------------
# Composer.json updater
# ---------------------------------------------------------------------------

def update_composer_json(composer_path: Path) -> bool:
    """Add workbench autoload and scripts to composer.json."""
    if not composer_path.exists():
        print(f"Error: composer.json not found at {composer_path}")
        return False

    with open(composer_path, 'r') as f:
        composer_data = json.load(f)

    # Ensure testbench is in require-dev
    if 'require-dev' not in composer_data:
        composer_data['require-dev'] = {}

    if 'orchestra/testbench' not in composer_data['require-dev']:
        composer_data['require-dev']['orchestra/testbench'] = "^10.0"

    # Add workbench autoload-dev namespaces
    if 'autoload-dev' not in composer_data:
        composer_data['autoload-dev'] = {}
    if 'psr-4' not in composer_data['autoload-dev']:
        composer_data['autoload-dev']['psr-4'] = {}

    workbench_namespaces = {
        "Workbench\\App\\": "workbench/app/",
        "Workbench\\Database\\Seeders\\": "workbench/database/seeders/",
        "Workbench\\Database\\Factories\\": "workbench/database/factories/"
    }

    for ns, path in workbench_namespaces.items():
        if ns not in composer_data['autoload-dev']['psr-4']:
            composer_data['autoload-dev']['psr-4'][ns] = path

    # Add workbench scripts
    if 'scripts' not in composer_data:
        composer_data['scripts'] = {}

    workbench_scripts = {
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
        ]
    }

    for key, value in workbench_scripts.items():
        if key not in composer_data['scripts']:
            composer_data['scripts'][key] = value

    with open(composer_path, 'w') as f:
        json.dump(composer_data, f, indent=4)

    return True


# ---------------------------------------------------------------------------
# File writing helper
# ---------------------------------------------------------------------------

def write_file(path: Path, content: str) -> None:
    """Write file with directory creation."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)
    print(f"  Created: {path}")


def write_gitkeep(path: Path) -> None:
    """Create an empty .gitkeep file."""
    write_file(path / '.gitkeep', '')


# ---------------------------------------------------------------------------
# Main function
# ---------------------------------------------------------------------------

def setup_workbench(input_name: str, project_root: Path = None) -> bool:
    """Main function to set up Workbench."""

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

    # Check for existing workbench
    if (package_dir / 'testbench.yaml').exists():
        print(f"Warning: testbench.yaml already exists at {package_dir}")
        print("  Skipping to avoid overwriting existing configuration.")
        print("  Delete testbench.yaml and workbench/ if you want to re-scaffold.")
        return False

    composer_path = package_dir / 'composer.json'
    if not composer_path.exists():
        print(f"Error: composer.json not found in {package_dir}")
        return False

    print(f"\n  Setting up Workbench for: {namespace}/{package_name}")
    print(f"  Package directory: {package_dir}")
    print()

    # Create workbench directory structure
    print("  Creating workbench files...")

    (package_dir / 'workbench' / 'app' / 'Models').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'app' / 'Providers').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'database' / 'factories').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'database' / 'migrations').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'database' / 'seeders').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'resources' / 'views').mkdir(parents=True, exist_ok=True)
    (package_dir / 'workbench' / 'routes').mkdir(parents=True, exist_ok=True)

    # Write files
    write_file(package_dir / 'testbench.yaml', create_testbench_yaml(package_name))
    write_file(
        package_dir / 'workbench' / 'app' / 'Providers' / 'WorkbenchServiceProvider.php',
        create_workbench_service_provider()
    )
    write_file(
        package_dir / 'workbench' / 'database' / 'seeders' / 'DatabaseSeeder.php',
        create_database_seeder()
    )
    write_file(
        package_dir / 'workbench' / 'resources' / 'views' / 'welcome.blade.php',
        create_welcome_view(package_name)
    )
    write_file(package_dir / 'workbench' / 'routes' / 'web.php', create_workbench_routes())
    write_gitkeep(package_dir / 'workbench' / 'app' / 'Models')
    write_gitkeep(package_dir / 'workbench' / 'database' / 'factories')
    write_gitkeep(package_dir / 'workbench' / 'database' / 'migrations')

    # Update composer.json
    print("\n  Updating composer.json...")
    if update_composer_json(composer_path):
        print("  composer.json updated with workbench config")
    else:
        return False

    print(f"\n  Workbench setup complete!")
    print("\n  Next steps:")
    print(f"  1. Install dependencies:")
    print(f"     cd packages/{namespace}/{package_name}")
    print(f"     composer update")
    print(f"  2. Serve the workbench:")
    print(f"     composer serve")
    print(f"  3. Visit http://127.0.0.1:8000 in your browser")

    return True


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args(args: list) -> tuple:
    """Parse command line arguments."""
    input_name = None
    project_root = None

    i = 0
    while i < len(args):
        arg = args[i]

        if arg == '--project-root' and i + 1 < len(args):
            i += 1
            project_root = Path(args[i])
        elif not arg.startswith('--') and input_name is None:
            input_name = arg

        i += 1

    return input_name, project_root


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_workbench.py vendor/package-name [options]")
        print("\nOptions:")
        print("  --project-root   Specify project root directory")
        print("\nExample:")
        print("  python3 scaffold_workbench.py mwguerra/my-package")
        sys.exit(1)

    input_name, project_root = parse_args(sys.argv[1:])

    if not input_name:
        print("Error: Package name required in format 'vendor/package-name'")
        sys.exit(1)

    success = setup_workbench(input_name, project_root)
    sys.exit(0 if success else 1)
