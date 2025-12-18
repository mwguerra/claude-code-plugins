---
description: Add Pest v4 + Orchestra Testbench (Laravel 12 compatible) testing infrastructure to an existing Laravel package (optionally Filament v4 aware)
argument-hint: <vendor/package-name> [--filament] [--with-ci] [--with-coverage]
allowed-tools: Bash(python3:*), Bash(php:*), Bash(composer:*), Read, Write, Edit, Glob
---

# Setup Pest v4 + Testbench

This command upgrades or installs a **modern** testing harness for a Laravel package:

- **Pest v4** (PHPUnit-based)
- **Orchestra Testbench ^10** (boots a minimal Laravel **12.x** app for package tests)
- A package-ready `tests/TestCase.php`
- `tests/Pest.php`
- `phpunit.xml`
- Optional: Filament v4 test panel wiring

> Notes:
> - Laravel recommends Testbench for “testing packages like they’re installed in a full app”.
> - Testbench-Core’s compatibility table maps Laravel **12.x** to Testbench-Core **10.x**. citeturn0search16turn0search12

## 1) Dev dependencies to require

Add / update these in `require-dev`:

```json
{
  "require-dev": {
    "orchestra/testbench": "^10.0",
    "pestphp/pest": "^4.0",
    "pestphp/pest-plugin-laravel": "^4.0"
  }
}
```

If `--filament` is enabled, also add:

```json
{
  "require-dev": {
    "filament/filament": "^4.0",
    "pestphp/pest-plugin-livewire": "^4.0"
  }
}
```

Filament’s panel builder installation uses `filament/filament:"^4.0"`. citeturn1view2

Run:

```bash
composer update -W
```

## 2) Create the Pest entrypoint

Create `tests/Pest.php`:

```php
<?php

use Vendor\Package\Tests\TestCase;

uses(TestCase::class)->in(__DIR__);
```

## 3) Create a Testbench TestCase

Create `tests/TestCase.php`:

```php
<?php

namespace Vendor\Package\Tests;

use Orchestra\Testbench\TestCase as Orchestra;

abstract class TestCase extends Orchestra
{
    protected function getPackageProviders($app): array
    {
        return [
            // Your package service provider:
            \Vendor\Package\PackageServiceProvider::class,
        ];
    }
}
```

## 4) Filament v4: create a minimal panel for tests (when --filament)

Filament panels are configured via a `PanelProvider`. citeturn1view3

Create `tests/Support/AdminPanelProvider.php`:

```php
<?php

namespace Vendor\Package\Tests\Support;

use Filament\Panel;
use Filament\PanelProvider;

class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->id('admin')
            ->path('admin')
            ->login();
    }
}
```

Then, in `tests/TestCase.php`, register Filament + the panel provider:

```php
protected function getPackageProviders($app): array
{
    return [
        // Filament:
        \Filament\FilamentServiceProvider::class,
        \Vendor\Package\Tests\Support\AdminPanelProvider::class,

        // Your package:
        \Vendor\Package\PackageServiceProvider::class,
    ];
}
```

If the package is a **panel plugin** (implements `Filament\Contracts\Plugin`), register it in the panel provider:

```php
return $panel
    ->id('admin')
    ->path('admin')
    ->login()
    ->plugins([
        \Vendor\Package\PackagePlugin::make(),
    ]);
```

## 5) Add a smoke test

Create `tests/SmokeTest.php`:

```php
<?php

it('boots the package service provider', function () {
    expect(app()->getProviders(\Vendor\Package\PackageServiceProvider::class))->not->toBeEmpty();
});
```

For `--filament`, add at least one HTTP test that the panel route is registered:

```php
it('registers the admin panel route', function () {
    $this->get('/admin')->assertStatus(200);
});
```

## 6) Quality gates

If `--with-ci` is enabled, add a GitHub Actions workflow that runs:

```bash
composer validate --strict
composer test
```

If `--with-coverage` is enabled, configure Xdebug/PCOV and add a coverage step.
