# PRD Ingestion Examples for MWGuerra Task Manager

These examples show how to convert `.taskmanager/docs/prd.md` into a hierarchical, level-by-level expanded set of tasks inside `.taskmanager/tasks.json`, fully compliant with the MWGuerra Task Manager schema and the Task Manager Skill instructions. (See SKILL.md for mandatory step-by-step expansion logic.)

---

## Example PRD

Content of `.taskmanager/docs/prd.md`:

```markdown
# Bandwidth Widget – Real-time Usage

## Objective
Provide a real-time bandwidth usage widget for project Likker PCAST so users
can monitor current traffic and recent history.

## Requirements
- Show current bandwidth usage (Mbps) updating at least every 5 seconds
- Show a small chart of last 5 minutes of usage
- Include warning state when usage exceeds 80% of configured capacity
- Persist historical data to be used in other reports
- Expose a simple JSON API endpoint for the widget

## Non-goals
- No authentication/authorization changes
- No UI theming changes

## Constraints
- Use existing Laravel + Reverb stack
- Use existing Redis instance for short-term storage
- Frontend is in React with chart.js
```

---

# Expected `tasks.json` Structure (Schema-Compliant)

When ingesting this PRD, `.taskmanager/tasks.json` should be updated with a **level-by-level expansion**:

1. **Level 1 = Epics (top-level tasks)**
2. **Level 2 = Subtasks of each epic**
3. **Level 3 = Subtasks of each Level 2 task (only if complexity requires it)**

Below is an illustrative example.

