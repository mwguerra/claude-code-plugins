---
description: Database operations - create, connect, backup, restore databases
---

# Docker-Local Database Operations

Manage MySQL, PostgreSQL, and Redis databases.

## Connect to Database CLIs

```bash
# MySQL CLI
docker-local db:mysql

# PostgreSQL CLI
docker-local db:postgres

# Redis CLI
docker-local db:redis
```

## Create Database

```bash
# Creates main + testing database
docker-local db:create myapp
```

## Backup Database

```bash
# Dump current project's database
docker-local db:dump

# Dump specific database
docker-local db:dump myapp
```

## Restore Database

```bash
# Restore from SQL file
docker-local db:restore backup.sql
```

## Run Migrations

```bash
# Fresh migration with seeds
docker-local db:fresh
```

## Default Credentials

### MySQL
```
Host:     mysql (container) / localhost (host)
Port:     3306
User:     laravel
Password: secret
```

### PostgreSQL
```
Host:     postgres (container) / localhost (host)
Port:     5432
User:     laravel
Password: secret
```

## GUI Connection (TablePlus, DBeaver)

From your host machine:
```
Host:     localhost
Port:     3306 (MySQL) / 5432 (PostgreSQL)
User:     laravel
Password: secret
Database: myapp
```

$ARGUMENTS
