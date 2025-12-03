# guerra:generate-pest-test

## Command Overview
Generate comprehensive Pest 4 test suites for PHP, Laravel, Livewire, and Filament applications with full coverage of processes, roles, policies, and page access.

## Syntax
```bash
guerra:generate-pest-test [options] [target]
```

## Options
- `--full` - Generate complete test suite for entire project
- `--analyze` - Analyze existing coverage before generating
- `--type=<type>` - Specify test type (unit, feature, integration, browser)
- `--model=<name>` - Generate tests for specific model
- `--force` - Overwrite existing test files
- `--no-backup` - Skip creating backup of existing tests
- `--dry-run` - Show what would be generated without creating files

## Documentation Reference Order
1. **Pest 4 Documentation** - https://pestphp.com/docs
2. **Filament Testing** - https://filamentphp.com/docs/panels/testing
3. **Livewire Testing** - https://livewire.laravel.com/docs/testing
4. **Laravel Testing** - https://laravel.com/docs/testing

## Implementation Steps

### Step 1: Project Analysis
```php
// Analyze project structure
- Scan app/Models for entities
- Identify app/Policies for authorization
- Locate app/Filament/Resources for admin
- Find app/Livewire components
- Check existing tests/Feature and tests/Unit
```

### Step 2: Test File Generation
Generate test files following Pest 4 syntax:

```php
<?php

use App\Models\User;
use App\Models\Post;
use function Pest\Laravel\{actingAs, get, post, put, delete};

// Process Testing Example
describe('Post Creation Process', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
    });

    it('allows authenticated users to create posts', function () {
        actingAs($this->user)
            ->post('/posts', [
                'title' => 'Test Post',
                'content' => 'Test Content',
            ])
            ->assertRedirect()
            ->assertSessionHas('success');

        expect(Post::count())->toBe(1);
        expect(Post::first()->user_id)->toBe($this->user->id);
    });

    it('validates required fields', function () {
        actingAs($this->user)
            ->post('/posts', [])
            ->assertSessionHasErrors(['title', 'content']);

        expect(Post::count())->toBe(0);
    });

    it('sanitizes content before saving', function () {
        actingAs($this->user)
            ->post('/posts', [
                'title' => 'Test Post',
                'content' => '<script>alert("xss")</script>',
            ]);

        expect(Post::first()->content)
            ->not->toContain('<script>');
    });
});
```

### Step 3: Role and Policy Testing
```php
<?php

use App\Models\{User, Post};
use App\Policies\PostPolicy;
use function Pest\Laravel\actingAs;

describe('Post Policy Authorization', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->editor = User::factory()->editor()->create();
        $this->user = User::factory()->create();
        $this->post = Post::factory()->create();
    });

    describe('viewAny', function () {
        it('allows admins to view all posts', function () {
            expect($this->admin->can('viewAny', Post::class))->toBeTrue();
        });

        it('allows editors to view all posts', function () {
            expect($this->editor->can('viewAny', Post::class))->toBeTrue();
        });

        it('denies regular users from viewing all posts', function () {
            expect($this->user->can('viewAny', Post::class))->toBeFalse();
        });
    });

    describe('update', function () {
        it('allows admins to update any post', function () {
            expect($this->admin->can('update', $this->post))->toBeTrue();
        });

        it('allows owners to update their posts', function () {
            $ownPost = Post::factory()->create(['user_id' => $this->user->id]);
            expect($this->user->can('update', $ownPost))->toBeTrue();
        });

        it('denies users from updating others posts', function () {
            expect($this->user->can('update', $this->post))->toBeFalse();
        });
    });

    describe('delete', function () {
        it('allows admins to delete any post', function () {
            expect($this->admin->can('delete', $this->post))->toBeTrue();
        });

        it('denies editors from deleting posts', function () {
            expect($this->editor->can('delete', $this->post))->toBeFalse();
        });
    });
});
```

### Step 4: Page Access Testing
```php
<?php

use App\Models\User;
use function Pest\Laravel\{actingAs, get};

describe('Admin Panel Access', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->user = User::factory()->create();
    });

    it('allows admins to access dashboard', function () {
        actingAs($this->admin)
            ->get('/admin')
            ->assertSuccessful();
    });

    it('denies regular users from accessing dashboard', function () {
        actingAs($this->user)
            ->get('/admin')
            ->assertForbidden();
    });

    it('redirects guests to login', function () {
        get('/admin')
            ->assertRedirect('/login');
    });
});

describe('Post Management Routes', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->editor = User::factory()->editor()->create();
        $this->user = User::factory()->create();
    });

    it('allows admins to access post index', function () {
        actingAs($this->admin)
            ->get('/admin/posts')
            ->assertSuccessful();
    });

    it('allows editors to access post index', function () {
        actingAs($this->editor)
            ->get('/admin/posts')
            ->assertSuccessful();
    });

    it('denies regular users from post management', function () {
        actingAs($this->user)
            ->get('/admin/posts')
            ->assertForbidden();
    });
});
```