```jsonc
{
  "version": "1.0.0",
  "project": {
    "id": "likker-pcast",
    "name": "Likker PCAST",
    "description": "Bandwidth monitoring and real-time features."
  },
  "tasks": [
    {
      "id": "1",
      "parentId": null,
      "title": "Implement real-time bandwidth widget for Likker PCAST",
      "description": "Top-level epic covering backend, frontend, realtime streaming, warnings, persistence, and tests.",
      "status": "planned",
      "type": "feature",
      "priority": "high",
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multi-system integration: backend, realtime updates, frontend visualization, persistence.",
        "recommendedSubtasks": 6,
        "expansionPrompt": "Expand into backend, UI, realtime, persistence, thresholds, and testing subtasks."
      },
      "dependencies": [],
      "dependencyAnalysis": {
        "blockedBy": [],
        "blocks": [],
        "conflictsWith": [],
        "notes": ""
      },
      "owner": "",
      "tags": ["frontend", "backend", "realtime", "laravel", "redis", "chartjs"],
      "details": "",
      "testStrategy": "Full coverage with Pest: API endpoints, realtime updates, warning threshold logic.",
      "createdAt": "2025-01-01T00:00:00.000Z",
      "updatedAt": "2025-01-01T00:00:00.000Z",
      "meta": {},
      "subtasks": [

        // ------------------------------------------------------
        // Level 2 Subtasks (expansion of epic)
        // ------------------------------------------------------

        {
          "id": "1.1",
          "parentId": "1",
          "title": "Confirm telemetry source and capacity thresholds",
          "description": "Define where bandwidth metrics originate and what constitutes 80% capacity.",
          "status": "planned",
          "type": "analysis",
          "priority": "high",
          "complexity": {
            "score": 1,
            "scale": "XS",
            "reasoning": "Simple analysis and definitions.",
            "recommendedSubtasks": 0
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["analysis"],
          "details": "",
          "testStrategy": "",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": []
        },

        {
          "id": "1.2",
          "parentId": "1",
          "title": "Implement bandwidth API endpoint",
          "description": "Expose current bandwidth + last 5 minutes history through a Laravel JSON API.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "Requires data access, formatting, and integration with frontend.",
            "recommendedSubtasks": 3,
            "expansionPrompt": "Split into endpoint definition, data retrieval, and response formatting."
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["backend", "laravel", "api"],
          "details": "",
          "testStrategy": "Pest tests verifying endpoint structure and realtime correctness.",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": [
            {
              "id": "1.2.1",
              "parentId": "1.2",
              "title": "Define endpoint contract",
              "description": "Specify response schema, error handling, and required fields.",
              "status": "planned",
              "type": "analysis",
              "priority": "medium",
              "complexity": {
                "score": 1,
                "scale": "XS"
              },
              "dependencies": [],
              "dependencyAnalysis": {},
              "tags": ["backend"],
              "createdAt": "2025-01-01T00:00:00.000Z",
              "updatedAt": "2025-01-01T00:00:00.000Z",
              "subtasks": []
            },
            {
              "id": "1.2.2",
              "parentId": "1.2",
              "title": "Fetch bandwidth data and 5-minute window",
              "description": "Read metrics from telemetry source and compile the rolling window.",
              "status": "planned",
              "type": "feature",
              "priority": "medium",
              "complexity": { "score": 2, "scale": "S" },
              "dependencies": [],
              "dependencyAnalysis": {},
              "tags": ["backend"],
              "createdAt": "2025-01-01T00:00:00.000Z",
              "updatedAt": "2025-01-01T00:00:00.000Z",
              "subtasks": []
            },
            {
              "id": "1.2.3",
              "parentId": "1.2",
              "title": "Build JSON response formatter",
              "description": "Structure consistent payload for frontend consumption.",
              "status": "planned",
              "type": "feature",
              "priority": "medium",
              "complexity": { "score": 1, "scale": "XS" },
              "dependencies": [],
              "dependencyAnalysis": {},
              "tags": ["backend"],
              "createdAt": "2025-01-01T00:00:00.000Z",
              "updatedAt": "2025-01-01T00:00:00.000Z",
              "subtasks": []
            }
          ]
        },

        {
          "id": "1.3",
          "parentId": "1",
          "title": "Implement realtime update mechanism",
          "description": "Use Laravel Reverb to push updates at least every 5 seconds.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "Requires pub/sub, client connections, and fallback handling.",
            "recommendedSubtasks": 2
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["backend", "realtime", "reverb"],
          "details": "",
          "testStrategy": "",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": []
        },

        {
          "id": "1.4",
          "parentId": "1",
          "title": "Create React bandwidth widget UI",
          "description": "Build UI component with chart.js rendering current and 5-minute metrics.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "UI rendering, state management, chart integration.",
            "recommendedSubtasks": 3
          },
          "dependencies": [],
          "dependencyAnalysis": {},
          "owner": "",
          "tags": ["frontend", "react", "chartjs"],
          "details": "",
          "testStrategy": "",
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z",
          "meta": {},
          "subtasks": []
        },

        {
          "id": "1.5",
          "parentId": "1",
          "title": "Implement warning state at >80% capacity",
          "description": "Show alert style when usage exceeds threshold.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 1, "scale": "XS" },
          "tags": ["frontend"],
          "dependencies": [],
          "dependencyAnalysis": {},
          "subtasks": [],
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z"
        },

        {
          "id": "1.6",
          "parentId": "1",
          "title": "Persist bandwidth history",
          "description": "Store rolling bandwidth metrics in Redis for reports.",
          "status": "planned",
          "priority": "medium",
          "type": "feature",
          "complexity": {
            "score": 2,
            "scale": "S"
          },
          "tags": ["backend", "redis"],
          "dependencies": [],
          "dependencyAnalysis": {},
          "subtasks": [],
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z"
        },

        {
          "id": "1.7",
          "parentId": "1",
          "title": "Add tests and monitoring",
          "description": "Implement Pest tests and minimal monitoring hooks.",
          "status": "planned",
          "type": "chore",
          "priority": "medium",
          "complexity": {
            "score": 2,
            "scale": "S"
          },
          "tags": ["tests", "monitoring"],
          "dependencies": [],
          "dependencyAnalysis": {},
          "subtasks": [],
          "createdAt": "2025-01-01T00:00:00.000Z",
          "updatedAt": "2025-01-01T00:00:00.000Z"
        }
      ]
    }
  ]
}
```

