---
description: Generate Pest tests for FilamentPHP v4 resources covering list, create, edit, view, and authorization
allowed-tools: Skill(testing), Skill(docs), Bash(php:*)
argument-hint: <ResourceName> [--type list|create|edit|view|all] [--with-auth]
---

# Generate FilamentPHP Tests

Generate comprehensive Pest tests for FilamentPHP v4 resources including CRUD operations, validation, and authorization.

## Usage

```bash
# Generate all tests for a resource
/filament-specialist:test PostResource

# Generate specific test type
/filament-specialist:test PostResource --type create

# Generate tests with authorization checks
/filament-specialist:test PostResource --with-auth

# Generate all test types
/filament-specialist:test PostResource --type all
```

## Process

### 1. Consult Documentation

Before generating, read the testing documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/docs/references/general/10-testing/`

### 2. Analyze Resource

Read the resource file to understand:
- Form schema (fields and validation)
- Table configuration (columns, filters, actions)
- Relations
- Custom actions

### 3. Generate Tests

Create tests for:
- Page rendering
- CRUD operations
- Form validation
- Table features
- Actions
- Authorization (if --with-auth)

## Output

Test file at `tests/Feature/Filament/{Resource}Test.php`

## Example Output

For `/filament-specialist:test PostResource --type all --with-auth`:

```php
<?php

declare(strict_types=1);

use App\Filament\Resources\PostResource;
use App\Filament\Resources\PostResource\Pages\CreatePost;
use App\Filament\Resources\PostResource\Pages\EditPost;
use App\Filament\Resources\PostResource\Pages\ListPosts;
use App\Filament\Resources\PostResource\Pages\ViewPost;
use App\Models\Category;
use App\Models\Post;
use App\Models\User;
use Filament\Actions\DeleteAction;
use Filament\Tables\Actions\DeleteBulkAction;

use function Pest\Livewire\livewire;

beforeEach(function () {
    $this->admin = User::factory()->create(['is_admin' => true]);
    $this->user = User::factory()->create(['is_admin' => false]);
});

describe('List Posts Page', function () {
    it('can render the list page', function () {
        $this->actingAs($this->admin);

        livewire(ListPosts::class)
            ->assertSuccessful();
    });

    it('can list posts', function () {
        $this->actingAs($this->admin);
        $posts = Post::factory()->count(5)->create();

        livewire(ListPosts::class)
            ->assertCanSeeTableRecords($posts);
    });

    it('can render all table columns', function () {
        $this->actingAs($this->admin);
        Post::factory()->create();

        livewire(ListPosts::class)
            ->assertCanRenderTableColumn('title')
            ->assertCanRenderTableColumn('author.name')
            ->assertCanRenderTableColumn('status')
            ->assertCanRenderTableColumn('published_at');
    });

    it('can search posts by title', function () {
        $this->actingAs($this->admin);
        $matchingPost = Post::factory()->create(['title' => 'Unique Searchable Title']);
        $otherPost = Post::factory()->create(['title' => 'Different Title']);

        livewire(ListPosts::class)
            ->searchTable('Unique Searchable')
            ->assertCanSeeTableRecords([$matchingPost])
            ->assertCanNotSeeTableRecords([$otherPost]);
    });

    it('can sort posts by title', function () {
        $this->actingAs($this->admin);
        $posts = Post::factory()->count(3)->create();

        livewire(ListPosts::class)
            ->sortTable('title')
            ->assertCanSeeTableRecords($posts->sortBy('title'), inOrder: true)
            ->sortTable('title', 'desc')
            ->assertCanSeeTableRecords($posts->sortByDesc('title'), inOrder: true);
    });

    it('can filter posts by status', function () {
        $this->actingAs($this->admin);
        $publishedPost = Post::factory()->create(['status' => 'published']);
        $draftPost = Post::factory()->create(['status' => 'draft']);

        livewire(ListPosts::class)
            ->filterTable('status', 'published')
            ->assertCanSeeTableRecords([$publishedPost])
            ->assertCanNotSeeTableRecords([$draftPost]);
    });

    it('can bulk delete posts', function () {
        $this->actingAs($this->admin);
        $posts = Post::factory()->count(3)->create();

        livewire(ListPosts::class)
            ->callTableBulkAction(DeleteBulkAction::class, $posts);

        foreach ($posts as $post) {
            $this->assertModelMissing($post);
        }
    });
});

