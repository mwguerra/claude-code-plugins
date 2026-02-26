# Laravel Package Developer

A Claude Code plugin for the full lifecycle of **Laravel package development for Packagist** — from scaffolding to publishing. Targets the latest stack: **PHP 8.3**, **Laravel 12**, **Pest v4**, **Orchestra Testbench v10**, and **Workbench**.

## Features

- Scaffold complete Laravel packages with a single command
- Testing always on — Pest v4 + Testbench v10 pre-configured
- Workbench always on — interactive development environment included
- Optional Playwright browser testing
- Add features (routes, commands, models, etc.) with ServiceProvider auto-wiring
- Health checks and publish readiness validation
- GitHub Actions CI pre-configured

## Commands

### `/laravel-package-developer:create`

Scaffold a complete new package.

```
/laravel-package-developer:create mwguerra/my-package --all
/laravel-package-developer:create mwguerra/my-package --all --with-playwright
```

**Arguments:** `<vendor/package-name> [--with-routes] [--with-views] [--with-migrations] [--with-commands] [--with-playwright] [--all]`

Always creates: composer.json, ServiceProvider, Facade, config, testbench.yaml, workbench/, tests/, phpunit.xml, GitHub Actions, README, LICENSE.

### `/laravel-package-developer:add`

Add features to an existing package.

```
/laravel-package-developer:add mwguerra/my-package command GenerateReport
/laravel-package-developer:add mwguerra/my-package model Post
/laravel-package-developer:add mwguerra/my-package migration create_posts_table
```

**Arguments:** `<vendor/package-name> <feature-type> [name]`

Feature types: route, command, middleware, event, listener, migration, model, view, config, facade, job, notification, policy, rule.

### `/laravel-package-developer:test`

Run Pest tests.

```
/laravel-package-developer:test mwguerra/my-package
/laravel-package-developer:test mwguerra/my-package --coverage
/laravel-package-developer:test mwguerra/my-package --browser
```

**Arguments:** `<vendor/package-name> [--coverage] [--filter <name>] [--parallel] [--browser] [--bail]`

### `/laravel-package-developer:serve`

Serve the Workbench for interactive development.

```
/laravel-package-developer:serve mwguerra/my-package
/laravel-package-developer:serve mwguerra/my-package --port 8001
```

**Arguments:** `<vendor/package-name> [--port <port>]`

### `/laravel-package-developer:status`

Package health check.

```
/laravel-package-developer:status mwguerra/my-package
```

**Arguments:** `<vendor/package-name>`

Checks structure, dependencies, ServiceProvider, tests, workbench, and host integration.

### `/laravel-package-developer:publish`

Prepare for Packagist publishing.

```
/laravel-package-developer:publish mwguerra/my-package
```

**Arguments:** `<vendor/package-name>`

Runs composer validate, checks required files, verifies .gitattributes, and ensures tests pass.

## Agents

### `package-architect`

Expert in Laravel 12 package structure, ServiceProviders, config merging/publishing, routes/views/migrations loading, package discovery, and Workbench development workflow.

Use when: designing packages, wiring ServiceProviders, setting up workbench.

### `package-test-writer`

Expert in Pest v4, Testbench v10, pest-plugin-testbench v4, WithWorkbench trait, testbench.yaml config, Playwright browser testing, and coverage reports.

Use when: writing tests, setting up test infrastructure, configuring CI.

## Understanding Testbench vs Workbench

