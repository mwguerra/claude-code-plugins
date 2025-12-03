# guerra:test-livewire

## Command Overview
Generate comprehensive Pest 4 tests for Livewire components with full coverage of interactions, data binding, validation, events, and component lifecycle.

## Syntax
```bash
guerra:test-livewire [options] [component]
```

## Options
- `--component=<n>` - Test specific Livewire component
- `--all` - Test all Livewire components
- `--interactions` - Include user interaction tests
- `--validation` - Include form validation tests
- `--events` - Include event dispatching/listening tests
- `--authorization` - Include authorization tests
- `--force` - Overwrite existing test files

## Documentation Reference Order
1. **Pest 4 Documentation** - https://pestphp.com/docs
2. **Filament Testing** - https://filamentphp.com/docs/panels/testing
3. **Livewire Testing Documentation** - https://livewire.laravel.com/docs/testing
4. **Laravel Testing** - https://laravel.com/docs/testing

## Basic Livewire Component Tests

### Component Rendering
```php
<?php

use App\Livewire\CreatePost;
use App\Models\User;
use function Pest\Laravel\actingAs;
use function Pest\Livewire\livewire;

describe('CreatePost Component', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('can render component', function () {
        livewire(CreatePost::class)
            ->assertStatus(200);
    });

    it('can see form fields', function () {
        livewire(CreatePost::class)
            ->assertSee('Title')
            ->assertSee('Content')
            ->assertSee('Status');
    });

    it('initializes with default values', function () {
        livewire(CreatePost::class)
            ->assertSet('status', 'draft')
            ->assertSet('title', '')
            ->assertSet('content', '');
    });
});
```

### Property Binding Tests
```php
<?php

describe('CreatePost Property Binding', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('can set title property', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->assertSet('title', 'Test Post');
    });

    it('can set content property', function () {
        livewire(CreatePost::class)
            ->set('content', 'Test content')
            ->assertSet('content', 'Test content');
    });

    it('can set status property', function () {
        livewire(CreatePost::class)
            ->set('status', 'published')
            ->assertSet('status', 'published');
    });

    it('can set multiple properties', function () {
        livewire(CreatePost::class)
            ->set([
                'title' => 'Test Post',
                'content' => 'Test content',
                'status' => 'published',
            ])
            ->assertSet('title', 'Test Post')
            ->assertSet('content', 'Test content')
            ->assertSet('status', 'published');
    });
});
```

### Form Submission Tests
```php
<?php

use App\Models\Post;

describe('CreatePost Form Submission', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('can create post', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', 'Test content')
            ->set('status', 'draft')
            ->call('save')
            ->assertHasNoErrors()
            ->assertRedirect('/posts');

        expect(Post::count())->toBe(1);
        
        $post = Post::first();
        expect($post->title)->toBe('Test Post');
        expect($post->content)->toBe('Test content');
        expect($post->status)->toBe('draft');
    });

    it('validates required fields', function () {
        livewire(CreatePost::class)
            ->set('title', '')
            ->call('save')
            ->assertHasErrors(['title' => 'required']);
    });

    it('validates title length', function () {
        livewire(CreatePost::class)
            ->set('title', str_repeat('a', 256))
            ->call('save')
            ->assertHasErrors(['title' => 'max']);
    });

    it('validates content is required', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', '')
            ->call('save')
            ->assertHasErrors(['content' => 'required']);
    });

    it('validates status is in list', function () {
        livewire(CreatePost::class)
            ->set('status', 'invalid')
            ->call('save')
            ->assertHasErrors(['status' => 'in']);
    });
});
```

### Real-Time Validation Tests
```php
<?php

describe('CreatePost Real-Time Validation', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('validates title on blur', function () {
        livewire(CreatePost::class)
            ->set('title', '')
            ->call('validateOnly', 'title')
            ->assertHasErrors(['title' => 'required']);
    });

    it('clears error when field is valid', function () {
        livewire(CreatePost::class)
            ->set('title', '')
            ->call('validateOnly', 'title')
            ->assertHasErrors(['title' => 'required'])
            ->set('title', 'Valid Title')
            ->call('validateOnly', 'title')
            ->assertHasNoErrors();
    });

    it('shows character count for content', function () {
        livewire(CreatePost::class)
            ->set('content', 'Test')
            ->assertSee('4 / 1000');
    });
});
```

### Component Actions and Methods
```php
<?php

describe('CreatePost Actions', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('can call save method', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', 'Test content')
            ->call('save')
            ->assertDispatched('post-created');
    });

    it('can call cancel method', function () {
        livewire(CreatePost::class)
            ->call('cancel')
            ->assertRedirect('/posts');
    });

    it('can call preview method', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', 'Test content')
            ->call('preview')
            ->assertSet('showPreview', true)
            ->assertSee('Test Post')
            ->assertSee('Test content');
    });

    it('can toggle draft mode', function () {
        livewire(CreatePost::class)
            ->assertSet('status', 'draft')
            ->call('toggleDraft')
            ->assertSet('status', 'published');
    });
});
```

