# Container Networking

## Network Types

Docker provides several network drivers:

| Driver | Use Case |
|--------|----------|
| `bridge` | Default. Containers on same host communicate |
| `host` | Container uses host's network directly |
| `overlay` | Multi-host communication (Swarm) |
| `macvlan` | Assign MAC address, appear as physical device |
| `none` | Disable networking |

## Creating Networks in Compose

```yaml
services:
  frontend:
    image: nginx:alpine
    networks:
      - frontend-net
    ports:
      - "80:80"

  api:
    build: ./api
    networks:
      - frontend-net
      - backend-net

  database:
    image: postgres:16
    networks:
      - backend-net
    # No ports exposed to host - only accessible via backend-net

networks:
  frontend-net:
    driver: bridge
  backend-net:
    driver: bridge
    internal: true  # No external access
```

## Container DNS Resolution

Within a Docker Compose network, containers can reach each other by service name:

```yaml
services:
  app:
    environment:
      # Use service name as hostname
      - DATABASE_HOST=db
      - REDIS_HOST=redis
      - API_URL=http://api:3000

  db:
    image: postgres:16

  redis:
    image: redis:7

  api:
    build: ./api
```

## External Networks

Share networks between multiple Compose projects:

```bash
# Create external network
docker network create shared-network
```

```yaml
# compose.yaml (Project A)
services:
  api:
    networks:
      - shared

networks:
  shared:
    external: true
    name: shared-network
```

```yaml
# compose.yaml (Project B)
services:
  frontend:
    networks:
      - shared

networks:
  shared:
    external: true
    name: shared-network
```

## Network Configuration Options

```yaml
networks:
  # Simple network
  app-net:

  # Network with driver options
  backend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: backend-br

  # Internal network (no external access)
  database:
    internal: true

  # Custom IPAM configuration
  custom:
    ipam:
      driver: default
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1

  # External network
  proxy:
    external: true
    name: traefik_proxy
```

## Service Network Options

```yaml
services:
  app:
    networks:
      frontend:
        aliases:
          - webapp
          - web
        ipv4_address: 172.28.0.10
      backend:
```

## Network Isolation Patterns

### Three-Tier Architecture

```yaml
services:
  # Public-facing
  nginx:
    image: nginx:alpine
    networks:
      - frontend
    ports:
      - "80:80"

  # Application layer
  api:
    build: .
    networks:
      - frontend
      - backend
    # No public ports

  # Database layer
  db:
    image: postgres:16
    networks:
      - backend
    # No public ports, isolated

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # Cannot reach internet
```

## Debugging Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect mynetwork

# Check container connectivity
docker compose exec app ping db
docker compose exec app nc -zv db 5432

# View container's network settings
docker inspect container_name | grep -A 50 "Networks"

# Test DNS resolution
docker compose exec app nslookup db
```

## Host Networking Mode

```yaml
services:
  app:
    network_mode: host
    # No port mapping needed - uses host ports directly
```

**Use cases:**
- Performance-critical applications
- Applications that need to bind to many ports
- When container must appear as host

**Limitations:**
- Only works on Linux
- Port conflicts with host services
- Less isolation

## Common Network Patterns

### Reverse Proxy Pattern

```yaml
services:
  traefik:
    image: traefik:v3.0
    networks:
      - proxy
    ports:
      - "80:80"
      - "443:443"

  app1:
    build: ./app1
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app1.rule=Host(`app1.example.com`)"

  app2:
    build: ./app2
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app2.rule=Host(`app2.example.com`)"

networks:
  proxy:
    name: proxy
```

### Service Mesh Pattern

```yaml
services:
  api-gateway:
    networks:
      - public
      - services

  user-service:
    networks:
      - services
      - user-db

  order-service:
    networks:
      - services
      - order-db

  user-db:
    image: postgres:16
    networks:
      - user-db

  order-db:
    image: postgres:16
    networks:
      - order-db

networks:
  public:
  services:
    internal: true
  user-db:
    internal: true
  order-db:
    internal: true
```
