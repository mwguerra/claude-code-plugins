---
description: Serve the Workbench development environment for interactive package development
argument-hint: <vendor/package-name> [--port <port>]
allowed-tools: Bash(composer:*), Bash(vendor/bin/testbench:*), Bash(cd:*), Read
---

# Serve Workbench

Start the Workbench development server for interactive package development.

## Input Format

Specify the package: `vendor/package-name`

## Options

- `--port <port>` - Specify the port (default: 8000)

## Process

1. Navigate to `packages/vendor/package-name/`
2. Ensure dependencies are installed
3. Run `composer serve` (which runs testbench serve with build steps)

```bash
cd packages/vendor/package-name
composer serve
```

Or with a custom port:

```bash
cd packages/vendor/package-name
vendor/bin/testbench serve --port=8001
```

## What Workbench Does

Workbench boots a real Laravel application with your package loaded. It uses the `testbench.yaml` configuration to:

- Register workbench service providers
- Run migrations from `workbench/database/migrations/`
- Seed data from `workbench/database/seeders/`
- Discover routes from `workbench/routes/`
- Serve views from `workbench/resources/views/`

This gives you a live, interactive environment to develop and test your package in a real Laravel app context.

## Health Check

Once running, the server responds to health checks at `/up`.

## Examples

```
/laravel-package-developer:serve mwguerra/my-package
/laravel-package-developer:serve mwguerra/my-package --port 8001
```