### Event Dispatching Tests
```php
<?php

describe('CreatePost Event Dispatching', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('dispatches post-created event', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', 'Test content')
            ->call('save')
            ->assertDispatched('post-created');
    });

    it('dispatches event with data', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', 'Test content')
            ->call('save')
            ->assertDispatched('post-created', function ($event) {
                return $event['title'] === 'Test Post';
            });
    });

    it('dispatches browser event', function () {
        livewire(CreatePost::class)
            ->call('save')
            ->assertDispatchedBrowserEvent('post-saved');
    });
});
```

### Event Listening Tests
```php
<?php

use App\Livewire\PostList;

describe('PostList Event Listening', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('refreshes when post-created event is fired', function () {
        $component = livewire(PostList::class);
        
        // Initial state
        expect($component->get('posts'))->toHaveCount(0);
        
        // Create a post and dispatch event
        Post::factory()->create();
        $component->dispatch('post-created');
        
        // Component should refresh
        expect($component->get('posts'))->toHaveCount(1);
    });

    it('listens to post-deleted event', function () {
        $post = Post::factory()->create();
        
        livewire(PostList::class)
            ->assertSee($post->title)
            ->dispatch('post-deleted', $post->id)
            ->assertDontSee($post->title);
    });
});
```

### File Upload Tests
```php
<?php

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

describe('CreatePost File Upload', function () {
    beforeEach(function () {
        Storage::fake('public');
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('can upload featured image', function () {
        $file = UploadedFile::fake()->image('test.jpg');

        livewire(CreatePost::class)
            ->set('featuredImage', $file)
            ->assertSet('featuredImage', $file);
    });

    it('validates image type', function () {
        $file = UploadedFile::fake()->create('document.pdf');

        livewire(CreatePost::class)
            ->set('featuredImage', $file)
            ->assertHasErrors(['featuredImage' => 'image']);
    });

    it('validates image size', function () {
        $file = UploadedFile::fake()->image('huge.jpg')->size(3000);

        livewire(CreatePost::class)
            ->set('featuredImage', $file)
            ->assertHasErrors(['featuredImage' => 'max']);
    });

    it('stores uploaded image', function () {
        $file = UploadedFile::fake()->image('test.jpg');

        livewire(CreatePost::class)
            ->set('title', 'Test Post')
            ->set('content', 'Test content')
            ->set('featuredImage', $file)
            ->call('save');

        $post = Post::first();
        Storage::disk('public')->assertExists($post->featured_image);
    });

    it('can remove uploaded image', function () {
        $file = UploadedFile::fake()->image('test.jpg');

        livewire(CreatePost::class)
            ->set('featuredImage', $file)
            ->call('removeFeaturedImage')
            ->assertSet('featuredImage', null);
    });
});
```

### Nested Component Tests
```php
<?php

use App\Livewire\{PostForm, TagSelector};

describe('Nested Livewire Components', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('can render child component', function () {
        livewire(PostForm::class)
            ->assertSeeLivewire(TagSelector::class);
    });

    it('can interact with child component', function () {
        $tag = Tag::factory()->create();

        livewire(PostForm::class)
            ->call('selectTag', $tag->id)
            ->assertSet('selectedTags', [$tag->id]);
    });

    it('parent receives event from child', function () {
        livewire(PostForm::class)
            ->dispatch('tag-selected', 1)
            ->assertSet('selectedTags', [1]);
    });
});
```

### Pagination Tests
```php
<?php

describe('PostList Pagination', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
        Post::factory()->count(30)->create();
    });

    it('can paginate results', function () {
        livewire(PostList::class)
            ->assertSee(Post::take(10)->pluck('title')->toArray())
            ->call('nextPage')
            ->assertSee(Post::skip(10)->take(10)->pluck('title')->toArray());
    });

    it('shows correct page count', function () {
        livewire(PostList::class)
            ->assertSee('Page 1 of 3');
    });

    it('can go to specific page', function () {
        livewire(PostList::class)
            ->call('gotoPage', 2)
            ->assertSee('Page 2 of 3');
    });
});
```

### Search and Filter Tests
```php
<?php

describe('PostList Search and Filter', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
        
        Post::factory()->create(['title' => 'Laravel Tutorial']);
        Post::factory()->create(['title' => 'PHP Guide']);
        Post::factory()->create(['title' => 'JavaScript Basics']);
    });

    it('can search posts', function () {
        livewire(PostList::class)
            ->set('search', 'Laravel')
            ->assertSee('Laravel Tutorial')
            ->assertDontSee('PHP Guide')
            ->assertDontSee('JavaScript Basics');
    });

    it('can filter by status', function () {
        Post::factory()->published()->count(2)->create();
        Post::factory()->draft()->count(3)->create();

        livewire(PostList::class)
            ->set('filterStatus', 'published')
            ->assertSee(Post::published()->count() . ' posts');
    });

    it('can combine search and filter', function () {
        livewire(PostList::class)
            ->set('search', 'Laravel')
            ->set('filterStatus', 'published')
            ->assertSee('Laravel Tutorial');
    });

    it('can clear filters', function () {
        livewire(PostList::class)
            ->set('search', 'Laravel')
            ->set('filterStatus', 'published')
            ->call('clearFilters')
            ->assertSet('search', '')
            ->assertSet('filterStatus', 'all');
    });
});
```

