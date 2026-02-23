---
description: Create FilamentPHP v4 form schemas with field types, validation rules, sections, and relationship fields
allowed-tools: Skill(forms), Skill(docs), Bash(php:*)
argument-hint: <description> [--resource ResourceName] [--for model|action|standalone]
---

# Generate FilamentPHP Form Schema

Create a FilamentPHP v4 form schema with appropriate field types, validation rules, and layout components.

## Usage

```bash
# Describe the form you need
/filament-specialist:form "user registration with name, email, password, and profile picture"

# For a specific resource
/filament-specialist:form "product with name, price, description, category, and images" --resource ProductResource

# For a modal action
/filament-specialist:form "send email with subject, recipient, and body" --for action
```

## Process

### 1. Consult Documentation

Before generating, read the forms documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/docs/references/forms/`
- Identify appropriate field types for each requirement

### 2. Analyze Requirements

Parse the description to identify:
- Field names and types
- Required vs optional fields
- Relationships (belongs to, has many)
- File uploads
- Layout preferences

### 3. Map to Filament Field Types

| Requirement | Filament Field |
|-------------|----------------|
| Text/string | TextInput |
| Long text | Textarea or RichEditor |
| Number | TextInput::numeric() |
| Email | TextInput::email() |
| Password | TextInput::password() |
| Date | DatePicker |
| DateTime | DateTimePicker |
| Boolean | Toggle or Checkbox |
| Selection | Select or Radio |
| Multiple selection | CheckboxList or Select::multiple() |
| File | FileUpload |
| Image | FileUpload::image() |
| Relationship (one) | Select::relationship() |
| Relationship (many) | CheckboxList::relationship() |
| Nested items | Repeater |
| Flexible content | Builder |

### 4. Generate Schema

Create the form schema with:
- Proper field configurations
- Validation rules
- Layout organization (sections, tabs, grids)
- Conditional visibility if needed

## Output

Complete form schema code with:
- All necessary imports
- Properly configured fields
- Validation rules
- Layout components
- Helper text and placeholders

## Example Output

For `/filament-specialist:form "user registration with name, email, password, and profile picture"`:

```php
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Grid;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\FileUpload;
use Illuminate\Support\Facades\Hash;

public static function form(Form $form): Form
{
    return $form
        ->schema([
            Section::make('Account Information')
                ->description('Enter the user\'s basic account details')
                ->schema([
                    Grid::make(2)
                        ->schema([
                            TextInput::make('name')
                                ->label('Full Name')
                                ->required()
                                ->maxLength(255)
                                ->placeholder('John Doe'),
                            TextInput::make('email')
                                ->label('Email Address')
                                ->email()
                                ->required()
                                ->unique(ignoreRecord: true)
                                ->placeholder('john@example.com'),
                        ]),
                    Grid::make(2)
                        ->schema([
                            TextInput::make('password')
                                ->label('Password')
                                ->password()
                                ->required(fn (string $operation): bool => $operation === 'create')
                                ->dehydrateStateUsing(fn (string $state): string => Hash::make($state))
                                ->dehydrated(fn (?string $state): bool => filled($state))
                                ->minLength(8)
                                ->confirmed(),
                            TextInput::make('password_confirmation')
                                ->label('Confirm Password')
                                ->password()
                                ->required(fn (string $operation): bool => $operation === 'create')
                                ->dehydrated(false),
                        ]),
                ]),
            Section::make('Profile')
                ->description('Optional profile information')
                ->schema([
                    FileUpload::make('avatar')
                        ->label('Profile Picture')
                        ->image()
                        ->imageEditor()
                        ->circleCropper()
                        ->disk('public')
                        ->directory('avatars')
                        ->visibility('public')
                        ->maxSize(2048)
                        ->helperText('Upload a profile picture (max 2MB)'),
                ])
                ->collapsible(),
        ]);
}
```

## Field Type Examples

### Text Fields
```php
TextInput::make('title')
    ->required()
    ->maxLength(255)
    ->placeholder('Enter title...')
    ->helperText('This will be displayed as the main heading');

TextInput::make('price')
    ->numeric()
    ->prefix('$')
    ->minValue(0)
    ->step(0.01);

TextInput::make('email')
    ->email()
    ->unique(table: User::class, ignoreRecord: true);
```

### Selection Fields
```php
Select::make('status')
    ->options([
        'draft' => 'Draft',
        'published' => 'Published',
    ])
    ->default('draft')
    ->required();

Select::make('category_id')
    ->relationship('category', 'name')
    ->searchable()
    ->preload()
    ->createOptionForm([
        TextInput::make('name')->required(),
    ]);
```

### Boolean Fields
```php
Toggle::make('is_active')
    ->label('Active')
    ->default(true)
    ->onColor('success')
    ->offColor('danger');

Checkbox::make('terms')
    ->label('I agree to the terms')
    ->required()
    ->accepted();
```

### Date Fields
```php
DatePicker::make('birth_date')
    ->native(false)
    ->displayFormat('d/m/Y')
    ->maxDate(now());

DateTimePicker::make('published_at')
    ->native(false)
    ->seconds(false);
```

### File Fields
```php
FileUpload::make('document')
    ->disk('public')
    ->directory('documents')
    ->acceptedFileTypes(['application/pdf'])
    ->maxSize(10240);

FileUpload::make('images')
    ->image()
    ->multiple()
    ->reorderable()
    ->directory('gallery');
```

### Complex Fields
```php
Repeater::make('items')
    ->relationship()
    ->schema([
        TextInput::make('name')->required(),
        TextInput::make('quantity')->numeric()->required(),
    ])
    ->columns(2)
    ->addActionLabel('Add Item');

Builder::make('content')
    ->blocks([
        Builder\Block::make('paragraph')
            ->schema([
                RichEditor::make('content'),
            ]),
        Builder\Block::make('image')
            ->schema([
                FileUpload::make('url')->image(),
                TextInput::make('alt'),
            ]),
    ]);
```
