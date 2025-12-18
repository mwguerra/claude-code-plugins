---
description: Search FilamentPHP v4 official documentation for patterns, methods, and implementation examples
allowed-tools: Skill(filament-docs), Glob(*), Grep(*)
argument-hint: <topic-or-search-query>
---

# Search FilamentPHP Documentation

Search and reference the official FilamentPHP v4 documentation to find patterns, examples, and solutions.

## Usage

```bash
# Search for a topic
/filament:docs "form validation"

# Find specific component docs
/filament:docs "TextInput"

# Search for patterns
/filament:docs "relationship select"

# Find examples
/filament:docs "file upload with preview"
```

## Process

### 1. Parse Search Query

Identify:
- Component type (form, table, action, etc.)
- Specific feature or method
- Pattern or example needed

### 2. Search Documentation

Search in `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/`

#### Documentation Structure

```
references/
├── actions/           # Modal actions, button actions
├── forms/             # Form field types
├── general/
│   ├── 01-introduction/   # Getting started
│   ├── 03-resources/      # CRUD resources
│   ├── 06-navigation/     # Menus, groups
│   ├── 07-users/          # Auth, permissions
│   ├── 08-styling/        # CSS, theming
│   ├── 09-advanced/       # Advanced patterns
│   ├── 10-testing/        # Testing guide
│   ├── 11-plugins/        # Plugin development
│   └── 12-components/     # UI components
├── infolists/         # Read-only display
├── notifications/     # Toast/database notifications
├── schemas/           # Data schemas
├── tables/
│   ├── 02-columns/    # Column types
│   └── 03-filters/    # Filter types
└── widgets/           # Dashboard widgets
```

### 3. Extract Information

From documentation, extract:
- Code examples
- Method signatures
- Configuration options
- Best practices

### 4. Present Results

Provide:
- Relevant documentation excerpts
- Working code examples
- Related topics
- Links to specific files

## Quick Reference

### Forms
| Topic | Location |
|-------|----------|
| Text inputs | `forms/` |
| Select fields | `forms/` |
| File uploads | `forms/` |
| Repeaters | `forms/` |
| Validation | `forms/` |
| Layout | `forms/` |

### Tables
| Topic | Location |
|-------|----------|
| Text columns | `tables/02-columns/` |
| Badge columns | `tables/02-columns/` |
| Image columns | `tables/02-columns/` |
| Select filters | `tables/03-filters/` |
| Date filters | `tables/03-filters/` |

### Resources
| Topic | Location |
|-------|----------|
| Creating resources | `general/03-resources/` |
| Relation managers | `general/03-resources/` |
| Custom pages | `general/03-resources/` |

### Actions
| Topic | Location |
|-------|----------|
| Table actions | `actions/` |
| Page actions | `actions/` |
| Modal forms | `actions/` |
| Bulk actions | `actions/` |

### Widgets
| Topic | Location |
|-------|----------|
| Stats widgets | `widgets/` |
| Chart widgets | `widgets/` |
| Table widgets | `widgets/` |

### Other
| Topic | Location |
|-------|----------|
| Navigation | `general/06-navigation/` |
| Users/Auth | `general/07-users/` |
| Styling | `general/08-styling/` |
| Testing | `general/10-testing/` |
| Plugins | `general/11-plugins/` |

## Example Searches

### "How do I create a searchable select with create option?"

1. Search forms documentation
2. Find Select component
3. Extract:
```php
Select::make('author_id')
    ->relationship('author', 'name')
    ->searchable()
    ->preload()
    ->createOptionForm([
        TextInput::make('name')
            ->required(),
        TextInput::make('email')
            ->email()
            ->required(),
    ])
    ->createOptionAction(function (Action $action) {
        return $action
            ->modalHeading('Create Author')
            ->modalSubmitActionLabel('Create');
    });
```

### "How do I add a confirmation modal to a delete action?"

1. Search actions documentation
2. Find confirmation patterns
3. Extract:
```php
DeleteAction::make()
    ->requiresConfirmation()
    ->modalHeading('Delete record')
    ->modalDescription('Are you sure you want to delete this? This cannot be undone.')
    ->modalSubmitActionLabel('Yes, delete')
    ->modalCancelActionLabel('Cancel');
```

### "How do I filter a table by date range?"

1. Search table filters documentation
2. Find date filter pattern
3. Extract:
```php
Tables\Filters\Filter::make('created_at')
    ->form([
        DatePicker::make('from'),
        DatePicker::make('until'),
    ])
    ->query(function (Builder $query, array $data): Builder {
        return $query
            ->when(
                $data['from'],
                fn (Builder $query, $date): Builder => $query->whereDate('created_at', '>=', $date),
            )
            ->when(
                $data['until'],
                fn (Builder $query, $date): Builder => $query->whereDate('created_at', '<=', $date),
            );
    });
```

## Output

Provide:
1. **Documentation excerpt** - Relevant section from docs
2. **Code example** - Working, copy-paste ready code
3. **Related topics** - Other relevant documentation
4. **Best practices** - Tips and recommendations
