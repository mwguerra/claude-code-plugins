---
description: Add a Filament Resource to an existing Filament plugin
argument-hint: <vendor/plugin-name> <ResourceName> [--with-model] [--soft-deletes]
allowed-tools: Bash(php:*), Read, Write, Glob
---

# Add Filament Resource

Add a new Filament Resource to an existing Filament plugin.

## Input Format

```
<vendor/plugin-name> <ResourceName>
```

Example: `mwguerra/filament-blog BlogPost`

## Options

- `--with-model` - Also create the Eloquent Model
- `--soft-deletes` - Include soft delete support
- `--with-migration` - Create a migration file

## Process

1. Locate the plugin at `packages/vendor/plugin-name/`
2. Create the Resource class at `src/Resources/ResourceNameResource.php`
3. Create the Resource pages:
   - `ListResourceNames.php`
   - `CreateResourceName.php`
   - `EditResourceName.php`
   - `ViewResourceName.php` (optional)
4. If `--with-model`, create Model at `src/Models/ResourceName.php`
5. If `--with-migration`, create migration file
6. Update the Plugin class to register the resource

## Files Created

```
src/
├── Resources/
│   └── BlogPostResource/
│       ├── Pages/
│       │   ├── CreateBlogPost.php
│       │   ├── EditBlogPost.php
│       │   └── ListBlogPosts.php
│       └── BlogPostResource.php
└── Models/
    └── BlogPost.php (if --with-model)

database/
└── migrations/
    └── 2024_01_01_000000_create_blog_posts_table.php (if --with-migration)
```

## Resource Structure

The Resource includes:
- Form schema with common fields
- Table columns with sorting/searching
- Filters and actions
- Navigation configuration
- Authorization policies placeholder

## Registration

The Plugin class is updated to include:

```php
public function getResources(): array
{
    return [
        BlogPostResource::class,
    ];
}
```
