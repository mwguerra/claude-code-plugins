# Laravel 12 + Filament 4 Package Toolkit

A comprehensive Claude Code plugin for creating, developing, and testing Laravel packages and Filament plugins.

## Features

- 🚀 **Laravel Package Scaffolding** - Create complete Laravel package skeletons with ServiceProvider, Facade, Config, and Commands
- 🎨 **Filament Plugin Scaffolding** - Generate Filament **v4** plugins with Resources, Pages, Widgets, and proper structure
- 🧪 **Pest v4 + Testbench ^10 Setup** - Add comprehensive testing infrastructure to any package (Laravel 12 compatible)
- 🤖 **Specialized Agents** - Expert agents for package development, Filament plugins, and test writing
- 🔧 **Auto-formatting** - PHP files are automatically formatted after creation/editing

## Installation

### Via Marketplace

```bash
/plugin marketplace add your-org/laravel-filament-package-toolkit
/plugin install laravel-filament-package-toolkit
```

### Manual Installation

1. Clone this repository to your Claude Code plugins directory
2. Enable the plugin via `/plugin` command

## Commands

### `/laravel-filament-package-development-specialist:create-laravel-package`

Create a new Laravel package with full structure.

```
/laravel-filament-package-development-specialist:create-laravel-package mwguerra/my-package --with-pest --with-facade
```

**Options:**
- `--with-pest` - Include PestPHP testing setup
- `--with-facade` - Include Facade class
- `--with-config` - Include config file
- `--with-command` - Include artisan command
- `--all` - Include all optional features

### `/laravel-filament-package-development-specialist:create-filament-plugin`

Create a new Filament **v4** plugin.

```
/laravel-filament-package-development-specialist:create-filament-plugin mwguerra/filament-blog --with-resource Post --with-widget
```

**Options:**
- `--with-resource <n>` - Include a sample Resource
- `--with-page` - Include a sample custom Page
- `--with-widget` - Include a sample Widget
- `--no-pest` - Exclude PestPHP testing

### `/laravel-filament-package-development-specialist:setup-pest-testing`

Add PestPHP testing to an existing package.

```
/laravel-filament-package-development-specialist:setup-pest-testing mwguerra/my-package --filament --with-ci
```

**Options:**
- `--filament` - Include Filament/Livewire testing utilities
- `--with-coverage` - Add code coverage configuration
- `--with-ci` - Add GitHub Actions CI workflow

### `/laravel-filament-package-development-specialist:run-package-tests`

Run tests for a package.

```
/laravel-filament-package-development-specialist:run-package-tests mwguerra/my-package --coverage
```

### `/laravel-filament-package-development-specialist:package-status`

Check the status and configuration of a package.

```
/laravel-filament-package-development-specialist:package-status mwguerra/my-package
```

### `/laravel-filament-package-development-specialist:add-filament-resource`

Add a Filament Resource to an existing plugin.

```
/laravel-filament-package-development-specialist:add-filament-resource mwguerra/filament-blog BlogPost --with-model
```

## Skills

### Laravel Package Scaffold

Automatically triggered when you mention:
- "create package"
- "scaffold package"
- "new laravel package"
- "package skeleton"

### Filament Plugin Scaffold

Automatically triggered when you mention:
- "create filament plugin"
- "scaffold filament"
- "new filament plugin"
- "admin panel plugin"

### PestPHP Testing Setup

Automatically triggered when you mention:
- "add tests"
- "setup testing"
- "pest setup"
- "testing infrastructure"

## Agents

### Laravel Package Developer

Expert in Laravel package development, ServiceProviders, Facades, and Laravel internals.

```
Use the laravel-package-developer agent to help me create a new package
```

### Filament Plugin Developer

Specialized in Filament (v3/v4), Resources, Pages, Widgets, and the TALL stack.

```
Use the filament-plugin-developer agent to create a custom page
```

### Package Test Writer

Expert in **Pest v4**, **Orchestra Testbench ^10**, and Laravel/Filament testing patterns.

```
Use the package-test-writer agent to write tests for my package
```

## Package Structure

### Laravel Package

```
packages/vendor/package-name/
├── composer.json
├── README.md
├── LICENSE
├── .gitignore
├── config/
│   └── package-name.php
├── src/
│   ├── PackageNameServiceProvider.php
│   ├── PackageName.php
│   ├── Facades/
│   │   └── PackageName.php
│   └── Commands/
│       └── InstallCommand.php
└── tests/
    ├── Pest.php
    ├── TestCase.php
    ├── Unit/
    │   └── ExampleTest.php
    └── Feature/
```

### Filament Plugin

```
packages/vendor/filament-plugin/
├── composer.json
├── README.md
├── LICENSE
├── phpunit.xml
├── config/
│   └── filament-plugin.php
├── database/
│   └── migrations/
├── resources/
│   ├── lang/en/
│   │   └── messages.php
│   └── views/
│       └── pages/
├── src/
│   ├── PluginNamePlugin.php
│   ├── PluginNameServiceProvider.php
│   ├── Facades/
│   ├── Resources/
│   ├── Pages/
│   ├── Widgets/
│   └── Livewire/
└── tests/
    ├── Pest.php
    ├── TestCase.php
    ├── Unit/
    └── Feature/
```

## Testing with PestPHP

### Running Tests

```bash
# Navigate to package
cd packages/vendor/package-name

# Install dependencies
composer install

# Run all tests
./vendor/bin/pest

# Run with coverage
./vendor/bin/pest --coverage

# Run specific test
./vendor/bin/pest --filter="service provider"

# Run in parallel
./vendor/bin/pest --parallel
```

### Writing Tests

```php
// Basic test
test('it does something', function () {
    expect(true)->toBeTrue();
});

// Testing ServiceProvider
test('service provider is registered', function () {
    expect($this->app->bound('my-service'))->toBeTrue();
});

// Testing Commands
test('command runs successfully', function () {
    $this->artisan('my-package:install')
        ->assertSuccessful();
});

// Testing with Database
uses(RefreshDatabase::class);

test('it creates model', function () {
    $model = MyModel::create(['name' => 'Test']);
    
    $this->assertDatabaseHas('my_models', ['name' => 'Test']);
});

// Testing Livewire Components (Filament)
test('component renders', function () {
    Livewire::test(MyComponent::class)
        ->assertSee('Expected text');
});
```

## Project Integration

Packages are automatically:
1. Created in `packages/vendor/package-name/`
2. Added as path repositories in project's `composer.json`
3. Added to `require` block with `@dev` version
4. Symlinked for real-time development

After creating a package, run:

```bash
composer update
```

## Requirements

- PHP 8.2+
- Laravel 12.x
- Filament v4 (for Filament plugins) citeturn1view2
- Composer 2.x

### Testing Dependencies (Latest Versions)

- **Orchestra Testbench ^10.0** - Laravel 12 compatible (Testbench-Core 10.x) citeturn0search12turn0search16
- **PestPHP ^4.0**
- **Pest Plugin Laravel ^4.0**
- **Pest Plugin Livewire ^4.0** - For Filament/Livewire testing

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.