### Authorization Tests
```php
<?php

describe('CreatePost Authorization', function () {
    it('denies guests from accessing component', function () {
        livewire(CreatePost::class)
            ->assertForbidden();
    });

    it('denies regular users from creating posts', function () {
        $user = User::factory()->create(['role' => 'user']);
        actingAs($user);

        livewire(CreatePost::class)
            ->assertForbidden();
    });

    it('allows authors to create posts', function () {
        $author = User::factory()->create(['role' => 'author']);
        actingAs($author);

        livewire(CreatePost::class)
            ->assertSuccessful();
    });

    it('allows admins to create posts', function () {
        $admin = User::factory()->admin()->create();
        actingAs($admin);

        livewire(CreatePost::class)
            ->assertSuccessful();
    });
});
```

### Loading States Tests
```php
<?php

describe('PostList Loading States', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('shows loading indicator during search', function () {
        livewire(PostList::class)
            ->set('search', 'test')
            ->assertSee('Loading...');
    });

    it('shows skeleton while loading', function () {
        livewire(PostList::class)
            ->call('loadMore')
            ->assertSee('skeleton');
    });
});
```

### Computed Property Tests
```php
<?php

describe('CreatePost Computed Properties', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('computes slug from title', function () {
        livewire(CreatePost::class)
            ->set('title', 'Test Post Title')
            ->assertSet('slug', 'test-post-title');
    });

    it('computes word count from content', function () {
        livewire(CreatePost::class)
            ->set('content', 'This is a test content')
            ->assertSee('5 words');
    });

    it('computes reading time', function () {
        livewire(CreatePost::class)
            ->set('content', str_repeat('word ', 500))
            ->assertSee('2 min read');
    });
});
```

### Query String Tests
```php
<?php

describe('PostList Query String', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        actingAs($this->user);
    });

    it('syncs search with query string', function () {
        livewire(PostList::class)
            ->set('search', 'laravel')
            ->assertQueryStringHas('search', 'laravel');
    });

    it('syncs page with query string', function () {
        Post::factory()->count(30)->create();

        livewire(PostList::class)
            ->call('gotoPage', 2)
            ->assertQueryStringHas('page', 2);
    });

    it('initializes from query string', function () {
        livewire(PostList::class, ['search' => 'test'])
            ->assertSet('search', 'test');
    });
});
```

## Best Practices
1. **Test component rendering** - Verify UI displays correctly
2. **Test property binding** - Ensure data flows properly
3. **Test user interactions** - Click, type, submit actions
4. **Test validation** - Both real-time and on submit
5. **Test events** - Dispatching and listening
6. **Test file uploads** - Including validation
7. **Test authorization** - Access control per role
8. **Test loading states** - Skeleton screens and indicators
9. **Test computed properties** - Derived data accuracy
10. **Use factories** - Generate consistent test data

## Quality Checklist
- [ ] Component renders successfully
- [ ] All properties bind correctly
- [ ] Form submissions work
- [ ] Validation rules tested
- [ ] Real-time validation works
- [ ] Events dispatch and listen properly
- [ ] File uploads validated
- [ ] Authorization enforced
- [ ] Loading states display
- [ ] Pagination functions correctly
- [ ] Search and filters work
- [ ] Tests use Pest 4 syntax
- [ ] All tests pass

## Common Livewire Test Patterns

### Testing Modal Components
```php
it('can open and close modal', function () {
    livewire(PostModal::class)
        ->assertSet('showModal', false)
        ->call('openModal')
        ->assertSet('showModal', true)
        ->call('closeModal')
        ->assertSet('showModal', false);
});
```

### Testing Debounced Input
```php
it('debounces search input', function () {
    livewire(PostList::class)
        ->set('search', 't')
        ->set('search', 'te')
        ->set('search', 'test')
        ->assertNotDispatched('search-updated')
        ->wait(500) // Wait for debounce
        ->assertDispatched('search-updated');
});
```

### Testing Component Refresh
```php
it('can refresh component', function () {
    $post = Post::factory()->create(['title' => 'Original']);
    
    $component = livewire(EditPost::class, ['post' => $post]);
    
    $post->update(['title' => 'Updated']);
    
    $component->call('$refresh')
        ->assertSee('Updated');
});
```
