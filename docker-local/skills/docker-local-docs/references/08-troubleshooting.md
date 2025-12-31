# Docker-Local Troubleshooting

## General Diagnostics

```bash
docker-local doctor            # Full health check
docker-local status            # Service status
docker-local logs              # View all logs
docker-local logs mysql        # View specific service logs
```

## Common Issues

### "Docker daemon is not running"

```bash
# Linux
sudo systemctl start docker

# macOS
open -a Docker

# Windows (WSL2)
# Start Docker Desktop from Windows
```

### "Port already in use"

```bash
# Find what's using the port
lsof -i :3306  # or :5432, :6379, etc.

# Kill the process
kill $(lsof -t -i:3306)

# Or change the port in config
# Edit ~/.config/docker-local/config.json
```

### "Permission denied" errors

```bash
# Linux: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or fix project permissions
sudo chown -R $USER:$USER ~/projects
```

### SSL Certificate Issues

```bash
# Regenerate certificates
docker-local init --certs

# Or manually with mkcert
mkcert -install
mkcert "*.test" "*.localhost"
```

## Container Issues

### Container Won't Start

```bash
# Check logs
docker-local logs php

# Check exit code
docker inspect --format='{{.State.ExitCode}}' php

# Exit codes:
# 0 - Normal stop
# 1 - Application error
# 137 - Out of memory (OOM killed)
# 139 - Segmentation fault
```

### Out of Memory (Exit 137)

Increase Docker memory allocation:
- **Docker Desktop:** Settings > Resources > Memory
- **Linux:** Check Docker daemon configuration

### Container Restarting

```bash
# Check restart count
docker inspect --format='{{.RestartCount}}' mysql

# Check logs for error
docker-local logs mysql --tail=100
```

## Network Issues

### Cannot Connect to Database

```bash
# Verify container is running
docker-local status

# Test connection from inside container
docker exec php php -r "new PDO('mysql:host=mysql;dbname=laravel', 'laravel', 'secret');"

# Check .env has correct host
# DB_HOST=mysql (not localhost)
```

### DNS Not Resolving

```bash
# Setup DNS
sudo docker-local setup:dns

# Or add to hosts
sudo docker-local setup:hosts

# Manual hosts entry
echo "127.0.0.1 myapp.test" | sudo tee -a /etc/hosts
```

### Container Can't Reach Other Container

```bash
# Check containers are on same network
docker network inspect laravel-dev

# Test DNS resolution
docker exec php nslookup mysql

# Test connectivity
docker exec php ping mysql
```

## Data Issues

### Data Disappearing

Check volume configuration:

```bash
docker volume ls
docker compose config | grep -A5 "volumes:"
```

Ensure using named volumes (not anonymous):
```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data  # Named (persists)
  # NOT: - /var/lib/postgresql/data         # Anonymous (deleted)
```

### Database Not Found

```bash
# List databases
docker exec mysql mysql -u root -psecret -e "SHOW DATABASES;"

# Create missing database
docker-local db:create myapp
```

## Performance Issues

### Slow Performance

```bash
# Check Docker resources
docker stats --no-stream

# Disable Xdebug for performance
docker-local xdebug off

# Check disk usage
docker system df
```

### High Memory Usage

```bash
# Prune unused resources
docker system prune -af
docker volume prune -f

# Restart Docker
docker-local down
# Restart Docker Desktop / systemctl restart docker
docker-local up
```

## Cleaning Up

```bash
# Clean caches and logs
docker-local clean

# Full cleanup (removes volumes)
docker-local clean --all

# Reset everything
docker-local down
docker system prune -af
docker volume prune -f
docker-local init
```

## Getting More Help

```bash
# View configuration
docker-local config

# Check Docker events in real-time
docker events

# Inspect container
docker inspect php

# Shell into container
docker-local shell
```

## IDE Integration Issues

### VS Code

```json
{
  "version": "0.2.0",
  "configurations": [{
    "name": "Listen for Xdebug",
    "type": "php",
    "request": "launch",
    "port": 9003,
    "pathMappings": {
      "/var/www/my-project": "${workspaceFolder}"
    }
  }]
}
```

### PhpStorm

1. Settings → PHP → Debug → Port: `9003`
2. Settings → PHP → Servers:
   - Name: `docker`
   - Host: `localhost`, Port: `443`
   - Path mappings: `/var/www/project` → `~/projects/project`
3. Click "Start Listening for PHP Debug Connections"