### Step 5: Database and State Testing
```php
<?php

use App\Models\{User, Post};
use function Pest\Laravel\{actingAs, delete};

describe('Post Deletion Process', function () {
    it('soft deletes posts by default', function () {
        $post = Post::factory()->create();
        $admin = User::factory()->admin()->create();

        actingAs($admin)
            ->delete("/admin/posts/{$post->id}")
            ->assertRedirect();

        expect(Post::count())->toBe(0);
        expect(Post::withTrashed()->count())->toBe(1);
    });

    it('maintains referential integrity', function () {
        $user = User::factory()
            ->has(Post::factory()->count(3))
            ->create();

        expect($user->posts()->count())->toBe(3);

        $user->delete();

        expect(Post::where('user_id', $user->id)->count())->toBe(0);
    });

    it('dispatches post deleted event', function () {
        Event::fake();

        $post = Post::factory()->create();
        $post->delete();

        Event::assertDispatched(PostDeleted::class);
    });
});
```

## Test Organization Structure
```
tests/
├── Unit/
│   ├── Models/
│   │   ├── PostTest.php
│   │   └── UserTest.php
│   └── Services/
│       └── PostServiceTest.php
├── Feature/
│   ├── Auth/
│   │   ├── LoginTest.php
│   │   └── RegistrationTest.php
│   ├── Posts/
│   │   ├── CreatePostTest.php
│   │   ├── UpdatePostTest.php
│   │   └── DeletePostTest.php
│   └── Policies/
│       └── PostPolicyTest.php
└── Pest.php
```

## Pest 4 Configuration (Pest.php)
```php
<?php

use Illuminate\Foundation\Testing\RefreshDatabase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
*/

uses(
    Tests\TestCase::class,
    RefreshDatabase::class,
)->in('Feature');

uses(Tests\TestCase::class)->in('Unit');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
*/

function actingAsAdmin(): User
{
    $admin = User::factory()->admin()->create();
    return test()->actingAs($admin);
}

function actingAsEditor(): User
{
    $editor = User::factory()->editor()->create();
    return test()->actingAs($editor);
}

function actingAsUser(): User
{
    $user = User::factory()->create();
    return test()->actingAs($user);
}
```

## Coverage Requirements
- ✅ All model CRUD operations
- ✅ All policies and gates
- ✅ All route access controls
- ✅ All form validations
- ✅ All business processes
- ✅ Database transactions
- ✅ Event dispatching
- ✅ Job queueing
- ✅ Email/notification sending
- ✅ API endpoints

## Best Practices
1. **Use descriptive test names** - Follow "it should..." pattern
2. **Test one thing at a time** - Keep tests focused and atomic
3. **Use factories** - Generate test data consistently
4. **Clean state** - Each test should be independent
5. **Test edge cases** - Include boundary conditions
6. **Mock external services** - Avoid real API calls
7. **Group related tests** - Use describe blocks effectively
8. **Document complex scenarios** - Add comments when needed

## Quality Checklist
Before completing, verify:
- [ ] All tests use Pest 4 syntax (it/describe/beforeEach)
- [ ] Tests follow documentation order (Pest → Filament → Livewire → Laravel)
- [ ] Process tests cover complete workflows
- [ ] Policy tests cover all authorization scenarios
- [ ] Page access tests verify all role combinations
- [ ] Tests use appropriate assertions and expectations
- [ ] Test data uses factories consistently
- [ ] Database is properly refreshed between tests
- [ ] All tests pass successfully
- [ ] Coverage meets project requirements (80%+ recommended)

## Common Patterns

### Dataset Testing
```php
it('validates email format', function (string $email, bool $valid) {
    $response = post('/register', ['email' => $email]);
    
    if ($valid) {
        $response->assertSessionMissing('errors');
    } else {
        $response->assertSessionHasErrors('email');
    }
})->with([
    ['valid@example.com', true],
    ['invalid-email', false],
    ['', false],
    ['@example.com', false],
]);
```

### Hooks
```php
beforeAll(function () {
    // Runs once before all tests in describe block
});

beforeEach(function () {
    // Runs before each test
    $this->user = User::factory()->create();
});

afterEach(function () {
    // Runs after each test
});

afterAll(function () {
    // Runs once after all tests in describe block
});
```

### Shared State
```php
describe('User Actions', function () {
    beforeEach(function () {
        $this->user = User::factory()->create();
        $this->post = Post::factory()->create(['user_id' => $this->user->id]);
    });

    it('can update own post', function () {
        // $this->user and $this->post available here
    });
});
```

## Error Handling
If tests fail:
1. Check Pest 4 syntax compatibility
2. Verify database migrations are current
3. Ensure factories are properly defined
4. Review recent code changes
5. Check environment configuration
6. Validate test dependencies

## Integration with CI/CD
```yaml
# .github/workflows/tests.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install dependencies
        run: composer install
      - name: Run tests
        run: ./vendor/bin/pest --coverage
```
