---
description: Diagnose and fix FilamentPHP v4 issues by consulting documentation and analyzing errors
allowed-tools: Skill(filament-docs), Bash(php:*), Bash(composer:*), Glob(*), Grep(*)
argument-hint: <error-message-or-issue-description>
---

# Diagnose FilamentPHP Issues

Diagnose and fix FilamentPHP v4 issues by consulting official documentation and analyzing error patterns.

## Usage

```bash
# Diagnose an error
/filament:diagnose "Target class [App\Filament\Resources\PostResource] does not exist"

# Diagnose a behavior issue
/filament:diagnose "form fields not saving to database"

# Diagnose a display issue
/filament:diagnose "table not showing any records"
```

## Process

### 1. Analyze the Issue

Parse the error or issue description to identify:
- Error type (class not found, method not found, validation, etc.)
- Component involved (resource, form, table, action, etc.)
- Context (create, edit, list, view page)

### 2. Consult Documentation

Read relevant documentation files:
- `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/`
- Focus on the component/feature mentioned in the error

### 3. Common Issue Categories

#### Class/Component Not Found
- Check namespace and file location
- Verify artisan command was run correctly
- Check service provider registration
- Clear caches: `php artisan optimize:clear`

#### Form Issues
- Fields not saving: Check `fillable` on model
- Validation not working: Verify rules syntax
- Relationships not loading: Check relationship method
- Select options empty: Verify `preload()` or `searchable()`

#### Table Issues
- No records: Check query and filters
- Column not showing: Verify column name matches attribute
- Relationship column error: Check relationship exists
- Actions not working: Verify action configuration

#### Navigation Issues
- Resource not in sidebar: Check `$navigationIcon` and panel registration
- Wrong order: Set `$navigationSort`
- Wrong group: Set `$navigationGroup`

#### Authorization Issues
- 403 Forbidden: Check policy methods
- Missing data: Check `canViewAny`, `canCreate`, etc.

### 4. Diagnostic Steps

1. **Check logs**: `storage/logs/laravel.log`
2. **Clear caches**:
   ```bash
   php artisan optimize:clear
   php artisan filament:clear-cached-components
   ```
3. **Verify registration**: Check AdminPanelProvider
4. **Check dependencies**: `composer show filament/filament`
5. **Run diagnostics**: `php artisan about`

### 5. Provide Solution

- Explain the root cause
- Provide corrected code
- Suggest prevention measures
- Include relevant documentation references

## Common Issues and Solutions

### Issue: Resource not appearing in navigation

**Causes:**
1. Resource not registered in panel
2. Incorrect namespace
3. Authorization blocking access

**Solutions:**
```php
// In AdminPanelProvider.php
->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')

// Or explicit registration
->resources([
    PostResource::class,
])
```

### Issue: Form data not saving

**Causes:**
1. Field name doesn't match model attribute
2. Attribute not in `$fillable`
3. Relationship not configured correctly

**Solutions:**
```php
// Model
protected $fillable = ['title', 'content', 'status'];

// Form field name must match
TextInput::make('title')  // Must match model attribute
```

### Issue: "Call to undefined method" on relationship

**Causes:**
1. Relationship method doesn't exist
2. Wrong relationship type
3. Typo in relationship name

**Solutions:**
```php
// Model must have the relationship
public function author(): BelongsTo
{
    return $this->belongsTo(User::class);
}

// Form field must match
Select::make('author_id')
    ->relationship('author', 'name')
```

### Issue: Table showing wrong data or no data

**Causes:**
1. Query returning wrong results
2. Soft deletes not handled
3. Global scope interference

**Solutions:**
```php
// Check the query
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery()
        ->withoutGlobalScopes([SoftDeletingScope::class]);
}
```

### Issue: Livewire component not found

**Causes:**
1. Class doesn't exist
2. Namespace mismatch
3. Cache issues

**Solutions:**
```bash
php artisan optimize:clear
php artisan filament:clear-cached-components
composer dump-autoload
```

### Issue: Actions not working/showing

**Causes:**
1. Wrong action class imported
2. Authorization blocking
3. Visibility condition failing

**Solutions:**
```php
// Make sure to use correct imports
use Filament\Tables\Actions\DeleteAction;  // For tables
use Filament\Actions\DeleteAction;  // For pages

// Check visibility
->visible(fn (Model $record): bool => $record->status === 'draft')
```

### Issue: Validation errors not showing

**Causes:**
1. Wrong validation rule syntax
2. Field name mismatch
3. Custom validation not throwing correctly

**Solutions:**
```php
TextInput::make('email')
    ->email()
    ->required()
    ->unique(ignoreRecord: true)
    // Use rules() for complex validation
    ->rules(['required', 'email', 'max:255']);
```

## Output

Provide:
1. **Root cause** explanation
2. **Corrected code** if applicable
3. **Commands to run** (cache clear, etc.)
4. **Prevention tips**
5. **Documentation reference**

## Log to solved-errors.md

After solving the issue, log it to `~/claude-docs/solved-errors.md` with:
- Project name and folder
- Error message
- What the error is about
- Why it happened
- Context data
- How it was solved
- Why the solution works
- Tags (filament, laravel, forms, tables, etc.)
