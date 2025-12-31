---
description: Show all docker-local commands and usage
---

# Docker-Local Help

Show all available commands.

## Run Help

```bash
docker-local help
```

## Command Categories

### Setup & Diagnostics
```bash
docker-local init              # Complete initial setup
docker-local doctor            # Full system health check
docker-local config            # View current configuration
docker-local setup:hosts       # Add Docker hostnames to /etc/hosts
docker-local setup:dns         # Configure dnsmasq for *.test
docker-local update            # Update Docker images
```

### Environment Management
```bash
docker-local up                # Start all containers
docker-local down              # Stop all containers
docker-local restart           # Restart all containers
docker-local status            # Show service status
docker-local logs [service]    # View logs
docker-local clean             # Clean caches and Docker
```

### Project Commands
```bash
docker-local list              # List all Laravel projects
docker-local make:laravel NAME # Create new project
docker-local clone REPO        # Clone existing project
docker-local open [name]       # Open in browser
docker-local ide [editor]      # Open in IDE
```

### Development Commands
```bash
docker-local tinker            # Laravel Tinker
docker-local test [options]    # Run tests
docker-local require PACKAGE   # Install Composer package
docker-local logs:laravel      # Tail Laravel logs
docker-local shell             # PHP container shell
```

### Database Commands
```bash
docker-local db:mysql          # MySQL CLI
docker-local db:postgres       # PostgreSQL CLI
docker-local db:redis          # Redis CLI
docker-local db:create NAME    # Create database
docker-local db:dump [name]    # Export database
docker-local db:restore FILE   # Import SQL file
docker-local db:fresh          # migrate:fresh --seed
```

### Queue Commands
```bash
docker-local queue:work        # Start queue worker
docker-local queue:restart     # Restart workers
docker-local queue:failed      # List failed jobs
docker-local queue:retry ID    # Retry failed job
docker-local queue:clear       # Clear all jobs
```

### Xdebug Commands
```bash
docker-local xdebug on         # Enable Xdebug
docker-local xdebug off        # Disable Xdebug
docker-local xdebug status     # Show status
```

### Environment Check
```bash
docker-local env:check         # Verify project .env
docker-local env:check --all   # Audit all projects
docker-local make:env          # Generate new .env
docker-local update:env        # Update existing .env
```

$ARGUMENTS
