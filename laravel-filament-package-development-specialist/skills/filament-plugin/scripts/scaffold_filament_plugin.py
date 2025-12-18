#!/usr/bin/env python3
"""
Filament Plugin Scaffold Script

Creates a complete Filament v3 plugin skeleton with Plugin class, ServiceProvider,
Resources, Pages, Widgets, and PestPHP testing setup.

Usage:
    python3 scaffold_filament_plugin.py vendor/plugin-name [options]

Options:
    --with-resource <n> Include a sample Resource
    --with-page         Include a sample custom Page
    --with-widget       Include a sample Widget
    --with-livewire     Include Livewire component structure
    --no-pest           Exclude PestPHP testing

Example:
    python3 scaffold_filament_plugin.py mwguerra/filament-blog --with-resource Post
"""

import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime


def to_pascal_case(name: str) -> str:
    """Convert plugin-name to PluginName."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def to_studly_case(name: str) -> str:
    """Convert namespace to StudlyCase."""
    return ''.join(word.capitalize() for word in re.split(r'[-_]', name))


def to_snake_case(name: str) -> str:
    """Convert PluginName to plugin_name."""
    s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


def to_kebab_case(name: str) -> str:
    """Convert PluginName to plugin-name."""
    return to_snake_case(name).replace('_', '-')


def create_composer_json(namespace: str, plugin_name: str, php_namespace: str, options: dict) -> dict:
    """Generate the plugin's composer.json content."""
    class_name = to_pascal_case(plugin_name)
    
    composer = {
        "name": f"{namespace}/{plugin_name}",
        "description": f"A Filament plugin: {class_name}",
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
            "filament/filament": "^3.0|^4.0",
            "illuminate/support": "^11.0|^12.0",
            "livewire/livewire": "^3.6",
            "spatie/laravel-package-tools": "^1.18"
        },
        "autoload": {
            "psr-4": {
                f"{php_namespace}\\": "src/"
            }
        },
        "extra": {
            "laravel": {
                "providers": [
                    f"{php_namespace}\\{class_name}ServiceProvider"
                ]
            }
        },
        "minimum-stability": "dev",
        "prefer-stable": True
    }
    
    if not options.get('no_pest', False):
        composer["require-dev"] = {
            "orchestra/testbench": "^10.0|^11.0",
            "pestphp/pest": "^3.0|^4.0",
            "pestphp/pest-plugin-laravel": "^3.0|^4.0",
            "pestphp/pest-plugin-livewire": "^3.0|^4.0"
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


def create_plugin_class(php_namespace: str, plugin_name: str, options: dict) -> str:
    """Generate the main Plugin class."""
    class_name = to_pascal_case(plugin_name)
    
    resources = []
    pages = []
    widgets = []
    uses = [
        "use Filament\\Contracts\\Plugin;",
        "use Filament\\Panel;",
    ]
    
    if options.get('resource_name'):
        resource_name = to_pascal_case(options['resource_name'])
        resources.append(f"Resources\\{resource_name}Resource::class")
        uses.append(f"use {php_namespace}\\Resources\\{resource_name}Resource;")
    
    if options.get('with_page'):
        uses.append(f"use {php_namespace}\\Pages\\SettingsPage;")
        pages.append("Pages\\SettingsPage::class")
    
    if options.get('with_widget'):
        uses.append(f"use {php_namespace}\\Widgets\\StatsOverviewWidget;")
        widgets.append("Widgets\\StatsOverviewWidget::class")
    
    uses_str = "\n".join(sorted(set(uses)))
    
    resources_str = ",\n            ".join(resources) if resources else "// Add your resources here"
    pages_str = ",\n            ".join(pages) if pages else "// Add your pages here"
    widgets_str = ",\n            ".join(widgets) if widgets else "// Add your widgets here"
    
    return f'''<?php

namespace {php_namespace};

{uses_str}

class {class_name}Plugin implements Plugin
{{
    public function getId(): string
    {{
        return '{plugin_name}';
    }}

    public function register(Panel $panel): void
    {{
        $panel
            ->resources([
                {resources_str}
            ])
            ->pages([
                {pages_str}
            ])
            ->widgets([
                {widgets_str}
            ]);
    }}

    public function boot(Panel $panel): void
    {{
        //
    }}

    public static function make(): static
    {{
        return app(static::class);
    }}

    public static function get(): static
    {{
        /** @var static $plugin */
        $plugin = filament(app(static::class)->getId());

        return $plugin;
    }}
}}
'''


def create_service_provider(php_namespace: str, plugin_name: str, options: dict) -> str:
    """Generate the ServiceProvider."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

namespace {php_namespace};

use Filament\\Support\\Assets\\AlpineComponent;
use Filament\\Support\\Assets\\Asset;
use Filament\\Support\\Assets\\Css;
use Filament\\Support\\Assets\\Js;
use Filament\\Support\\Facades\\FilamentAsset;
use Filament\\Support\\Facades\\FilamentIcon;
use Illuminate\\Filesystem\\Filesystem;
use Livewire\\Features\\SupportTesting\\Testable;
use Spatie\\LaravelPackageTools\\Commands\\InstallCommand;
use Spatie\\LaravelPackageTools\\Package;
use Spatie\\LaravelPackageTools\\PackageServiceProvider;

class {class_name}ServiceProvider extends PackageServiceProvider
{{
    public static string $name = '{plugin_name}';

    public static string $viewNamespace = '{plugin_name}';

    public function configurePackage(Package $package): void
    {{
        $package->name(static::$name)
            ->hasConfigFile()
            ->hasViews(static::$viewNamespace)
            ->hasTranslations()
            ->hasMigrations($this->getMigrations())
            ->hasCommands($this->getCommands())
            ->hasInstallCommand(function (InstallCommand $command) {{
                $command
                    ->publishConfigFile()
                    ->publishMigrations()
                    ->askToRunMigrations()
                    ->askToStarRepoOnGitHub('{plugin_name}');
            }});
    }}

    public function packageRegistered(): void
    {{
        //
    }}

    public function packageBooted(): void
    {{
        // Asset Registration
        FilamentAsset::register(
            $this->getAssets(),
            $this->getAssetPackageName()
        );

        FilamentAsset::registerScriptData(
            $this->getScriptData(),
            $this->getAssetPackageName()
        );

        // Icon Registration
        FilamentIcon::register($this->getIcons());

        // Handle Stubs
        if (app()->runningInConsole()) {{
            foreach (app(Filesystem::class)->files(__DIR__ . '/../stubs/') as $file) {{
                $this->publishes([
                    $file->getRealPath() => base_path("stubs/{plugin_name}/{{$file->getFilename()}}"),
                ], '{plugin_name}-stubs');
            }}
        }}

        // Testing
        Testable::mixin(new TestsPluginName());
    }}

    protected function getAssetPackageName(): ?string
    {{
        return '{plugin_name}';
    }}

    /**
     * @return array<Asset>
     */
    protected function getAssets(): array
    {{
        return [
            AlpineComponent::make('{plugin_name}', __DIR__ . '/../resources/dist/{plugin_name}.js'),
            Css::make('{plugin_name}', __DIR__ . '/../resources/dist/{plugin_name}.css')->loadedOnRequest(),
        ];
    }}

    /**
     * @return array<class-string>
     */
    protected function getCommands(): array
    {{
        return [
            // Commands\\{class_name}Command::class,
        ];
    }}

    /**
     * @return array<string>
     */
    protected function getIcons(): array
    {{
        return [];
    }}

    /**
     * @return array<string>
     */
    protected function getRoutes(): array
    {{
        return [];
    }}

    /**
     * @return array<string, mixed>
     */
    protected function getScriptData(): array
    {{
        return [];
    }}

    /**
     * @return array<string>
     */
    protected function getMigrations(): array
    {{
        return [
            // 'create_{to_snake_case(plugin_name)}_table',
        ];
    }}
}}
'''


def create_tests_plugin_name(php_namespace: str, plugin_name: str) -> str:
    """Generate the TestsPluginName mixin class."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

namespace {php_namespace};

/**
 * @method \\{php_namespace}\\{class_name}Plugin plugin()
 */
class TestsPluginName
{{
    public function plugin(): \\Closure
    {{
        return function (): {class_name}Plugin {{
            /** @var \\Livewire\\Features\\SupportTesting\\Testable $this */
            return {class_name}Plugin::get();
        }};
    }}
}}
'''


def create_facade(php_namespace: str, plugin_name: str) -> str:
    """Generate the Facade."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

namespace {php_namespace}\\Facades;

use Illuminate\\Support\\Facades\\Facade;

/**
 * @see \\{php_namespace}\\{class_name}Plugin
 */
class {class_name} extends Facade
{{
    protected static function getFacadeAccessor(): string
    {{
        return '{plugin_name}';
    }}
}}
'''


def create_config_file(plugin_name: str) -> str:
    """Generate the config file."""
    return f'''<?php

return [
    /*
    |--------------------------------------------------------------------------
    | {to_pascal_case(plugin_name)} Configuration
    |--------------------------------------------------------------------------
    |
    | Configure your Filament plugin settings here.
    |
    */

    'enabled' => env('{to_snake_case(plugin_name).upper()}_ENABLED', true),

    // Add your configuration options here
];
'''


def create_resource(php_namespace: str, plugin_name: str, resource_name: str) -> str:
    """Generate a Filament Resource."""
    class_name = to_pascal_case(resource_name)
    
    return f'''<?php

namespace {php_namespace}\\Resources;

use {php_namespace}\\Resources\\{class_name}Resource\\Pages;
use Filament\\Forms;
use Filament\\Forms\\Form;
use Filament\\Resources\\Resource;
use Filament\\Tables;
use Filament\\Tables\\Table;
use Illuminate\\Database\\Eloquent\\Builder;
use Illuminate\\Database\\Eloquent\\Model;

class {class_name}Resource extends Resource
{{
    // protected static ?string $model = {class_name}::class;

    protected static ?string $navigationIcon = 'heroicon-o-rectangle-stack';

    protected static ?string $navigationGroup = '{to_pascal_case(plugin_name)}';

    public static function form(Form $form): Form
    {{
        return $form
            ->schema([
                Forms\\Components\\Section::make()
                    ->schema([
                        Forms\\Components\\TextInput::make('name')
                            ->required()
                            ->maxLength(255),
                        Forms\\Components\\Textarea::make('description')
                            ->maxLength(65535)
                            ->columnSpanFull(),
                        Forms\\Components\\Toggle::make('is_active')
                            ->default(true),
                    ])
                    ->columns(2),
            ]);
    }}

    public static function table(Table $table): Table
    {{
        return $table
            ->columns([
                Tables\\Columns\\TextColumn::make('name')
                    ->searchable()
                    ->sortable(),
                Tables\\Columns\\IconColumn::make('is_active')
                    ->boolean(),
                Tables\\Columns\\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\\Columns\\TextColumn::make('updated_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\\Filters\\TernaryFilter::make('is_active'),
            ])
            ->actions([
                Tables\\Actions\\EditAction::make(),
                Tables\\Actions\\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\\Actions\\BulkActionGroup::make([
                    Tables\\Actions\\DeleteBulkAction::make(),
                ]),
            ]);
    }}

    public static function getRelations(): array
    {{
        return [
            //
        ];
    }}

    public static function getPages(): array
    {{
        return [
            'index' => Pages\\List{class_name}s::route('/'),
            'create' => Pages\\Create{class_name}::route('/create'),
            'edit' => Pages\\Edit{class_name}::route('/{{record}}/edit'),
        ];
    }}
}}
'''


def create_resource_pages(php_namespace: str, plugin_name: str, resource_name: str) -> dict:
    """Generate Resource pages."""
    class_name = to_pascal_case(resource_name)
    
    return {
        f'List{class_name}s.php': f'''<?php

namespace {php_namespace}\\Resources\\{class_name}Resource\\Pages;

use {php_namespace}\\Resources\\{class_name}Resource;
use Filament\\Actions;
use Filament\\Resources\\Pages\\ListRecords;

class List{class_name}s extends ListRecords
{{
    protected static string $resource = {class_name}Resource::class;

    protected function getHeaderActions(): array
    {{
        return [
            Actions\\CreateAction::make(),
        ];
    }}
}}
''',
        f'Create{class_name}.php': f'''<?php

namespace {php_namespace}\\Resources\\{class_name}Resource\\Pages;

use {php_namespace}\\Resources\\{class_name}Resource;
use Filament\\Resources\\Pages\\CreateRecord;

class Create{class_name} extends CreateRecord
{{
    protected static string $resource = {class_name}Resource::class;
}}
''',
        f'Edit{class_name}.php': f'''<?php

namespace {php_namespace}\\Resources\\{class_name}Resource\\Pages;

use {php_namespace}\\Resources\\{class_name}Resource;
use Filament\\Actions;
use Filament\\Resources\\Pages\\EditRecord;

class Edit{class_name} extends EditRecord
{{
    protected static string $resource = {class_name}Resource::class;

    protected function getHeaderActions(): array
    {{
        return [
            Actions\\DeleteAction::make(),
        ];
    }}
}}
'''
    }


def create_page(php_namespace: str, plugin_name: str) -> str:
    """Generate a custom Filament Page."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

namespace {php_namespace}\\Pages;

use Filament\\Pages\\Page;

class SettingsPage extends Page
{{
    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationGroup = '{class_name}';

    protected static ?int $navigationSort = 99;

    protected static string $view = '{plugin_name}::pages.settings';

    public function getTitle(): string
    {{
        return __('{{plugin_name}::messages.settings.title');
    }}

    public static function getNavigationLabel(): string
    {{
        return __('{{plugin_name}::messages.settings.navigation');
    }}
}}
'''


def create_page_view(plugin_name: str) -> str:
    """Generate the page view."""
    return f'''<x-filament-panels::page>
    <x-filament::section>
        <x-slot name="heading">
            {{{{ __('{{plugin_name}::messages.settings.heading') }}}}
        </x-slot>

        <p>
            {{{{ __('{{plugin_name}::messages.settings.description') }}}}
        </p>
    </x-filament::section>
</x-filament-panels::page>
'''


def create_widget(php_namespace: str, plugin_name: str) -> str:
    """Generate a Filament Widget."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

namespace {php_namespace}\\Widgets;

use Filament\\Widgets\\StatsOverviewWidget as BaseWidget;
use Filament\\Widgets\\StatsOverviewWidget\\Stat;

class StatsOverviewWidget extends BaseWidget
{{
    protected static ?string $pollingInterval = '30s';

    protected function getStats(): array
    {{
        return [
            Stat::make(__('{{plugin_name}::messages.widgets.total'), '0')
                ->description(__('{{plugin_name}::messages.widgets.total_description'))
                ->descriptionIcon('heroicon-m-arrow-trending-up')
                ->color('success'),
            Stat::make(__('{{plugin_name}::messages.widgets.active'), '0')
                ->description(__('{{plugin_name}::messages.widgets.active_description'))
                ->descriptionIcon('heroicon-m-check-circle')
                ->color('info'),
            Stat::make(__('{{plugin_name}::messages.widgets.pending'), '0')
                ->description(__('{{plugin_name}::messages.widgets.pending_description'))
                ->descriptionIcon('heroicon-m-clock')
                ->color('warning'),
        ];
    }}
}}
'''


def create_translations(plugin_name: str) -> str:
    """Generate translation file."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

return [
    'name' => '{class_name}',
    
    'settings' => [
        'title' => '{class_name} Settings',
        'navigation' => 'Settings',
        'heading' => 'Plugin Settings',
        'description' => 'Configure your {class_name} plugin settings here.',
    ],
    
    'widgets' => [
        'total' => 'Total',
        'total_description' => 'Total items',
        'active' => 'Active',
        'active_description' => 'Active items',
        'pending' => 'Pending',
        'pending_description' => 'Pending items',
    ],
];
'''


def create_phpunit_xml(php_namespace: str) -> str:
    """Generate phpunit.xml."""
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
    """Generate Pest.php."""
    return f'''<?php

use {php_namespace}\\Tests\\TestCase;

uses(TestCase::class)->in(__DIR__);

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
*/

// Custom expectations can be added here

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
*/

// Helper functions can be added here
'''


def create_test_case(php_namespace: str, plugin_name: str) -> str:
    """Generate TestCase."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

namespace {php_namespace}\\Tests;

use BladeUI\\Heroicons\\BladeHeroiconsServiceProvider;
use BladeUI\\Icons\\BladeIconsServiceProvider;
use Filament\\Actions\\ActionsServiceProvider;
use Filament\\FilamentServiceProvider;
use Filament\\Forms\\FormsServiceProvider;
use Filament\\Infolists\\InfolistsServiceProvider;
use Filament\\Notifications\\NotificationsServiceProvider;
use Filament\\Support\\SupportServiceProvider;
use Filament\\Tables\\TablesServiceProvider;
use Filament\\Widgets\\WidgetsServiceProvider;
use Livewire\\LivewireServiceProvider;
use Orchestra\\Testbench\\TestCase as Orchestra;
use {php_namespace}\\{class_name}ServiceProvider;

class TestCase extends Orchestra
{{
    protected function setUp(): void
    {{
        parent::setUp();
    }}

    protected function getPackageProviders($app): array
    {{
        return [
            ActionsServiceProvider::class,
            BladeHeroiconsServiceProvider::class,
            BladeIconsServiceProvider::class,
            FilamentServiceProvider::class,
            FormsServiceProvider::class,
            InfolistsServiceProvider::class,
            LivewireServiceProvider::class,
            NotificationsServiceProvider::class,
            SupportServiceProvider::class,
            TablesServiceProvider::class,
            WidgetsServiceProvider::class,
            {class_name}ServiceProvider::class,
        ];
    }}

    public function getEnvironmentSetUp($app): void
    {{
        config()->set('database.default', 'testing');
        config()->set('database.connections.testing', [
            'driver' => 'sqlite',
            'database' => ':memory:',
            'prefix' => '',
        ]);
    }}
}}
'''


def create_example_test(php_namespace: str, plugin_name: str) -> str:
    """Generate example test."""
    class_name = to_pascal_case(plugin_name)
    
    return f'''<?php

use {php_namespace}\\{class_name}Plugin;

test('plugin can be instantiated', function () {{
    $plugin = {class_name}Plugin::make();
    
    expect($plugin)->toBeInstanceOf({class_name}Plugin::class);
}});

test('plugin has correct id', function () {{
    $plugin = {class_name}Plugin::make();
    
    expect($plugin->getId())->toBe('{plugin_name}');
}});

test('environment is configured correctly', function () {{
    expect(config('app.env'))->toBe('testing');
}});
'''


def create_readme(namespace: str, plugin_name: str, php_namespace: str, options: dict) -> str:
    """Generate README.md."""
    class_name = to_pascal_case(plugin_name)
    
    resource_section = ""
    if options.get('resource_name'):
        resource_section = f"""
## Resources

This plugin provides the following Filament Resources:

- `{to_pascal_case(options['resource_name'])}Resource` - Manage {options['resource_name']}s
"""
    
    return f'''# {class_name}

[![Latest Version on Packagist](https://img.shields.io/packagist/v/{namespace}/{plugin_name}.svg?style=flat-square)](https://packagist.org/packages/{namespace}/{plugin_name})
[![Total Downloads](https://img.shields.io/packagist/dt/{namespace}/{plugin_name}.svg?style=flat-square)](https://packagist.org/packages/{namespace}/{plugin_name})

A Filament v3 plugin: {class_name}

## Installation

You can install the package via composer:

```bash
composer require {namespace}/{plugin_name}
```

## Configuration

Publish the configuration file:

```bash
php artisan vendor:publish --tag={plugin_name}-config
```

Optionally, publish the migrations:

```bash
php artisan vendor:publish --tag={plugin_name}-migrations
```

## Usage

Register the plugin in your Panel Provider:

```php
use {php_namespace}\\{class_name}Plugin;

public function panel(Panel $panel): Panel
{{
    return $panel
        // ...
        ->plugins([
            {class_name}Plugin::make(),
        ]);
}}
```
{resource_section}
## Testing

```bash
composer test
```

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
    """Generate .gitignore."""
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
/resources/dist/
'''


def create_license() -> str:
    """Generate LICENSE."""
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


def update_project_composer(project_root: Path, namespace: str, plugin_name: str) -> bool:
    """Update project composer.json."""
    composer_path = project_root / 'composer.json'
    
    if not composer_path.exists():
        print(f"Warning: Project composer.json not found at {composer_path}")
        return False
    
    with open(composer_path, 'r') as f:
        composer_data = json.load(f)
    
    if 'repositories' not in composer_data:
        composer_data['repositories'] = []
    
    package_url = f"packages/{namespace}/{plugin_name}"
    repo_exists = any(
        repo.get('url') == package_url 
        for repo in composer_data['repositories'] 
        if isinstance(repo, dict)
    )
    
    if not repo_exists:
        composer_data['repositories'].append({
            "type": "path",
            "url": package_url,
            "options": {"symlink": True}
        })
    
    package_full_name = f"{namespace}/{plugin_name}"
    if 'require' not in composer_data:
        composer_data['require'] = {}
    
    if package_full_name not in composer_data['require']:
        composer_data['require'][package_full_name] = "@dev"
    
    with open(composer_path, 'w') as f:
        json.dump(composer_data, f, indent=4)
    
    return True


def write_file(path: Path, content: str) -> None:
    """Write file with directory creation."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)
    print(f"✓ Created: {path}")


def scaffold_plugin(input_name: str, project_root: Path = None, options: dict = None) -> bool:
    """Main function to scaffold a Filament plugin."""
    options = options or {}
    
    if '/' not in input_name:
        print("Error: Input must be in format 'vendor/plugin-name'")
        return False
    
    namespace, plugin_name = input_name.split('/', 1)
    
    if not namespace or not plugin_name:
        print("Error: Both vendor and plugin-name are required")
        return False
    
    if project_root is None:
        project_root = Path.cwd()
    
    php_namespace = f"{to_studly_case(namespace)}\\{to_pascal_case(plugin_name)}"
    class_name = to_pascal_case(plugin_name)
    
    plugin_dir = project_root / 'packages' / namespace / plugin_name
    
    print(f"\n🚀 Creating Filament Plugin: {namespace}/{plugin_name}")
    print(f"   PHP Namespace: {php_namespace}")
    print(f"   Plugin directory: {plugin_dir}")
    print(f"   Options: {', '.join(k for k, v in options.items() if v) or 'default'}")
    print()
    
    # Create directories
    dirs = [
        'src/Facades',
        'src/Resources',
        'src/Pages',
        'src/Widgets',
        'src/Livewire',
        'src/Commands',
        'config',
        'database/migrations',
        'resources/lang/en',
        'resources/views/pages',
        'stubs',
    ]
    
    if not options.get('no_pest', False):
        dirs.extend(['tests/Unit', 'tests/Feature'])
    
    for d in dirs:
        (plugin_dir / d).mkdir(parents=True, exist_ok=True)
    
    print("📁 Creating plugin files...")
    
    # Core files
    write_file(plugin_dir / 'composer.json', 
               json.dumps(create_composer_json(namespace, plugin_name, php_namespace, options), indent=4))
    write_file(plugin_dir / f'src/{class_name}Plugin.php', 
               create_plugin_class(php_namespace, plugin_name, options))
    write_file(plugin_dir / f'src/{class_name}ServiceProvider.php', 
               create_service_provider(php_namespace, plugin_name, options))
    write_file(plugin_dir / 'src/TestsPluginName.php',
               create_tests_plugin_name(php_namespace, plugin_name))
    write_file(plugin_dir / f'src/Facades/{class_name}.php', 
               create_facade(php_namespace, plugin_name))
    write_file(plugin_dir / f'config/{plugin_name}.php', 
               create_config_file(plugin_name))
    write_file(plugin_dir / 'resources/lang/en/messages.php', 
               create_translations(plugin_name))
    write_file(plugin_dir / 'README.md', 
               create_readme(namespace, plugin_name, php_namespace, options))
    write_file(plugin_dir / '.gitignore', create_gitignore())
    write_file(plugin_dir / 'LICENSE', create_license())
    
    # Gitkeep files
    for d in ['database/migrations', 'stubs', 'src/Commands', 'src/Livewire']:
        write_file(plugin_dir / d / '.gitkeep', '')
    
    # Resource
    if options.get('resource_name'):
        resource_name = to_pascal_case(options['resource_name'])
        write_file(plugin_dir / f'src/Resources/{resource_name}Resource.php',
                   create_resource(php_namespace, plugin_name, options['resource_name']))
        
        pages_dir = plugin_dir / f'src/Resources/{resource_name}Resource/Pages'
        for filename, content in create_resource_pages(php_namespace, plugin_name, options['resource_name']).items():
            write_file(pages_dir / filename, content)
    else:
        write_file(plugin_dir / 'src/Resources/.gitkeep', '')
    
    # Page
    if options.get('with_page'):
        write_file(plugin_dir / 'src/Pages/SettingsPage.php',
                   create_page(php_namespace, plugin_name))
        write_file(plugin_dir / 'resources/views/pages/settings.blade.php',
                   create_page_view(plugin_name))
    else:
        write_file(plugin_dir / 'src/Pages/.gitkeep', '')
    
    # Widget
    if options.get('with_widget'):
        write_file(plugin_dir / 'src/Widgets/StatsOverviewWidget.php',
                   create_widget(php_namespace, plugin_name))
    else:
        write_file(plugin_dir / 'src/Widgets/.gitkeep', '')
    
    # Testing
    if not options.get('no_pest', False):
        print("\n🧪 Setting up PestPHP testing...")
        write_file(plugin_dir / 'phpunit.xml', create_phpunit_xml(php_namespace))
        write_file(plugin_dir / 'tests/Pest.php', create_pest_php(php_namespace))
        write_file(plugin_dir / 'tests/TestCase.php', create_test_case(php_namespace, plugin_name))
        write_file(plugin_dir / 'tests/Unit/ExampleTest.php', create_example_test(php_namespace, plugin_name))
        write_file(plugin_dir / 'tests/Feature/.gitkeep', '')
    
    # Update project composer
    print("\n📦 Updating project composer.json...")
    if update_project_composer(project_root, namespace, plugin_name):
        print("✓ Project composer.json updated")
    else:
        print("⚠ Could not update project composer.json")
    
    print(f"\n✅ Filament Plugin '{namespace}/{plugin_name}' created successfully!")
    print("\n📋 Next steps:")
    print("   1. Run: composer update")
    print(f"   2. Register plugin in your Panel Provider:")
    print(f"      ->plugins([{class_name}Plugin::make()])")
    print(f"   3. Publish config: php artisan vendor:publish --tag={plugin_name}-config")
    
    if not options.get('no_pest', False):
        print(f"   4. Run tests:")
        print(f"      cd packages/{namespace}/{plugin_name}")
        print(f"      composer install")
        print(f"      ./vendor/bin/pest")
    
    return True


def parse_args(args: list) -> tuple:
    """Parse command line arguments."""
    options = {
        'resource_name': None,
        'with_page': False,
        'with_widget': False,
        'with_livewire': False,
        'no_pest': False,
    }
    
    input_name = None
    project_root = None
    
    i = 0
    while i < len(args):
        arg = args[i]
        
        if arg == '--with-resource' and i + 1 < len(args):
            i += 1
            options['resource_name'] = args[i]
        elif arg == '--with-page':
            options['with_page'] = True
        elif arg == '--with-widget':
            options['with_widget'] = True
        elif arg == '--with-livewire':
            options['with_livewire'] = True
        elif arg == '--no-pest':
            options['no_pest'] = True
        elif arg == '--project-root' and i + 1 < len(args):
            i += 1
            project_root = Path(args[i])
        elif not arg.startswith('--') and input_name is None:
            input_name = arg
        
        i += 1
    
    return input_name, project_root, options


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 scaffold_filament_plugin.py vendor/plugin-name [options]")
        print("\nOptions:")
        print("  --with-resource <n> Include a sample Resource")
        print("  --with-page         Include a sample custom Page")
        print("  --with-widget       Include a sample Widget")
        print("  --with-livewire     Include Livewire component structure")
        print("  --no-pest           Exclude PestPHP testing")
        print("  --project-root      Specify project root directory")
        print("\nExample:")
        print("  python3 scaffold_filament_plugin.py mwguerra/filament-blog --with-resource Post")
        sys.exit(1)
    
    input_name, project_root, options = parse_args(sys.argv[1:])
    
    if not input_name:
        print("Error: Plugin name required in format 'vendor/plugin-name'")
        sys.exit(1)
    
    success = scaffold_plugin(input_name, project_root, options)
    sys.exit(0 if success else 1)
