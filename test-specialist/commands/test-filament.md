# guerra:test-filament

## Command Overview
Generate comprehensive Pest 4 tests for Filament admin panels, resources, pages, widgets, and custom actions following Filament testing best practices.

## Syntax
```bash
guerra:test-filament [options] [target]
```

## Options
- `--resource=<n>` - Test specific Filament resource
- `--page=<n>` - Test specific Filament page
- `--widget=<n>` - Test specific widget
- `--all` - Test all Filament components
- `--actions` - Include action tests
- `--forms` - Include form field tests
- `--tables` - Include table column/filter tests
- `--access` - Include authorization tests
- `--force` - Overwrite existing test files

## Documentation Reference Order
1. **Pest 4 Documentation** - https://pestphp.com/docs
2. **Filament Testing Documentation** - https://filamentphp.com/docs/panels/testing
3. **Livewire Testing** - https://livewire.laravel.com/docs/testing
4. **Laravel Testing** - https://laravel.com/docs/testing

## Filament Resource Tests

### Basic Resource CRUD Tests
```php
<?php

use App\Filament\Resources\PostResource;
use App\Models\{User, Post};
use function Pest\Livewire\livewire;

describe('PostResource CRUD Operations', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        actingAs($this->admin);
    });

    describe('List Page', function () {
        it('can render list page', function () {
            livewire(PostResource\Pages\ListPosts::class)
                ->assertSuccessful();
        });

        it('can list posts', function () {
            $posts = Post::factory()->count(10)->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->assertCanSeeTableRecords($posts);
        });

        it('can search posts by title', function () {
            $posts = Post::factory()->count(10)->create();
            $targetPost = $posts->first();

            livewire(PostResource\Pages\ListPosts::class)
                ->searchTable($targetPost->title)
                ->assertCanSeeTableRecords([$targetPost])
                ->assertCanNotSeeTableRecords($posts->skip(1));
        });

        it('can filter posts by status', function () {
            $publishedPosts = Post::factory()->published()->count(5)->create();
            $draftPosts = Post::factory()->draft()->count(3)->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->filterTable('status', 'published')
                ->assertCanSeeTableRecords($publishedPosts)
                ->assertCanNotSeeTableRecords($draftPosts);
        });

        it('can sort posts by title', function () {
            $posts = Post::factory()->count(3)->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->sortTable('title')
                ->assertCanSeeTableRecords($posts->sortBy('title'), inOrder: true);
        });

        it('can paginate posts', function () {
            Post::factory()->count(30)->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->assertCanSeeTableRecords(Post::take(10)->get())
                ->call('nextPage')
                ->assertCanSeeTableRecords(Post::skip(10)->take(10)->get());
        });
    });

    describe('Create Page', function () {
        it('can render create page', function () {
            livewire(PostResource\Pages\CreatePost::class)
                ->assertSuccessful();
        });

        it('can create post', function () {
            $newData = Post::factory()->make();

            livewire(PostResource\Pages\CreatePost::class)
                ->fillForm([
                    'title' => $newData->title,
                    'slug' => $newData->slug,
                    'content' => $newData->content,
                    'status' => $newData->status,
                ])
                ->call('create')
                ->assertHasNoFormErrors();

            $this->assertDatabaseHas(Post::class, [
                'title' => $newData->title,
                'slug' => $newData->slug,
                'content' => $newData->content,
            ]);
        });

        it('can validate input', function () {
            livewire(PostResource\Pages\CreatePost::class)
                ->fillForm([
                    'title' => null,
                ])
                ->call('create')
                ->assertHasFormErrors(['title' => 'required']);
        });

        it('can validate unique slug', function () {
            $existingPost = Post::factory()->create();

            livewire(PostResource\Pages\CreatePost::class)
                ->fillForm([
                    'title' => 'New Post',
                    'slug' => $existingPost->slug,
                ])
                ->call('create')
                ->assertHasFormErrors(['slug' => 'unique']);
        });
    });

    describe('Edit Page', function () {
        it('can render edit page', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->assertSuccessful();
        });

        it('can retrieve data', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->assertFormSet([
                    'title' => $post->title,
                    'slug' => $post->slug,
                    'content' => $post->content,
                    'status' => $post->status,
                ]);
        });

        it('can save', function () {
            $post = Post::factory()->create();
            $newData = Post::factory()->make();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->fillForm([
                    'title' => $newData->title,
                    'slug' => $newData->slug,
                    'content' => $newData->content,
                ])
                ->call('save')
                ->assertHasNoFormErrors();

            expect($post->refresh())
                ->title->toBe($newData->title)
                ->slug->toBe($newData->slug)
                ->content->toBe($newData->content);
        });

        it('can validate input', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->fillForm([
                    'title' => null,
                ])
                ->call('save')
                ->assertHasFormErrors(['title' => 'required']);
        });

        it('can delete', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->callAction('delete');

            $this->assertModelMissing($post);
        });
    });
});
```

