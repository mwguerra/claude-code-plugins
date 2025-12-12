# FilamentPHP Specialist Plugin

Ultra-specialized Claude Code plugin for FilamentPHP v4 development. This plugin provides comprehensive tools for generating resources, forms, tables, actions, widgets, infolists, and tests following official documentation patterns.

## Features

- **Complete FilamentPHP v4 Documentation**: All official documentation is bundled with the plugin for accurate code generation
- **Resource Generation**: Create complete CRUD resources with forms, tables, relations, and tests
- **Form Builder**: Generate form schemas with all field types and validation
- **Table Configuration**: Build tables with columns, filters, and actions
- **Action Creation**: Generate modal actions, bulk actions, and page actions
- **Widget Development**: Create stats, charts, table, and custom widgets
- **Infolist Builder**: Design read-only data displays for view pages
- **Test Generation**: Comprehensive Pest tests for all components
- **Issue Diagnosis**: Troubleshoot FilamentPHP issues with documentation reference

## Commands

| Command | Description |
|---------|-------------|
| `/filament:resource <Model>` | Generate a complete resource with form, table, and tests |
| `/filament:form <description>` | Create a form schema with fields and validation |
| `/filament:table <description>` | Build a table configuration with columns and filters |
| `/filament:action <description>` | Generate actions (row, bulk, header, page) |
| `/filament:widget <description>` | Create dashboard widgets (stats, chart, table, custom) |
| `/filament:infolist <description>` | Design infolists for view pages |
| `/filament:test <Resource>` | Generate Pest tests for a resource |
| `/filament:diagnose <error>` | Diagnose and fix FilamentPHP issues |
| `/filament:docs <topic>` | Search official documentation |

## Usage Examples

### Generate a Resource

```bash
/filament:resource Post --generate
```

Creates:
- `PostResource.php` with form and table
- List, Create, Edit, View pages
- Relation managers for relationships
- Pest tests for all operations

### Create a Form

```bash
/filament:form "product with name, price, description, category, and images"
```

Generates a complete form schema with:
- TextInput for name
- Numeric input with currency prefix for price
- RichEditor for description
- Select with relationship for category
- FileUpload for images

### Build a Table

```bash
/filament:table "orders with customer, items count, total, status badge"
```

Creates table configuration with:
- Relationship columns
- Aggregate counts
- Money formatting
- Badge colors for status
- Search, sort, and filters

### Generate Actions

```bash
/filament:action "send email with subject and body" --modal
```

Creates an action with:
- Modal form with fields
- Validation
- Action handler
- Success notification

### Create Widgets

```bash
/filament:widget "monthly revenue chart" --type chart
```

Generates:
- ChartWidget with data fetching
- Filter options (week, month, year)
- Styling configuration

### Diagnose Issues

```bash
/filament:diagnose "form fields not saving to database"
```

- Analyzes the issue
- Consults documentation
- Provides solution with code
- Logs to solved-errors.md

## Agent

The plugin includes a specialized agent (`filament-specialist-agent`) that can be used for complex FilamentPHP tasks:

- Autonomous resource creation
- Multi-component implementations
- Issue diagnosis and fixing
- Documentation-driven development

## Documentation Structure

All FilamentPHP v4 documentation is stored in:
```
skills/filament-docs/references/
├── actions/           # Action buttons and modals
├── forms/             # Form field types
├── general/
│   ├── 01-introduction/
│   ├── 03-resources/
│   ├── 06-navigation/
│   ├── 07-users/
│   ├── 08-styling/
│   ├── 09-advanced/
│   ├── 10-testing/
│   ├── 11-plugins/
│   └── 12-components/
├── infolists/         # Info display entries
├── notifications/     # Toast notifications
├── schemas/           # Schema validation
├── tables/
│   ├── 02-columns/
│   └── 03-filters/
└── widgets/           # Dashboard widgets
```

## Skills

The plugin provides specialized skills that can be invoked:

- `filament-docs` - Search and reference documentation
- `filament-resource` - Resource generation workflow
- `filament-forms` - Form schema creation
- `filament-tables` - Table configuration
- `filament-actions` - Action generation
- `filament-widgets` - Widget creation
- `filament-infolists` - Infolist design
- `filament-testing` - Test generation

## Best Practices

1. **Documentation-First**: Always consults official docs before generating code
2. **Artisan Integration**: Uses `php artisan make:filament-*` commands when available
3. **Type Safety**: All generated code uses strict types and proper type hints
4. **Testing**: Generates comprehensive Pest tests alongside components
5. **Error Logging**: Logs solved errors to `~/claude-docs/solved-errors.md` for future reference

## Requirements

- Laravel 10+
- FilamentPHP v4
- PHP 8.2+
- Pest (for testing)