---

# Key Conformance Notes

### ✔ Skill Compliance (Level-by-Level)

* Top-level task → many Level 2 tasks → Level 3 subtasks only where needed
* Complexity-driven expansion aligns with the Skill instructions

### ✔ Tasks Schema Compliance

* `status` uses allowed enum values
* `complexity` uses required fields:

  * `score`, `scale`, `reasoning`, `recommendedSubtasks`, `expansionPrompt`
* All required fields from schema included
* All IDs match regex: `^[0-9]+(\.[0-9]+)*$`
* `additionalProperties: false` respected

---

# Folder Input Example

This example demonstrates how to create tasks from a **folder of documentation files** instead of a single PRD.

## Example Folder Structure

```
docs/e-commerce-platform/
├── README.md                    # Project overview
├── architecture.md              # System architecture
├── database/
│   └── schema.md                # Database schema design
├── features/
│   ├── user-auth.md             # User authentication feature
│   ├── product-catalog.md       # Product catalog feature
│   └── shopping-cart.md         # Shopping cart feature
└── api/
    └── endpoints.md             # API endpoint definitions
```

## File Contents

### README.md
```markdown
# E-Commerce Platform

A modern e-commerce platform with user authentication, product catalog, and shopping cart functionality.

## Goals
- Secure user authentication with OAuth support
- Searchable product catalog with filtering
- Persistent shopping cart with checkout flow
```

### architecture.md
```markdown
# System Architecture

## Tech Stack
- Backend: Laravel 11
- Frontend: React with TypeScript
- Database: PostgreSQL
- Cache: Redis
- Search: Meilisearch

## Components
- API Gateway (Laravel)
- Frontend SPA (React)
- Background Jobs (Laravel Queues)
- Search Service (Meilisearch)
```

### database/schema.md
```markdown
# Database Schema

## Users Table
- id, email, password_hash, name, created_at, updated_at

## Products Table
- id, name, description, price, stock_quantity, category_id, created_at

## Cart Items Table
- id, user_id, product_id, quantity, created_at
```

### features/user-auth.md
```markdown
# User Authentication

## Requirements
- Email/password registration and login
- OAuth integration (Google, GitHub)
- Password reset via email
- Session management with remember me

## Security
- Passwords hashed with bcrypt
- CSRF protection on all forms
- Rate limiting on auth endpoints
```

### features/product-catalog.md
```markdown
# Product Catalog

## Requirements
- List products with pagination
- Filter by category, price range
- Full-text search via Meilisearch
- Product detail pages with images

## Admin Features
- CRUD operations for products
- Bulk import/export via CSV
```

### features/shopping-cart.md
```markdown
# Shopping Cart

## Requirements
- Add/remove items from cart
- Update quantities
- Persist cart for logged-in users
- Guest cart with session storage
- Calculate totals with tax

## Checkout
- Address form
- Payment integration (Stripe)
- Order confirmation email
```

### api/endpoints.md
```markdown
# API Endpoints

## Authentication
- POST /api/auth/register
- POST /api/auth/login
- POST /api/auth/logout
- POST /api/auth/password/reset

## Products
- GET /api/products
- GET /api/products/{id}
- GET /api/products/search?q=

## Cart
- GET /api/cart
- POST /api/cart/items
- PUT /api/cart/items/{id}
- DELETE /api/cart/items/{id}
- POST /api/cart/checkout
```

---

## Aggregated PRD Content

When `/taskmanager:plan docs/e-commerce-platform/` is run, the files are aggregated:

