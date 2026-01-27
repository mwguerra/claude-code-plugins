# Error Patterns Reference

Comprehensive reference of common error patterns organized by technology and framework.

## PHP / Laravel Errors

### Database Errors

```
SQLSTATE[HY000] [2002] Connection refused
```
- **Cause**: Database server not running or wrong host/port
- **Common fixes**: Start database container, check `.env` DB_HOST

```
SQLSTATE[42S02]: Base table or view not found
```
- **Cause**: Missing database table
- **Common fixes**: Run migrations, check table name spelling

```
SQLSTATE[23000]: Integrity constraint violation: Duplicate entry
```
- **Cause**: Unique constraint violated
- **Common fixes**: Check for existing records, use updateOrCreate

### Class/Method Errors

```
Class 'App\...' not found
```
- **Cause**: Missing class, wrong namespace, autoload not updated
- **Common fixes**: `composer dump-autoload`, check namespace

```
Call to undefined method
```
- **Cause**: Method doesn't exist on class
- **Common fixes**: Check method name, check class inheritance

```
Target class [...] does not exist
```
- **Cause**: Service container can't resolve class
- **Common fixes**: Check binding, ensure class exists

### Configuration Errors

```
Configuration cache is stale
```
- **Cause**: Config cached but files changed
- **Common fixes**: `php artisan config:clear`

```
Route [...] not defined
```
- **Cause**: Missing route or wrong name
- **Common fixes**: Check route names, clear route cache

## JavaScript / Node Errors

### Module Errors

```
Cannot find module 'xxx'
```
- **Cause**: Missing dependency
- **Common fixes**: `npm install xxx`, check package.json

```
Module not found: Can't resolve 'xxx'
```
- **Cause**: Import path wrong or missing
- **Common fixes**: Check import path, install package

### Type Errors

```
TypeError: Cannot read property 'x' of undefined
```
- **Cause**: Accessing property on undefined value
- **Common fixes**: Add null checks, initialize variable

```
TypeError: x is not a function
```
- **Cause**: Calling non-function as function
- **Common fixes**: Check variable type, import correctly

### Async Errors

```
UnhandledPromiseRejectionWarning
```
- **Cause**: Promise rejected without catch
- **Common fixes**: Add .catch() or try/catch with async/await

## Docker Errors

### Container Errors

```
Error response from daemon: container xxx is not running
```
- **Cause**: Container stopped or crashed
- **Common fixes**: `docker start xxx`, check logs

```
Bind for 0.0.0.0:xxxx failed: port is already allocated
```
- **Cause**: Port in use by another process
- **Common fixes**: Stop other process, use different port

### Network Errors

```
network xxx not found
```
- **Cause**: Docker network doesn't exist
- **Common fixes**: Create network, check docker-compose

```
Could not connect to xxx:xxxx
```
- **Cause**: Container not on same network
- **Common fixes**: Check network configuration, use service names

## Database Connection Errors

### MySQL/MariaDB

```
Access denied for user 'xxx'@'xxx'
```
- **Cause**: Wrong credentials or missing permissions
- **Common fixes**: Check username/password, grant permissions

```
Unknown database 'xxx'
```
- **Cause**: Database doesn't exist
- **Common fixes**: Create database, check name spelling

### PostgreSQL

```
FATAL: database "xxx" does not exist
```
- **Cause**: Database not created
- **Common fixes**: `CREATE DATABASE xxx`

```
FATAL: password authentication failed
```
- **Cause**: Wrong password
- **Common fixes**: Reset password, check .env

## Browser / Playwright Errors

### Network Errors

```
net::ERR_CONNECTION_REFUSED
```
- **Cause**: Server not running or wrong port
- **Common fixes**: Start server, check URL

```
net::ERR_NAME_NOT_RESOLVED
```
- **Cause**: DNS resolution failed
- **Common fixes**: Check hostname, use IP address

### Element Errors

```
Element not found / Selector not found
```
- **Cause**: Element doesn't exist or wrong selector
- **Common fixes**: Update selector, wait for element

```
TimeoutError: waiting for selector
```
- **Cause**: Element didn't appear in time
- **Common fixes**: Increase timeout, check page load

### Page Errors

```
Navigation failed because page crashed
```
- **Cause**: Browser process crashed
- **Common fixes**: Reduce resource usage, restart browser

## Git Errors

### Push/Pull Errors

```
fatal: remote origin already exists
```
- **Cause**: Remote already configured
- **Common fixes**: `git remote remove origin` then re-add

```
error: failed to push some refs
```
- **Cause**: Remote has changes not in local
- **Common fixes**: Pull first, then push

### Merge Errors

```
CONFLICT (content): Merge conflict in xxx
```
- **Cause**: Same lines changed in both branches
- **Common fixes**: Resolve conflicts manually, then commit

## Build Errors

### NPM

```
npm ERR! code ERESOLVE
```
- **Cause**: Dependency version conflicts
- **Common fixes**: Use `--legacy-peer-deps`, update packages

```
npm ERR! code ENOENT
```
- **Cause**: File or directory not found
- **Common fixes**: Check paths, run from correct directory

### Composer

```
Your requirements could not be resolved
```
- **Cause**: Package version conflicts
- **Common fixes**: Update version constraints, use `--with-all-dependencies`

## Error Normalization

The error memory system normalizes errors for better matching by:

1. **Stripping file paths** - Keeps only filename
2. **Replacing UUIDs** - Substitutes with `{uuid}`
3. **Replacing line numbers** - Substitutes with `{line}`
4. **Replacing IDs** - Substitutes with `{id}`
5. **Replacing timestamps** - Substitutes with `{timestamp}`
6. **Normalizing whitespace** - Single spaces, trimmed

This allows matching errors that differ only in dynamic values.