### Table Actions and Bulk Actions
```php
<?php

describe('PostResource Table Actions', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        actingAs($this->admin);
    });

    describe('Row Actions', function () {
        it('can edit from table', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableAction('edit', $post);

            // Verify redirect or modal opens
        });

        it('can delete from table', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableAction('delete', $post);

            $this->assertModelMissing($post);
        });

        it('can view from table', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableAction('view', $post)
                ->assertSuccessful();
        });
    });

    describe('Bulk Actions', function () {
        it('can bulk delete posts', function () {
            $posts = Post::factory()->count(10)->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableBulkAction('delete', $posts);

            foreach ($posts as $post) {
                $this->assertModelMissing($post);
            }
        });

        it('can bulk publish posts', function () {
            $posts = Post::factory()->draft()->count(5)->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableBulkAction('publish', $posts);

            foreach ($posts as $post) {
                expect($post->refresh()->status)->toBe('published');
            }
        });
    });

    describe('Custom Actions', function () {
        it('can archive post', function () {
            $post = Post::factory()->published()->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableAction('archive', $post);

            expect($post->refresh()->status)->toBe('archived');
        });

        it('can duplicate post', function () {
            $post = Post::factory()->create();

            livewire(PostResource\Pages\ListPosts::class)
                ->callTableAction('duplicate', $post);

            $this->assertDatabaseCount(Post::class, 2);
            
            $duplicate = Post::latest()->first();
            expect($duplicate->title)->toContain('(Copy)');
        });
    });
});
```

### Form Field Tests
```php
<?php

describe('PostResource Form Fields', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        actingAs($this->admin);
    });

    it('can fill and save text input', function () {
        livewire(PostResource\Pages\CreatePost::class)
            ->fillForm([
                'title' => 'Test Title',
            ])
            ->assertFormSet([
                'title' => 'Test Title',
            ]);
    });

    it('can fill and save textarea', function () {
        livewire(PostResource\Pages\CreatePost::class)
            ->fillForm([
                'content' => 'Test Content',
            ])
            ->assertFormSet([
                'content' => 'Test Content',
            ]);
    });

    it('can fill and save select', function () {
        livewire(PostResource\Pages\CreatePost::class)
            ->fillForm([
                'status' => 'published',
            ])
            ->assertFormSet([
                'status' => 'published',
            ]);
    });

    it('can fill and save relationship select', function () {
        $category = Category::factory()->create();

        livewire(PostResource\Pages\CreatePost::class)
            ->fillForm([
                'category_id' => $category->id,
            ])
            ->assertFormSet([
                'category_id' => $category->id,
            ]);
    });

    it('can fill and save file upload', function () {
        Storage::fake('public');

        livewire(PostResource\Pages\CreatePost::class)
            ->fillForm([
                'featured_image' => UploadedFile::fake()->image('test.jpg'),
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $post = Post::latest()->first();
        Storage::disk('public')->assertExists($post->featured_image);
    });

    it('can fill and save repeater', function () {
        livewire(PostResource\Pages\CreatePost::class)
            ->fillForm([
                'meta_tags' => [
                    ['key' => 'author', 'value' => 'John Doe'],
                    ['key' => 'keywords', 'value' => 'test, blog'],
                ],
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $post = Post::latest()->first();
        expect($post->meta_tags)->toHaveCount(2);
    });
});
```

