---
description: Show all docker-local commands and usage
allowed-tools: Bash(docker-local:*), Read
---

# Docker-Local Help

Show all available commands.

## 0. Prerequisite Check

**FIRST, verify docker-local is installed:**

```bash
which docker-local > /dev/null 2>&1 && echo "docker-local: OK" || echo "docker-local: NOT INSTALLED"
```

**If NOT installed, ask user to install:**
```bash
composer global require mwguerra/docker-local
export PATH="$HOME/.composer/vendor/bin:$PATH"
docker-local init
```

## Run Help

```bash
docker-local help
```

## Command Categories

### Setup & Diagnostics
```bash
docker-local init              # Complete initial setup
docker-local setup [setting]   # Configure settings (paths, ports, editor)
docker-local doctor            # Full system health check
docker-local fix [options]     # Diagnose and auto-fix common issues
docker-local config            # View current configuration
docker-local setup:hosts       # Add Docker hostnames to /etc/hosts (sudo)
docker-local setup:dns         # Configure dnsmasq for *.test (sudo)
docker-local ssl:status        # Show SSL certificate status
docker-local ssl:regenerate    # Regenerate SSL certificates with mkcert
docker-local update            # Update Docker images
docker-local self-update       # Update docker-local CLI itself
```

### Fix Command Options
```bash
docker-local fix               # Run all checks, auto-fix what's possible
docker-local fix --dns         # Only check/fix DNS issues
docker-local fix --docker      # Only check/fix Docker daemon
docker-local fix --services    # Only check/fix container services
docker-local fix --hosts       # Only check/fix /etc/hosts
docker-local fix --verbose     # Show detailed diagnostic info
docker-local fix --dry-run     # Show what would be fixed without making changes
```

### Environment Management
```bash
docker-local up                # Start all containers
docker-local down              # Stop all containers
docker-local restart           # Restart all containers
docker-local status            # Show service status
docker-local logs [service]    # View logs
docker-local ports             # Display all mapped ports
docker-local clean             # Clean caches and Docker
docker-local clean --all       # Full cleanup (including volumes)
```

### Project Commands
```bash
docker-local park [path]       # Set projects directory (like Valet)
docker-local link              # Rescan and link all Laravel projects
docker-local list              # List all Laravel projects (recursive)
docker-local make:laravel NAME # Create new project (MySQL)
docker-local make:laravel NAME --postgres  # Create with PostgreSQL
docker-local clone REPO        # Clone existing project
docker-local open [name]       # Open in browser
docker-local open --mail       # Open Mailpit
docker-local open --minio      # Open MinIO Console
docker-local open --traefik    # Open Traefik Dashboard
docker-local ide [editor]      # Open in IDE (code, phpstorm)
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

### Startup Commands
```bash
docker-local startup enable    # Start docker-local on OS boot
docker-local startup disable   # Disable startup on boot
docker-local startup status    # Show startup status
```

### Artisan Shortcuts
```bash
docker-local new:model NAME [-mcr]       # make:model (migration, controller, resource)
docker-local new:model NAME -a           # make:model --all
docker-local new:controller NAME [--api] # make:controller
docker-local new:controller NAME --resource  # make:controller --resource
docker-local new:migration NAME          # make:migration
docker-local new:seeder NAME             # make:seeder
docker-local new:factory NAME            # make:factory
docker-local new:request NAME            # make:request
docker-local new:resource NAME           # make:resource
docker-local new:middleware NAME         # make:middleware
docker-local new:event NAME              # make:event
docker-local new:job NAME                # make:job
docker-local new:mail NAME               # make:mail
docker-local new:command NAME            # make:command
```

### Shell Completion
```bash
# Bash (add to ~/.bashrc)
eval "$(docker-local completion bash)"

# Zsh (add to ~/.zshrc)
eval "$(docker-local completion zsh)"
```

$ARGUMENTS
