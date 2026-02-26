---
description: Add features (routes, commands, middleware, models, etc.) to an existing Laravel package
argument-hint: <vendor/package-name> <feature-type> [name]
allowed-tools: Bash(php:*), Bash(composer:*), Read, Write, Edit, Glob
---

# Add Feature to Package

Add a new feature to an existing Laravel package and wire it into the ServiceProvider.

## Input Format

```
<vendor/package-name> <feature-type> [name]
```

## Feature Types

| Type | Description | Example |
|---|---|---|
| `route` | Add a route file | `route web` or `route api` |
| `command` | Add an artisan command | `command SyncData` |
| `middleware` | Add HTTP middleware | `middleware EnsureValid` |
| `event` | Add an event class | `event OrderPlaced` |
| `listener` | Add an event listener | `listener SendNotification` |
| `migration` | Add a database migration | `migration create_posts_table` |
| `model` | Add an Eloquent model | `model Post` |
| `view` | Add views directory + namespace | `view` |
| `config` | Add config file | `config` |
| `facade` | Add a Facade class | `facade` |
| `job` | Add a queueable job | `job ProcessPayment` |
| `notification` | Add a notification | `notification InvoicePaid` |
| `policy` | Add a policy | `policy PostPolicy` |
| `rule` | Add a validation rule | `rule Uppercase` |

## Process

1. Verify the package exists at `packages/vendor/package-name/`
2. Read the existing ServiceProvider to understand current registrations
3. Create the appropriate file(s) in the correct directory
4. Update the ServiceProvider's `register()` or `boot()` method as needed
5. Update `composer.json` if new autoloading is required

## ServiceProvider Wiring

### `register()` — Container bindings
- Facades, config merging

### `boot()` — Resource loading & publishing
- Routes: `$this->loadRoutesFrom()`
- Views: `$this->loadViewsFrom()` + `$this->publishes()`
- Migrations: `$this->publishesMigrations()`
- Translations: `$this->loadTranslationsFrom()`
- Commands: `$this->commands()` (inside `runningInConsole()`)
- Config publish: `$this->publishes()` with tag

## Examples

```
/laravel-package-developer:add mwguerra/my-package command GenerateReport
/laravel-package-developer:add mwguerra/my-package model Post
/laravel-package-developer:add mwguerra/my-package migration create_posts_table
/laravel-package-developer:add mwguerra/my-package middleware EnsureApiKey
/laravel-package-developer:add mwguerra/my-package route api
```
