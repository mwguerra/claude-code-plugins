# Security Best Practices

## Container Security

### 1. Run as Non-Root User

```dockerfile
# Dockerfile
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser
USER appuser
```

```yaml
# compose.yaml
services:
  app:
    user: "1000:1000"
```

### 2. Use Read-Only Filesystem

```yaml
services:
  app:
    read_only: true
    tmpfs:
      - /tmp
      - /app/cache
```

### 3. Drop Unnecessary Capabilities

```yaml
services:
  app:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if needed
```

### 4. Set Resource Limits

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### 5. Scan Images for Vulnerabilities

```bash
# Docker Scout
docker scout quickview myimage:latest
docker scout cves myimage:latest

# Trivy
trivy image myimage:latest

# Grype
grype myimage:latest
```

## Network Security

### 1. Use Internal Networks for Databases

```yaml
networks:
  backend:
    internal: true

services:
  db:
    networks:
      - backend
    # No ports exposed to host
```

### 2. Bind to Localhost for Development

```yaml
ports:
  - "127.0.0.1:5432:5432"
```

### 3. Use TLS for Production

```yaml
# Use Traefik with Let's Encrypt
labels:
  - "traefik.http.routers.app.tls.certresolver=letsencrypt"
```

### 4. Network Segmentation

```yaml
services:
  frontend:
    networks:
      - public

  api:
    networks:
      - public
      - internal

  db:
    networks:
      - internal

networks:
  public:
  internal:
    internal: true
```

## Secret Management

### 1. Never Commit Secrets

```bash
# .gitignore
.env
secrets/
*.pem
*.key
```

### 2. Use Docker Secrets

```yaml
services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    file: ./secrets/api_key.txt
```

### 3. Use Environment Variables from Secure Sources

```yaml
environment:
  - DB_PASSWORD  # From shell, not compose file
```

### 4. External Secret Managers

```yaml
# HashiCorp Vault integration
services:
  app:
    environment:
      - VAULT_ADDR=http://vault:8200
      - VAULT_TOKEN=${VAULT_TOKEN}
```

## Image Security

### 1. Use Minimal Base Images

```dockerfile
# Prefer Alpine or distroless
FROM node:20-alpine
FROM gcr.io/distroless/nodejs
```

### 2. Pin Image Versions

```dockerfile
# BAD
FROM node:latest

# GOOD
FROM node:20.10.0-alpine3.19
```

### 3. Multi-Stage Builds

```dockerfile
# Build stage
FROM node:20 AS builder
WORKDIR /app
COPY . .
RUN npm ci && npm run build

# Production stage - minimal image
FROM node:20-alpine
COPY --from=builder /app/dist ./dist
USER node
CMD ["node", "dist/index.js"]
```

### 4. Verify Image Signatures

```bash
# Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker pull myimage:latest
```

## Dockerfile Security

### 1. Don't Store Secrets in Images

```dockerfile
# BAD
ENV API_KEY=secret123

# GOOD - Pass at runtime
# docker run -e API_KEY=secret123 myimage
```

### 2. Use COPY Instead of ADD

```dockerfile
# Prefer COPY (more explicit)
COPY requirements.txt .

# ADD only for tar extraction
ADD archive.tar.gz /app/
```

### 3. Minimize Layers and Clean Up

```dockerfile
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean
```

### 4. Use .dockerignore

```plaintext
.git
.env
secrets/
*.pem
node_modules/
tests/
```

## Runtime Security

### 1. Limit Container Resources

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
          pids: 100
```

### 2. Use Security Options

```yaml
services:
  app:
    security_opt:
      - no-new-privileges:true
      - seccomp:unconfined  # Only if needed
```

### 3. Disable Privilege Escalation

```yaml
services:
  app:
    privileged: false
    security_opt:
      - no-new-privileges:true
```

### 4. Use AppArmor/SELinux

```yaml
services:
  app:
    security_opt:
      - apparmor:docker-default
      - label:type:container_runtime_t
```

## Access Control

### 1. Protect Docker Socket

```yaml
services:
  app:
    volumes:
      # Read-only access to docker socket (if needed)
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### 2. Use Docker Context for Remote Access

```bash
docker context create remote --docker "host=ssh://user@remote-host"
docker context use remote
```

### 3. Enable TLS for Docker Daemon

```bash
# Generate certificates
# Configure dockerd with --tlsverify
```

## Logging and Monitoring

### 1. Configure Log Rotation

```yaml
services:
  app:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

### 2. Use Centralized Logging

```yaml
services:
  app:
    logging:
      driver: syslog
      options:
        syslog-address: "tcp://logserver:514"
```

### 3. Monitor Container Health

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Security Checklist

- [ ] Run containers as non-root
- [ ] Use read-only filesystem where possible
- [ ] Drop all capabilities, add only needed ones
- [ ] Set resource limits
- [ ] Use internal networks for backend services
- [ ] Never expose database ports publicly
- [ ] Use TLS in production
- [ ] Never commit secrets to version control
- [ ] Use minimal base images
- [ ] Pin image versions
- [ ] Scan images for vulnerabilities
- [ ] Use multi-stage builds
- [ ] Enable log rotation
- [ ] Implement health checks
- [ ] Disable privilege escalation
