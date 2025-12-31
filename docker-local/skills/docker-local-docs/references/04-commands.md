# Docker-Local CLI Commands

## Setup & Diagnostics

```bash
docker-local init              # Complete initial setup
docker-local doctor            # Full system health check
docker-local config            # View current configuration
docker-local setup:hosts       # Add Docker hostnames to /etc/hosts (sudo)
docker-local setup:dns         # Configure dnsmasq for *.test (sudo)
docker-local update            # Update Docker images
```

## Environment Management

```bash
docker-local up                # Start all containers
docker-local down              # Stop all containers
docker-local restart           # Restart all containers
docker-local status            # Show service status
docker-local logs [service]    # View logs (all or specific service)
docker-local clean             # Clean caches and unused Docker resources
```

## Project Commands

```bash
docker-local list              # List all Laravel projects
docker-local make:laravel NAME # Create new Laravel project (MySQL, full isolation)
docker-local make:laravel NAME --postgres  # Create with PostgreSQL + pgvector
docker-local clone REPO        # Clone and setup existing project
docker-local open [name]       # Open project in browser
docker-local open --mail       # Open Mailpit
docker-local open --minio      # Open MinIO Console
docker-local open --traefik    # Open Traefik Dashboard
docker-local ide [editor]      # Open in IDE (code, phpstorm)
```

**`make:laravel` creates everything automatically:**
- Laravel project via Composer
- Database (MySQL or PostgreSQL) + testing database
- MinIO bucket for file storage
- Unique Redis DB numbers for cache/session/queue
- Unique cache prefix and Reverb credentials
- Configured `.env` with all Docker service connections

## Development Commands

```bash
docker-local tinker            # Laravel Tinker REPL
docker-local test [options]    # Run tests (supports --coverage, --parallel)
docker-local require PACKAGE   # Install Composer package with suggestions
docker-local logs:laravel      # Tail Laravel logs
docker-local shell             # Open PHP container shell
```

## Artisan Shortcuts

```bash
docker-local new:model NAME [-mcr]       # make:model (with migration, controller, resource)
docker-local new:controller NAME [--api] # make:controller
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

## Database Commands

```bash
docker-local db:mysql          # Open MySQL CLI
docker-local db:postgres       # Open PostgreSQL CLI
docker-local db:redis          # Open Redis CLI
docker-local db:create NAME    # Create new database
docker-local db:dump [name]    # Export database to SQL
docker-local db:restore FILE   # Import SQL file
docker-local db:fresh          # migrate:fresh --seed
```

## Queue Commands

```bash
docker-local queue:work        # Start queue worker
docker-local queue:restart     # Restart queue workers
docker-local queue:failed      # List failed jobs
docker-local queue:retry ID    # Retry failed job (or 'all')
docker-local queue:clear       # Clear all queued jobs
```

## Xdebug Commands

```bash
docker-local xdebug on         # Enable Xdebug
docker-local xdebug off        # Disable Xdebug (better performance)
docker-local xdebug status     # Show Xdebug status
```

## Startup Commands

```bash
docker-local startup enable    # Start on OS boot
docker-local startup disable   # Disable startup on boot
docker-local startup status    # Show startup status
```

**Platform-specific behavior:**

| Platform | Method | Location |
|----------|--------|----------|
| Linux | systemd service | `~/.config/systemd/user/docker-local.service` |
| macOS | LaunchAgent | `~/Library/LaunchAgents/com.mwguerra.docker-local.plist` |
| WSL2 | bashrc script | Entry in `~/.bashrc` |

## Environment Verification

```bash
docker-local env:check         # Verify current project .env
docker-local env:check --all   # Audit ALL projects for conflicts
docker-local make:env          # Generate new .env with unique IDs
docker-local update:env        # Update existing .env
```

## Shell Completion

### Bash
```bash
# Add to ~/.bashrc
eval "$(docker-local completion bash)"
```

### Zsh
```bash
# Add to ~/.zshrc
eval "$(docker-local completion zsh)"
```
