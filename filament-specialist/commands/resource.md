---
description: Generate a complete FilamentPHP v4 resource with form, table, relations, and tests
allowed-tools: Skill(filament-resource), Skill(filament-docs), Skill(filament-forms), Skill(filament-tables), Skill(filament-testing), Bash(php:*)
argument-hint: <ModelName> [--generate] [--simple] [--soft-deletes] [--view]
---

# Generate FilamentPHP Resource

Create a complete FilamentPHP v4 resource including form schema, table configuration, relation managers, and Pest tests.

## Usage

```bash
# Basic resource
/filament:resource Post

# Generate from model (auto-detect fields)
/filament:resource Post --generate

# Simple resource (modal forms)
/filament:resource Post --simple

# With soft deletes support
/filament:resource Post --soft-deletes

# View-only resource
/filament:resource Post --view
```

## Process

### 1. Consult Documentation

Before generating any code, read the relevant documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/general/03-resources/` for resource patterns
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/forms/` for form fields
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/tables/` for table columns

### 2. Analyze the Model

If the model exists:
1. Read the model file to understand:
   - Fillable attributes
   - Relationships (belongsTo, hasMany, belongsToMany)
   - Casts and accessors
   - Validation rules if defined
2. Read any existing migration for column types

### 3. Generate Base Resource

Use artisan to create the resource:

```bash
php artisan make:filament-resource ModelName [flags]
```

### 4. Customize Form Schema

Based on model analysis:
- Map database columns to appropriate form fields
- Add relationship fields (Select for belongsTo, Repeater for hasMany)
- Include validation rules
- Organize into sections/tabs as appropriate

### 5. Customize Table Configuration

Based on model analysis:
- Add searchable and sortable columns
- Include relationship columns
- Add appropriate filters
- Configure actions (view, edit, delete)
- Add bulk actions

### 6. Create Relation Managers

For each hasMany or belongsToMany relationship:

```bash
php artisan make:filament-relation-manager ResourceName RelationName column_name
```

### 7. Generate Tests

Create comprehensive Pest tests for:
- List page rendering and records display
- Create page with form validation
- Edit page with data retrieval and update
- Delete functionality
- Search, sort, and filter operations
- Authorization (if applicable)

## Output

Generated files:
- `app/Filament/Resources/{Model}Resource.php`
- `app/Filament/Resources/{Model}Resource/Pages/List{Models}.php`
- `app/Filament/Resources/{Model}Resource/Pages/Create{Model}.php`
- `app/Filament/Resources/{Model}Resource/Pages/Edit{Model}.php`
- `app/Filament/Resources/{Model}Resource/Pages/View{Model}.php` (if --view)
- `app/Filament/Resources/{Model}Resource/RelationManagers/*` (if relations)
- `tests/Feature/Filament/{Model}ResourceTest.php`

## Example Output

For `/filament:resource Post`:

```php
// app/Filament/Resources/PostResource.php
<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Filament\Resources\PostResource\Pages;
use App\Filament\Resources\PostResource\RelationManagers;
use App\Models\Post;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class PostResource extends Resource
{
    protected static ?string $model = Post::class;
    protected static ?string $navigationIcon = 'heroicon-o-document-text';
    protected static ?string $navigationGroup = 'Content';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Post Details')
                    ->schema([
                        Forms\Components\TextInput::make('title')
                            ->required()
                            ->maxLength(255)
                            ->live(onBlur: true)
                            ->afterStateUpdated(fn ($state, $set) =>
                                $set('slug', \Str::slug($state))),
                        Forms\Components\TextInput::make('slug')
                            ->required()
                            ->unique(ignoreRecord: true),
                        Forms\Components\Select::make('author_id')
                            ->relationship('author', 'name')
                            ->searchable()
                            ->preload()
                            ->required(),
                        Forms\Components\Select::make('category_id')
                            ->relationship('category', 'name')
                            ->searchable()
                            ->preload(),
                    ])
                    ->columns(2),
                Forms\Components\Section::make('Content')
                    ->schema([
                        Forms\Components\RichEditor::make('content')
                            ->required()
                            ->columnSpanFull(),
                    ]),
                Forms\Components\Section::make('Publishing')
                    ->schema([
                        Forms\Components\Select::make('status')
                            ->options([
                                'draft' => 'Draft',
                                'published' => 'Published',
                            ])
                            ->default('draft')
                            ->required(),
                        Forms\Components\DateTimePicker::make('published_at'),
                        Forms\Components\Toggle::make('is_featured')
                            ->default(false),
                    ])
                    ->columns(3),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('title')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('author.name')
                    ->sortable(),
                Tables\Columns\BadgeColumn::make('status')
                    ->colors([
                        'warning' => 'draft',
                        'success' => 'published',
                    ]),
                Tables\Columns\IconColumn::make('is_featured')
                    ->boolean(),
                Tables\Columns\TextColumn::make('published_at')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'draft' => 'Draft',
                        'published' => 'Published',
                    ]),
                Tables\Filters\SelectFilter::make('author')
                    ->relationship('author', 'name'),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            RelationManagers\CommentsRelationManager::class,
            RelationManagers\TagsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPosts::route('/'),
            'create' => Pages\CreatePost::route('/create'),
            'view' => Pages\ViewPost::route('/{record}'),
            'edit' => Pages\EditPost::route('/{record}/edit'),
        ];
    }
}
```
