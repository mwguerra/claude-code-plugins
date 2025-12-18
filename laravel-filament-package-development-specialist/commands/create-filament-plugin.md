---
description: Create a new Filament plugin (panel or standalone) with proper package structure and test setup
argument-hint: <vendor/plugin-name> [--type panel|standalone] [--with-resource <ResourceName>] [--with-page] [--with-widget]
allowed-tools: Bash(python3:*), Bash(php:*), Bash(composer:*), Read, Write, Glob
---

# Create Filament Plugin

Creates a Filament plugin as a **Laravel package**, following Filament’s plugin conventions.

## Input format

`vendor/plugin-name`

Example: `mwguerra/clock-widget`

## Plugin types

- `--type panel` (default): ships a `Plugin` class implementing `Filament\Contracts\Plugin` so users can register it per panel.
- `--type standalone`: ships only package + ServiceProvider (good for custom components / styling / utilities outside panels).

## What gets created

- `composer.json` with Laravel package discovery
- `src/*ServiceProvider.php` using **spatie/laravel-package-tools**
- `src/*Plugin.php` (panel plugins)
- `resources/views` (+ optional `lang/`)
- `resources/dist` for JS/CSS that is registered via `FilamentAsset`
- Optional: sample Resource / Page / Widget scaffolds
- Optional: Pest + Testbench test harness

## How users register it (panel plugins)

In the consuming app’s Panel provider:

```php
public function panel(Panel $panel): Panel
{
    return $panel->plugins([
        \Vendor\Plugin\PluginNamePlugin::make(),
    ]);
}
```

If you generate only a Widget, users may also register the widget directly:

```php
public function panel(Panel $panel): Panel
{
    return $panel->widgets([
        \Vendor\Plugin\Widgets\ExampleWidget::class,
    ]);
}
```

## Notes

- Assets are registered with `Filament\Support\Facades\FilamentAsset` and should be loaded on-demand when possible.
- Tests should be written against Livewire components (Filament is Livewire-first).