```markdown
# From: README.md

# E-Commerce Platform

A modern e-commerce platform with user authentication, product catalog, and shopping cart functionality.

## Goals
- Secure user authentication with OAuth support
- Searchable product catalog with filtering
- Persistent shopping cart with checkout flow

---

# From: api/endpoints.md

# API Endpoints

## Authentication
- POST /api/auth/register
...

---

# From: architecture.md

# System Architecture

## Tech Stack
- Backend: Laravel 11
...

---

# From: database/schema.md

# Database Schema

## Users Table
...

---

# From: features/product-catalog.md

# Product Catalog

## Requirements
...

---

# From: features/shopping-cart.md

# Shopping Cart

## Requirements
...

---

# From: features/user-auth.md

# User Authentication

## Requirements
...
```

---

## Expected `tasks.json` from Folder Input

```jsonc
{
  "version": "1.0.0",
  "project": {
    "id": "e-commerce-platform",
    "name": "E-Commerce Platform",
    "description": "Modern e-commerce platform with user auth, product catalog, and shopping cart."
  },
  "tasks": [
    {
      "id": "1",
      "parentId": null,
      "title": "Implement user authentication system",
      "description": "Complete auth system with email/password and OAuth support as defined in features/user-auth.md",
      "status": "planned",
      "type": "feature",
      "priority": "critical",
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multiple auth methods, security requirements, and API endpoints to implement.",
        "recommendedSubtasks": 5,
        "expansionPrompt": "Split into registration, login, OAuth, password reset, and session management."
      },
      "dependencies": [],
      "tags": ["auth", "security", "laravel", "api"],
      "subtasks": [
        {
          "id": "1.1",
          "parentId": "1",
          "title": "Implement email/password registration",
          "description": "POST /api/auth/register endpoint with validation and bcrypt hashing.",
          "status": "planned",
          "type": "feature",
          "priority": "critical",
          "complexity": { "score": 2, "scale": "S" },
          "subtasks": []
        },
        {
          "id": "1.2",
          "parentId": "1",
          "title": "Implement login and session management",
          "description": "POST /api/auth/login with remember-me token support.",
          "status": "planned",
          "type": "feature",
          "priority": "critical",
          "complexity": { "score": 2, "scale": "S" },
          "subtasks": []
        },
        {
          "id": "1.3",
          "parentId": "1",
          "title": "Implement OAuth integration",
          "description": "Google and GitHub OAuth providers using Laravel Socialite.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 3, "scale": "M" },
          "subtasks": []
        },
        {
          "id": "1.4",
          "parentId": "1",
          "title": "Implement password reset flow",
          "description": "POST /api/auth/password/reset with email notification.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 2, "scale": "S" },
          "subtasks": []
        }
      ]
    },
    {
      "id": "2",
      "parentId": null,
      "title": "Implement product catalog",
      "description": "Product listing, filtering, search, and admin CRUD as defined in features/product-catalog.md",
      "status": "planned",
      "type": "feature",
      "priority": "high",
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multiple endpoints, Meilisearch integration, admin features.",
        "recommendedSubtasks": 4
      },
      "dependencies": [],
      "tags": ["products", "search", "meilisearch", "api"],
      "subtasks": [
        {
          "id": "2.1",
          "parentId": "2",
          "title": "Create products database migration and model",
          "description": "Based on schema in database/schema.md",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 1, "scale": "XS" },
          "subtasks": []
        },
        {
          "id": "2.2",
          "parentId": "2",
          "title": "Implement product listing API",
          "description": "GET /api/products with pagination and category/price filtering.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["2.1"],
          "subtasks": []
        },
        {
          "id": "2.3",
          "parentId": "2",
          "title": "Integrate Meilisearch for product search",
          "description": "GET /api/products/search endpoint with full-text search.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": { "score": 3, "scale": "M" },
          "dependencies": ["2.1"],
          "subtasks": []
        },
        {
          "id": "2.4",
          "parentId": "2",
          "title": "Implement admin product CRUD",
          "description": "Admin endpoints for create, update, delete products.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["2.1"],
          "subtasks": []
        }
      ]
    },
    {
      "id": "3",
      "parentId": null,
      "title": "Implement shopping cart and checkout",
      "description": "Cart management and Stripe checkout as defined in features/shopping-cart.md",
      "status": "planned",
      "type": "feature",
      "priority": "high",
      "complexity": {
        "score": 5,
        "scale": "XL",
        "reasoning": "Cart state management, guest/user carts, payment integration, order flow.",
        "recommendedSubtasks": 5
      },
      "dependencies": ["1", "2"],
      "tags": ["cart", "checkout", "stripe", "payments"],
      "subtasks": [
        {
          "id": "3.1",
          "parentId": "3",
          "title": "Create cart items migration and model",
          "description": "Based on schema in database/schema.md",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 1, "scale": "XS" },
          "subtasks": []
        },
        {
          "id": "3.2",
          "parentId": "3",
          "title": "Implement cart CRUD API",
          "description": "GET/POST/PUT/DELETE /api/cart/items endpoints.",
          "status": "planned",
          "type": "feature",
          "priority": "high",
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["3.1"],
          "subtasks": []
        },
        {
          "id": "3.3",
          "parentId": "3",
          "title": "Implement guest cart with session storage",
          "description": "Cart persistence for non-authenticated users.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": { "score": 2, "scale": "S" },
          "subtasks": []
        },
        {
          "id": "3.4",
          "parentId": "3",
          "title": "Integrate Stripe payment",
          "description": "POST /api/cart/checkout with Stripe payment intent.",
          "status": "planned",
          "type": "feature",
          "priority": "critical",
          "complexity": { "score": 4, "scale": "L" },
          "dependencies": ["3.2"],
          "subtasks": []
        },
        {
          "id": "3.5",
          "parentId": "3",
          "title": "Implement order confirmation email",
          "description": "Send email notification after successful checkout.",
          "status": "planned",
          "type": "feature",
          "priority": "medium",
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": ["3.4"],
          "subtasks": []
        }
      ]
    },
    {
      "id": "4",
      "parentId": null,
      "title": "Set up infrastructure and architecture",
      "description": "Database, cache, and search infrastructure as defined in architecture.md",
      "status": "planned",
      "type": "chore",
      "priority": "critical",
      "complexity": {
        "score": 2,
        "scale": "S",
        "reasoning": "Standard Laravel setup with additional services."
      },
      "dependencies": [],
      "tags": ["infrastructure", "devops"],
      "subtasks": [
        {
          "id": "4.1",
          "parentId": "4",
          "title": "Configure PostgreSQL database",
          "description": "Set up database connection and run base migrations.",
          "status": "planned",
          "type": "chore",
          "priority": "critical",
          "complexity": { "score": 1, "scale": "XS" },
          "subtasks": []
        },
        {
          "id": "4.2",
          "parentId": "4",
          "title": "Configure Redis cache",
          "description": "Set up Redis for caching and session storage.",
          "status": "planned",
          "type": "chore",
          "priority": "high",
          "complexity": { "score": 1, "scale": "XS" },
          "subtasks": []
        },
        {
          "id": "4.3",
          "parentId": "4",
          "title": "Set up Meilisearch",
          "description": "Configure Meilisearch for product search indexing.",
          "status": "planned",
          "type": "chore",
          "priority": "medium",
          "complexity": { "score": 2, "scale": "S" },
          "subtasks": []
        }
      ]
    }
  ]
}
```

---

## Key Points for Folder Input

### ✔ Cross-File Dependencies
- Tasks reference content from multiple files (e.g., task 3.1 references `database/schema.md`)
- Dependencies are identified across feature boundaries (e.g., cart depends on auth and products)

### ✔ Folder Structure Informs Organization
- Features from `features/` folder become top-level tasks
- Infrastructure from `architecture.md` becomes its own epic
- API endpoints from `api/endpoints.md` are distributed to relevant features

### ✔ Aggregation Preserves Context
- Each file's origin is tracked in the aggregated content
- Cross-references between files are resolved during task generation