These are two complementary tools from the [Orchestra](https://packages.tools) ecosystem that share the same `testbench.yaml` configuration file:

### Testbench — Automated Testing

[Orchestra Testbench](https://packages.tools/testbench) is the **testing framework** for Laravel packages. It boots a minimal Laravel application for your tests, so you can test your package as if it were installed in a real app.

- Runs PHPUnit/Pest tests
- Bootstraps a Laravel app with your package loaded
- Provides `TestCase` base class extending `Orchestra\Testbench\TestCase`
- Handles package provider registration, config, migrations

```php
// tests/TestCase.php
use Orchestra\Testbench\Concerns\WithWorkbench;
use Orchestra\Testbench\TestCase as Orchestra;

abstract class TestCase extends Orchestra
{
    use WithWorkbench;
}
```

### Workbench — Interactive Development

[Orchestra Workbench](https://packages.tools/workbench) is the **interactive development environment**. It serves a real Laravel application with your package loaded, so you can browse, click, and test manually.

- Serves a real Laravel app via `composer serve`
- Uses `workbench/` directory for app files (models, routes, views, seeders)
- Hot-reloads as you develop your package
- Perfect for visual testing and rapid prototyping

```bash
composer serve
# Visit http://127.0.0.1:8000
```

### How They Work Together

Both Testbench and Workbench read from the same `testbench.yaml` file:

```yaml
providers:
  - Workbench\App\Providers\WorkbenchServiceProvider

migrations:
  - workbench/database/migrations

seeders:
  - Workbench\Database\Seeders\DatabaseSeeder

workbench:
  start: "/"
  install: true
  health: "/up"
  discovers:
    web: true
    api: false
  build:
    - create-sqlite-db
    - migrate:fresh
```

The **`WithWorkbench` trait** in your TestCase is the bridge. It tells Testbench to read `testbench.yaml` instead of requiring manual `getPackageProviders()` and `getEnvironmentSetUp()` overrides. This means your test environment and development environment use the same configuration.

**Summary:**

| | Testbench | Workbench |
|---|---|---|
| Purpose | Automated testing | Interactive development |
| Command | `vendor/bin/pest` | `composer serve` |
| Environment | Headless (CLI) | Browser (HTTP) |
| Config | `testbench.yaml` | `testbench.yaml` |
| App files | — | `workbench/` directory |

## Technology Stack

| Dependency | Version | Purpose |
|---|---|---|
| PHP | ^8.3 | Runtime |
| illuminate/support | ^12.0 | Laravel 12 |
| orchestra/testbench | ^10.0 | Testing framework for packages |
| pestphp/pest | ^4.0 | Testing framework |
| pestphp/pest-plugin-laravel | ^4.0 | Laravel Pest integration |
| orchestra/pest-plugin-testbench | ^4.0 | Pest + Testbench bridge |
| @playwright/test | ^1.50 | Browser E2E testing (optional) |

## Setup Guide

### testbench.yaml

This file configures both Testbench and Workbench. Key sections:

- `providers` — service providers loaded during tests and workbench
- `migrations` — migration paths for the test/dev database
- `seeders` — seeders to run
- `workbench.discovers` — which resource types to auto-discover from workbench/
- `workbench.build` — build steps to run before serving

### workbench/

The workbench directory is a mini Laravel app:

```
workbench/
├── app/
│   ├── Models/          # Models for development
│   └── Providers/
│       └── WorkbenchServiceProvider.php
├── database/
│   ├── factories/       # Factories for development
│   ├── migrations/      # Migrations for development
│   └── seeders/
│       └── DatabaseSeeder.php
├── resources/views/
│   └── welcome.blade.php
└── routes/
    └── web.php
```

### Playwright (optional)

When created with `--with-playwright`:

1. `playwright.config.ts` uses Playwright's `webServer` to auto-start `testbench serve`
2. `package.json` declares `@playwright/test` as a devDependency
3. Tests go in `tests/Browser/`

Setup:
```bash
npm install
npx playwright install --with-deps chromium
npx playwright test
```

## References

- [Orchestra Testbench](https://packages.tools/testbench) — testing framework for Laravel packages
- [Orchestra Workbench](https://packages.tools/workbench) — interactive development for packages
- [Pest Plugin Testbench](https://github.com/orchestral/pest-plugin-testbench) — Pest + Testbench bridge
- [Laravel Package Development](https://laravel.com/docs/packages) — official Laravel docs
- [PestPHP](https://pestphp.com) — testing framework

## License

MIT
