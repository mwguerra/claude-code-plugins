# Docker-Local Quick Start

## New Project

```bash
# Create a new Laravel project (everything is configured automatically)
docker-local make:laravel my-app

# With PostgreSQL instead of MySQL
docker-local make:laravel my-app --postgres

# Navigate to project
cd ~/projects/my-app

# Open in browser (https://my-app.test)
docker-local open

# Run artisan commands
docker-local tinker
docker-local new:model Post -mcr

# View logs
docker-local logs
docker-local logs:laravel

# Stop environment
docker-local down
```

## Existing Project

If you have an existing Laravel project, copy it to `~/projects/` and configure it:

```bash
# 1. Copy your project to the projects directory
cp -r /path/to/existing-project ~/projects/my-existing-app

# 2. Navigate to the project
cd ~/projects/my-existing-app

# 3. Create the database
docker-local db:create my_existing_app

# 4. Update your .env file with docker-local settings
```

### Required `.env` Changes for Existing Projects

```bash
# Database - use Docker service names, not localhost
DB_HOST=mysql                    # or 'postgres' for PostgreSQL
DB_PORT=3306                     # or 5432 for PostgreSQL
DB_DATABASE=my_existing_app      # your project's database name
DB_USERNAME=laravel
DB_PASSWORD=secret

# Redis - use Docker service name
REDIS_HOST=redis
REDIS_PORT=6379

# IMPORTANT: Unique isolation values (prevent conflicts with other projects)
CACHE_PREFIX=my_existing_app_
REDIS_CACHE_DB=0                 # Use different numbers if you have multiple projects
REDIS_SESSION_DB=1               # Project 1: 0-2, Project 2: 3-5, etc.
REDIS_QUEUE_DB=2

# Mail - use Mailpit
MAIL_HOST=mailpit
MAIL_PORT=1025

# MinIO/S3 (optional)
AWS_ENDPOINT=http://minio:9000
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
AWS_BUCKET=my_existing_app
AWS_USE_PATH_STYLE_ENDPOINT=true
```

### Quick Setup Script for Existing Projects

```bash
# Create database
docker-local db:create my_existing_app

# Create MinIO bucket (optional)
docker exec minio mc mb local/my_existing_app --ignore-existing

# Install dependencies
docker exec -w /var/www/my-existing-app php composer install

# Generate key if needed
docker exec -w /var/www/my-existing-app php php artisan key:generate

# Run migrations
docker exec -w /var/www/my-existing-app php php artisan migrate

# Open in browser
docker-local open my-existing-app
```

### Checklist for Existing Projects

- [ ] Project copied to `~/projects/<name>/`
- [ ] Database created (`docker-local db:create <name>`)
- [ ] `.env` updated with Docker service names (`mysql`, `redis`, `mailpit`)
- [ ] Unique `CACHE_PREFIX` set (e.g., `myproject_`)
- [ ] Unique `REDIS_*_DB` numbers assigned (if running multiple projects)
- [ ] Dependencies installed (`composer install`)
- [ ] Migrations run (`php artisan migrate`)
- [ ] Host added to `/etc/hosts` or dnsmasq configured