describe('Create Post Page', function () {
    it('can render the create page', function () {
        $this->actingAs($this->admin);

        livewire(CreatePost::class)
            ->assertSuccessful();
    });

    it('has required form fields', function () {
        $this->actingAs($this->admin);

        livewire(CreatePost::class)
            ->assertFormFieldExists('title')
            ->assertFormFieldExists('slug')
            ->assertFormFieldExists('content')
            ->assertFormFieldExists('status')
            ->assertFormFieldExists('author_id');
    });

    it('can create a post', function () {
        $this->actingAs($this->admin);
        $category = Category::factory()->create();
        $author = User::factory()->create();

        $newData = [
            'title' => 'Test Post Title',
            'slug' => 'test-post-title',
            'content' => 'This is the test post content.',
            'status' => 'draft',
            'author_id' => $author->id,
            'category_id' => $category->id,
        ];

        livewire(CreatePost::class)
            ->fillForm($newData)
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertDatabaseHas(Post::class, [
            'title' => 'Test Post Title',
            'slug' => 'test-post-title',
            'author_id' => $author->id,
        ]);
    });

    it('validates required fields', function () {
        $this->actingAs($this->admin);

        livewire(CreatePost::class)
            ->fillForm([
                'title' => '',
                'slug' => '',
                'content' => '',
            ])
            ->call('create')
            ->assertHasFormErrors([
                'title' => 'required',
                'slug' => 'required',
                'content' => 'required',
            ]);
    });

    it('validates title max length', function () {
        $this->actingAs($this->admin);

        livewire(CreatePost::class)
            ->fillForm([
                'title' => str_repeat('a', 256),
            ])
            ->call('create')
            ->assertHasFormErrors(['title' => 'max']);
    });

    it('validates unique slug', function () {
        $this->actingAs($this->admin);
        Post::factory()->create(['slug' => 'existing-slug']);

        livewire(CreatePost::class)
            ->fillForm([
                'title' => 'New Post',
                'slug' => 'existing-slug',
                'content' => 'Content here',
            ])
            ->call('create')
            ->assertHasFormErrors(['slug' => 'unique']);
    });
});

describe('Edit Post Page', function () {
    it('can render the edit page', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create();

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->assertSuccessful();
    });

    it('can retrieve post data', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create();

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->assertFormSet([
                'title' => $post->title,
                'slug' => $post->slug,
                'content' => $post->content,
                'status' => $post->status,
            ]);
    });

    it('can update a post', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create();

        $newData = [
            'title' => 'Updated Title',
            'slug' => 'updated-title',
            'content' => 'Updated content.',
            'status' => 'published',
        ];

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->fillForm($newData)
            ->call('save')
            ->assertHasNoFormErrors();

        expect($post->refresh())
            ->title->toBe('Updated Title')
            ->slug->toBe('updated-title')
            ->status->toBe('published');
    });

    it('can delete a post', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create();

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->callAction(DeleteAction::class);

        $this->assertModelMissing($post);
    });

    it('validates unique slug excluding current record', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create(['slug' => 'my-post']);
        Post::factory()->create(['slug' => 'other-post']);

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->fillForm(['slug' => 'other-post'])
            ->call('save')
            ->assertHasFormErrors(['slug' => 'unique']);
    });
});

describe('View Post Page', function () {
    it('can render the view page', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create();

        livewire(ViewPost::class, ['record' => $post->getRouteKey()])
            ->assertSuccessful();
    });

    it('displays post information', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create([
            'title' => 'Viewable Post Title',
            'status' => 'published',
        ]);

        livewire(ViewPost::class, ['record' => $post->getRouteKey()])
            ->assertSee('Viewable Post Title')
            ->assertSee('published');
    });
});

describe('Authorization', function () {
    it('prevents non-admin from viewing list', function () {
        $this->actingAs($this->user);

        livewire(ListPosts::class)
            ->assertForbidden();
    });

    it('prevents non-admin from creating posts', function () {
        $this->actingAs($this->user);

        livewire(CreatePost::class)
            ->assertForbidden();
    });

    it('prevents non-admin from editing posts', function () {
        $this->actingAs($this->user);
        $post = Post::factory()->create();

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->assertForbidden();
    });

    it('allows admin to access all pages', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create();

        livewire(ListPosts::class)->assertSuccessful();
        livewire(CreatePost::class)->assertSuccessful();
        livewire(EditPost::class, ['record' => $post->getRouteKey()])->assertSuccessful();
        livewire(ViewPost::class, ['record' => $post->getRouteKey()])->assertSuccessful();
    });
});

describe('Custom Actions', function () {
    it('can publish a draft post', function () {
        $this->actingAs($this->admin);
        $post = Post::factory()->create(['status' => 'draft']);

        livewire(EditPost::class, ['record' => $post->getRouteKey()])
            ->callAction('publish');

        expect($post->refresh()->status)->toBe('published');
    });

    it('shows publish action only for drafts', function () {
        $this->actingAs($this->admin);
        $draftPost = Post::factory()->create(['status' => 'draft']);
        $publishedPost = Post::factory()->create(['status' => 'published']);

        livewire(EditPost::class, ['record' => $draftPost->getRouteKey()])
            ->assertActionVisible('publish');

        livewire(EditPost::class, ['record' => $publishedPost->getRouteKey()])
            ->assertActionHidden('publish');
    });
});
```