### Authorization Tests
```php
<?php

describe('PostResource Authorization', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->editor = User::factory()->editor()->create();
        $this->user = User::factory()->create();
    });

    describe('Resource Access', function () {
        it('allows admins to access resource', function () {
            actingAs($this->admin);

            livewire(PostResource\Pages\ListPosts::class)
                ->assertSuccessful();
        });

        it('allows editors to access resource', function () {
            actingAs($this->editor);

            livewire(PostResource\Pages\ListPosts::class)
                ->assertSuccessful();
        });

        it('denies regular users from accessing resource', function () {
            actingAs($this->user);

            livewire(PostResource\Pages\ListPosts::class)
                ->assertForbidden();
        });
    });

    describe('Action Visibility', function () {
        it('shows delete action to admins', function () {
            actingAs($this->admin);
            $post = Post::factory()->create();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->assertActionVisible('delete');
        });

        it('hides delete action from editors', function () {
            actingAs($this->editor);
            $post = Post::factory()->create();

            livewire(PostResource\Pages\EditPost::class, [
                'record' => $post->getRouteKey(),
            ])
                ->assertActionHidden('delete');
        });
    });

    describe('Field Visibility', function () {
        it('shows all fields to admins', function () {
            actingAs($this->admin);

            livewire(PostResource\Pages\CreatePost::class)
                ->assertFormFieldExists('title')
                ->assertFormFieldExists('featured')
                ->assertFormFieldExists('status');
        });

        it('hides featured checkbox from editors', function () {
            actingAs($this->editor);

            livewire(PostResource\Pages\CreatePost::class)
                ->assertFormFieldExists('title')
                ->assertFormFieldExists('status')
                ->assertFormFieldDoesNotExist('featured');
        });
    });
});
```

### Widget Tests
```php
<?php

use App\Filament\Widgets\StatsOverview;
use App\Models\Post;

describe('Dashboard Widgets', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        actingAs($this->admin);
    });

    it('can render stats overview widget', function () {
        livewire(StatsOverview::class)
            ->assertSuccessful();
    });

    it('displays correct post count', function () {
        Post::factory()->count(5)->create();

        livewire(StatsOverview::class)
            ->assertSee('5')
            ->assertSee('Total Posts');
    });

    it('displays correct published count', function () {
        Post::factory()->published()->count(3)->create();
        Post::factory()->draft()->count(2)->create();

        livewire(StatsOverview::class)
            ->assertSee('3')
            ->assertSee('Published');
    });

    it('displays correct draft count', function () {
        Post::factory()->published()->count(3)->create();
        Post::factory()->draft()->count(2)->create();

        livewire(StatsOverview::class)
            ->assertSee('2')
            ->assertSee('Drafts');
    });
});
```

### Custom Page Tests
```php
<?php

use App\Filament\Pages\Settings;

describe('Custom Filament Pages', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        actingAs($this->admin);
    });

    it('can render settings page', function () {
        livewire(Settings::class)
            ->assertSuccessful();
    });

    it('can save settings', function () {
        livewire(Settings::class)
            ->fillForm([
                'site_name' => 'My Blog',
                'site_description' => 'A great blog',
            ])
            ->call('save')
            ->assertHasNoFormErrors();

        expect(setting('site_name'))->toBe('My Blog');
        expect(setting('site_description'))->toBe('A great blog');
    });

    it('can validate settings', function () {
        livewire(Settings::class)
            ->fillForm([
                'site_name' => null,
            ])
            ->call('save')
            ->assertHasFormErrors(['site_name' => 'required']);
    });
});
```

