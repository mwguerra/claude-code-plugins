# Environment Variables & Secrets

## Environment Variable Sources

```yaml
services:
  app:
    # Direct values
    environment:
      - NODE_ENV=production
      - API_KEY=${API_KEY}  # From .env or shell

    # From file
    env_file:
      - .env
      - .env.local
```

## .env File

```bash
# .env
NODE_ENV=development
DB_HOST=db
DB_PORT=5432
DB_USER=appuser
DB_PASSWORD=secretpassword
DB_NAME=appdb

# Computed values
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
```

## Environment Variable Precedence

1. Compose file `environment` values
2. Shell environment variables
3. Environment file (`.env`)
4. Dockerfile `ENV` values
5. Variable not defined

## Variable Substitution Syntax

| Syntax | Behavior |
|--------|----------|
| `${VAR}` | Value of VAR |
| `${VAR:-default}` | Default if VAR unset or empty |
| `${VAR-default}` | Default if VAR unset |
| `${VAR:?error}` | Error if VAR unset or empty |
| `${VAR?error}` | Error if VAR unset |
| `${VAR:+value}` | Value if VAR is set |

```yaml
services:
  app:
    image: myapp:${TAG:-latest}
    environment:
      - DB_HOST=${DB_HOST:-localhost}
      - DB_PASSWORD=${DB_PASSWORD:?DB password is required}
      - DEBUG=${DEBUG:+true}
```

## Docker Secrets (Sensitive Data)

```yaml
services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    file: ./secrets/api_key.txt
```

### Reading Secrets in Application

```javascript
// Node.js
const fs = require('fs');
const dbPassword = process.env.DB_PASSWORD_FILE
  ? fs.readFileSync(process.env.DB_PASSWORD_FILE, 'utf8').trim()
  : process.env.DB_PASSWORD;
```

```python
# Python
import os

def get_secret(name):
    file_path = os.environ.get(f'{name}_FILE')
    if file_path:
        with open(file_path, 'r') as f:
            return f.read().strip()
    return os.environ.get(name)

db_password = get_secret('DB_PASSWORD')
```

## Best Practices

### .env.example (Commit this)

```bash
# .env.example
NODE_ENV=development
DB_HOST=db
DB_PASSWORD=  # Set in .env
API_KEY=      # Set in .env
```

### .gitignore

```bash
.env
.env.local
.env.*.local
secrets/
*.pem
*.key
```

## Environment by Stage

```yaml
# compose.yaml (base)
services:
  app:
    environment:
      - NODE_ENV=${NODE_ENV:-development}
    env_file:
      - .env
```

```yaml
# compose.override.yaml (development)
services:
  app:
    environment:
      - DEBUG=true
      - LOG_LEVEL=debug
```

```yaml
# compose.prod.yaml (production)
services:
  app:
    environment:
      - DEBUG=false
      - LOG_LEVEL=warn
```

## Multi-Environment Setup

```
project/
├── .env                    # Local development
├── .env.example            # Template (committed)
├── .env.staging            # Staging environment
├── .env.production         # Production (not committed)
├── compose.yaml
├── compose.override.yaml   # Dev overrides
├── compose.staging.yaml
└── compose.prod.yaml
```

```bash
# Development (uses .env and compose.override.yaml automatically)
docker compose up

# Staging
docker compose --env-file .env.staging -f compose.yaml -f compose.staging.yaml up

# Production
docker compose --env-file .env.production -f compose.yaml -f compose.prod.yaml up
```

## Environment Variable Patterns

### Database Connection

```bash
# .env
DB_HOST=postgres
DB_PORT=5432
DB_USER=appuser
DB_PASSWORD=secretpass
DB_NAME=appdb
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
```

### API Keys

```bash
# .env
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
SENDGRID_API_KEY=SG.xxx
```

### Feature Flags

```bash
# .env
FEATURE_NEW_DASHBOARD=true
FEATURE_BETA_API=false
ENABLE_ANALYTICS=true
```

### Service URLs

```bash
# .env
API_URL=http://api:3000
FRONTEND_URL=http://localhost:8080
REDIS_URL=redis://redis:6379
ELASTICSEARCH_URL=http://elasticsearch:9200
```

## Runtime Environment Inspection

```bash
# View container environment
docker compose exec app env

# View specific variable
docker compose exec app printenv DATABASE_URL

# Pass environment to command
docker compose exec -e DEBUG=true app npm run test
```

## Interpolation in Config Files

Using environment variables in configuration files:

```yaml
# docker-compose.yaml can interpolate
services:
  app:
    image: ${REGISTRY:-docker.io}/myapp:${TAG:-latest}
    ports:
      - "${APP_PORT:-3000}:3000"
```

```nginx
# Nginx requires envsubst
# nginx.conf.template
server {
    listen ${NGINX_PORT};
    server_name ${NGINX_HOST};
}
```

```yaml
services:
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf.template:/etc/nginx/templates/default.conf.template
    environment:
      - NGINX_PORT=80
      - NGINX_HOST=localhost
```

## External Secrets Management

### HashiCorp Vault

```yaml
services:
  vault:
    image: vault:latest
    cap_add:
      - IPC_LOCK
    environment:
      - VAULT_ADDR=http://0.0.0.0:8200
    volumes:
      - vault_data:/vault/data

  app:
    environment:
      - VAULT_ADDR=http://vault:8200
      - VAULT_TOKEN=${VAULT_TOKEN}

volumes:
  vault_data:
```

### AWS Secrets Manager

```yaml
services:
  app:
    environment:
      - AWS_REGION=us-east-1
      - AWS_SECRET_NAME=my-app/production
    # Application fetches secrets at runtime
```

## Debugging Environment Issues

```bash
# Check what variables compose sees
docker compose config

# Check .env parsing
docker compose config --format json | jq '.services.app.environment'

# Verify variable expansion
echo "DB_HOST is: ${DB_HOST}"
```
