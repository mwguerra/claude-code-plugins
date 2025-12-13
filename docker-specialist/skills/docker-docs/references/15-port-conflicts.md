# Port Conflict Resolution

## Detecting Port Conflicts

When you run `docker compose up` and a port is already in use, you'll see an error like:

```
Error response from daemon: driver failed programming external connectivity:
Bind for 0.0.0.0:3000 failed: port is already allocated
```

## Finding What's Using a Port

```bash
# Linux/macOS
lsof -i :3000
lsof -Pi :3000 -sTCP:LISTEN -t

# Linux alternative
ss -tulpn | grep 3000
netstat -tulpn | grep 3000

# Check if Docker container is using the port
docker ps --filter "publish=3000"
```

## Killing Processes on a Port

```bash
# Kill process using port
kill $(lsof -t -i:3000)

# Force kill
kill -9 $(lsof -t -i:3000)

# If it's a Docker container
docker stop $(docker ps -q --filter "publish=3000")
```

## Dynamic Port Assignment

Configure compose file to handle port conflicts:

```yaml
services:
  app:
    build: .
    ports:
      # Use environment variable with fallback
      - "${APP_PORT:-3000}:3000"
    environment:
      - PORT=3000

  db:
    image: postgres:16
    ports:
      - "${DB_PORT:-5432}:5432"

  redis:
    image: redis:7
    ports:
      - "${REDIS_PORT:-6379}:6379"
```

**.env:**

```bash
# Change these if defaults are in use
APP_PORT=3000
DB_PORT=5432
REDIS_PORT=6379
```

## Port Conflict Resolution Strategies

| Strategy | When to Use | Command/Config |
|----------|-------------|----------------|
| **Stop conflicting process** | You don't need the other service | `kill $(lsof -t -i:3000)` |
| **Change your port** | Other service must keep its port | Edit `.env` or `compose.yaml` |
| **Use random port** | Port doesn't matter (dev only) | `ports: - "3000"` (no host port) |
| **Stop old containers** | Old Docker containers blocking | `docker compose down` or `docker stop $(docker ps -q)` |
| **Use host network** | Avoid port mapping entirely | `network_mode: host` |

## Automatic Port Conflict Detection Script

**scripts/check-ports.sh:**

```bash
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Ports to check (customize for your project)
PORTS=(3000 5432 6379 80 443)

echo "Checking port availability..."

CONFLICTS=()

for PORT in "${PORTS[@]}"; do
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        PROCESS=$(lsof -Pi :$PORT -sTCP:LISTEN | tail -1 | awk '{print $1, $2}')
        echo -e "${RED}Port $PORT is in use by: $PROCESS${NC}"
        CONFLICTS+=($PORT)
    else
        echo -e "${GREEN}Port $PORT is available${NC}"
    fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Port conflicts detected!${NC}"
    echo ""
    echo "Options:"
    echo "  1. Stop the conflicting processes"
    echo "  2. Change ports in compose.yaml or .env"
    echo "  3. Use dynamic port assignment"
    exit 1
fi

echo -e "\n${GREEN}All ports available! Starting containers...${NC}"
docker compose up -d
```

## Find Free Port Script

**scripts/find-free-port.sh:**

```bash
#!/bin/bash

# Find a free port starting from a given port
find_free_port() {
    local port=$1
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
        ((port++))
    done
    echo $port
}

# Auto-configure ports
APP_PORT=$(find_free_port 3000)
DB_PORT=$(find_free_port 5432)
REDIS_PORT=$(find_free_port 6379)

echo "APP_PORT=$APP_PORT"
echo "DB_PORT=$DB_PORT"
echo "REDIS_PORT=$REDIS_PORT"

# Export for docker compose
export APP_PORT DB_PORT REDIS_PORT

# Start with auto-assigned ports
docker compose up -d

echo ""
echo "Services started on:"
echo "  App:   http://localhost:$APP_PORT"
echo "  DB:    localhost:$DB_PORT"
echo "  Redis: localhost:$REDIS_PORT"
```

## Common Port Conflicts

| Port | Common Service | Solution |
|------|----------------|----------|
| 80 | Apache, nginx | Stop web server or use different port |
| 443 | Apache, nginx | Stop web server or use different port |
| 3000 | Node.js apps | Change to 3001, 3002, etc. |
| 3306 | MySQL | Stop local MySQL or use 3307 |
| 5432 | PostgreSQL | Stop local PostgreSQL or use 5433 |
| 6379 | Redis | Stop local Redis or use 6380 |
| 8080 | Tomcat, Jenkins | Use 8081, 8082, etc. |
| 27017 | MongoDB | Stop local MongoDB or use 27018 |

## Using Random Host Ports

For development when you don't need a specific port:

```yaml
services:
  app:
    ports:
      - "3000"  # No host port = random assignment

  api:
    ports:
      - "3000"  # Each service gets different random port
```

Find the assigned port:
```bash
docker compose port app 3000
```

## Localhost-Only Binding

For services that shouldn't be accessible from network:

```yaml
services:
  db:
    ports:
      - "127.0.0.1:5432:5432"  # Only accessible from localhost
```

## Complete Port Management Script

**scripts/docker-start.sh:**

```bash
#!/bin/bash
set -e

PROJECT_NAME=${1:-$(basename $(pwd))}

echo "Docker Compose Smart Starter"
echo "============================"

# Function to check if a port is in use
port_in_use() {
    lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1
}

# Function to get process using a port
get_port_process() {
    lsof -Pi :$1 -sTCP:LISTEN | tail -1 | awk '{print $1 " (PID: " $2 ")"}'
}

# Extract ports from compose file
PORTS=$(grep -E '^\s+-\s*"?[0-9]+:[0-9]+"?' compose.yaml | grep -oE '[0-9]+:' | tr -d ':' | sort -u)

echo "Checking ports: $PORTS"

CONFLICTS=()

for PORT in $PORTS; do
    if port_in_use $PORT; then
        echo "Port $PORT: CONFLICT - $(get_port_process $PORT)"
        CONFLICTS+=($PORT)
    else
        echo "Port $PORT: Available"
    fi
done

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    echo ""
    echo "Found ${#CONFLICTS[@]} port conflict(s)"
    echo ""
    echo "Choose an action:"
    echo "  1) Kill conflicting processes"
    echo "  2) Exit and fix manually"
    read -p "Enter choice [1-2]: " choice

    case $choice in
        1)
            for PORT in "${CONFLICTS[@]}"; do
                echo "Killing process on port $PORT..."
                kill $(lsof -t -i:$PORT) 2>/dev/null || true
                sleep 1
            done
            ;;
        *)
            exit 1
            ;;
    esac
fi

echo ""
echo "Starting containers..."
docker compose up -d

echo ""
echo "Done! Containers are running."
docker compose ps
```
