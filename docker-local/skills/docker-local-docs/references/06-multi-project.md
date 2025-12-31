# Docker-Local Multi-Project Support

Docker-local supports multiple Laravel projects sharing the same Docker services. Each project gets **complete automatic isolation** to prevent data leakage between projects.

## What Gets Created Automatically

When you create a project with `docker-local make:laravel myapp`, everything is set up automatically:

```
Creating Laravel project: myapp
Database: MySQL
Redis DBs: cache=0, session=1, queue=2

✓ Project created successfully!
✓ MySQL database 'myapp' created
✓ MySQL database 'myapp_testing' created
✓ MinIO bucket 'myapp' created
✓ .env configured with complete isolation

Isolation settings (multi-project):
  ✓ Database: myapp (MySQL)
  ✓ Redis Cache DB: 0
  ✓ Redis Session DB: 1
  ✓ Redis Queue DB: 2
  ✓ Cache Prefix: myapp_
  ✓ MinIO Bucket: myapp
  ✓ Reverb App ID: 847291
```

## Automatic Isolation Details

| Resource | How It's Isolated | Example Value |
|----------|-------------------|---------------|
| **Database** | Unique DB per project | `myapp`, `myapp_testing` |
| **Redis Cache** | Separate Redis DB number | `REDIS_CACHE_DB=0` |
| **Redis Session** | Separate Redis DB number | `REDIS_SESSION_DB=1` |
| **Redis Queue** | Separate Redis DB number | `REDIS_QUEUE_DB=2` |
| **Cache Prefix** | Unique prefix per project | `CACHE_PREFIX=myapp_` |
| **MinIO Bucket** | Separate S3 bucket | `AWS_BUCKET=myapp` |
| **Reverb/WebSockets** | Unique credentials | Random `REVERB_APP_ID/KEY/SECRET` |
| **Horizon Prefix** | Unique queue prefix | `HORIZON_PREFIX=myapp_horizon:` |

## Redis Database Allocation

Redis has 16 databases (0-15). Each project uses 3 databases:

| Project | Cache DB | Session DB | Queue DB |
|---------|----------|------------|----------|
| 1st project | 0 | 1 | 2 |
| 2nd project | 3 | 4 | 5 |
| 3rd project | 6 | 7 | 8 |
| 4th project | 9 | 10 | 11 |
| 5th project | 12 | 13 | 14 |

This allows up to 5 fully isolated projects. Beyond that, DB numbers wrap around (with a warning).

## PostgreSQL vs MySQL

Both database engines are available. Use the `--postgres` flag:

```bash
# MySQL (default)
docker-local make:laravel myapp

# PostgreSQL with pgvector
docker-local make:laravel myapp --postgres
```

PostgreSQL projects automatically get these extensions:
- `uuid-ossp` - UUID generation
- `pgcrypto` - Cryptographic functions
- `vector` - pgvector for AI embeddings

## Conflict Detection

```bash
# Check current project
docker-local env:check

# Audit ALL projects for conflicts
docker-local env:check --all
```

Example conflict output:

```
┌─ Cross-Project Conflicts ─────────────────────────────────────────┐
  ⚠ CACHE_PREFIX conflict with 'other-project'
    Both projects use: laravel_cache_

  Why: Cache data will be shared/corrupted between projects
  Fix: Change CACHE_PREFIX in one of the projects' .env files
```

## Running Multiple Projects Simultaneously

All projects can run at the same time without conflicts:

```bash
# Terminal 1 - Work on blog
cd ~/projects/blog
docker-local tinker

# Terminal 2 - Work on api
cd ~/projects/api
docker-local test

# Terminal 3 - Work on admin
cd ~/projects/admin
docker-local queue:work
```

Each project has its own:
- Database (no shared tables)
- Cache (no key collisions)
- Sessions (users stay logged in to their project)
- Queues (jobs don't mix between projects)
- File storage (separate MinIO buckets)

## Project Directory Structure

Each Laravel project is automatically accessible via HTTPS:

```
~/projects/
├── blog/                         → https://blog.test
│   ├── .env                      # Project-specific Laravel config
│   ├── app/
│   └── ...
├── api/                          → https://api.test
└── shop/                         → https://shop.test
```