### Relation Manager Tests
```php
<?php

use App\Filament\Resources\PostResource\RelationManagers\CommentsRelationManager;

describe('Post Comments Relation Manager', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->post = Post::factory()->create();
        actingAs($this->admin);
    });

    it('can render relation manager', function () {
        livewire(CommentsRelationManager::class, [
            'ownerRecord' => $this->post,
        ])
            ->assertSuccessful();
    });

    it('can list comments', function () {
        $comments = Comment::factory()->count(5)->create([
            'post_id' => $this->post->id,
        ]);

        livewire(CommentsRelationManager::class, [
            'ownerRecord' => $this->post,
        ])
            ->assertCanSeeTableRecords($comments);
    });

    it('can create comment', function () {
        livewire(CommentsRelationManager::class, [
            'ownerRecord' => $this->post,
        ])
            ->callTableAction('create', data: [
                'content' => 'Test comment',
            ])
            ->assertHasNoTableActionErrors();

        expect($this->post->comments()->count())->toBe(1);
    });

    it('can edit comment', function () {
        $comment = Comment::factory()->create([
            'post_id' => $this->post->id,
        ]);

        livewire(CommentsRelationManager::class, [
            'ownerRecord' => $this->post,
        ])
            ->callTableAction('edit', $comment, data: [
                'content' => 'Updated comment',
            ])
            ->assertHasNoTableActionErrors();

        expect($comment->refresh()->content)->toBe('Updated comment');
    });

    it('can delete comment', function () {
        $comment = Comment::factory()->create([
            'post_id' => $this->post->id,
        ]);

        livewire(CommentsRelationManager::class, [
            'ownerRecord' => $this->post,
        ])
            ->callTableAction('delete', $comment);

        $this->assertModelMissing($comment);
    });
});
```

## Best Practices
1. **Test complete workflows** - From list to create to edit
2. **Test all form fields** - Validate each input type
3. **Test table features** - Search, filter, sort, pagination
4. **Test actions** - Both row and bulk actions
5. **Test authorization** - All permission levels
6. **Test widgets** - Stats and data accuracy
7. **Test relation managers** - CRUD on related models
8. **Use factories** - Generate consistent test data
9. **Test validation** - Both client and server side
10. **Test custom pages** - Settings and specialized pages

## Quality Checklist
- [ ] All resource pages tested (List, Create, Edit, View)
- [ ] Table features tested (search, filter, sort, pagination)
- [ ] All actions tested (row, bulk, custom)
- [ ] Form fields validated
- [ ] Authorization properly tested
- [ ] Widgets display correct data
- [ ] Relation managers work correctly
- [ ] Custom pages function properly
- [ ] Tests use Pest 4 syntax
- [ ] All tests pass successfully

## Common Test Patterns

### Testing Modal Actions
```php
it('can open modal action', function () {
    $post = Post::factory()->create();

    livewire(PostResource\Pages\ListPosts::class)
        ->callTableAction('view', $post)
        ->assertSuccessful()
        ->assertSee($post->title);
});
```

### Testing Form Sections
```php
it('can fill form across multiple sections', function () {
    livewire(PostResource\Pages\CreatePost::class)
        ->fillForm([
            'title' => 'Test Post',
            'content' => 'Content',
            'meta_title' => 'SEO Title',
            'meta_description' => 'SEO Description',
        ])
        ->call('create')
        ->assertHasNoFormErrors();
});
```

### Testing Notifications
```php
it('shows success notification after save', function () {
    $post = Post::factory()->create();

    livewire(PostResource\Pages\EditPost::class, [
        'record' => $post->getRouteKey(),
    ])
        ->fillForm(['title' => 'Updated Title'])
        ->call('save')
        ->assertNotified('Saved successfully');
});
```
