# PRD Ingestion Examples for MWGuerra Task Manager

These examples show how to convert `.taskmanager/docs/prd.md` into a hierarchical, level-by-level expanded set of tasks in the SQLite database (`.taskmanager/taskmanager.db`), fully compliant with the MWGuerra Task Manager v4.0.0 schema and the Task Manager Skill instructions. (See SKILL.md for mandatory step-by-step expansion logic.)

> **Note:** While data is stored in SQLite, the examples below show JSON format for readability. The conceptual task structure remains the same - tasks are inserted into the `tasks` table with `parent_id` relationships, milestones into the `milestones` table, and analysis artifacts into the `plan_analyses` table.

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

# Expected Task Structure (Schema-Compliant)

When ingesting this PRD, the `plan` command produces milestones and tasks via the 6-phase planning flow:

1. **Phase 1**: Input & Memory Load
2. **Phase 2**: PRD Analysis (tech stack detection, risks, assumptions)
3. **Phase 3**: Macro Architectural Questions (if ambiguities found)
4. **Phase 4**: Milestone Definition (MoSCoW -> milestones)
5. **Phase 5**: Task Generation (level-by-level with acceptance criteria)
6. **Phase 6**: Insert & Summary

Below is the resulting structure.

```jsonc
{
  "version": "4.0.0",
  "project": {
    "id": "likker-pcast",
    "name": "Likker PCAST",
    "description": "Bandwidth monitoring and real-time features."
  },
  "milestones": [
    {
      "id": "MS-001",
      "title": "MVP - Real-time Bandwidth Widget",
      "description": "Core bandwidth monitoring with API, real-time updates, and warning state",
      "status": "planned",
      "phaseOrder": 1,
      "acceptanceCriteria": [
        "Widget displays current bandwidth updating every 5 seconds",
        "5-minute chart renders correctly",
        "Warning state triggers at 80% capacity"
      ]
    }
  ],
  "tasks": [
    {
      "id": "1",
      "parentId": null,
      "title": "Implement real-time bandwidth widget for Likker PCAST",
      "description": "Top-level epic covering backend, frontend, realtime streaming, warnings, persistence, and tests.",
      "status": "planned",
      "type": "feature",
      "priority": "high",
      "milestoneId": "MS-001",
      "moscow": "must",
      "businessValue": 5,
      "acceptanceCriteria": [
        "Widget displays current Mbps with <=5s update frequency",
        "5-minute rolling chart is visible and accurate",
        "Warning state triggers at >80% configured capacity",
        "Historical data persists for reporting"
      ],
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multi-system integration: backend, realtime updates, frontend visualization, persistence.",
        "recommendedSubtasks": 6,
        "expansionPrompt": "Expand into backend, UI, realtime, persistence, thresholds, and testing subtasks."
      },
      "dependencies": [],
      "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": [
            "Telemetry data source documented",
            "80% capacity threshold defined with units"
          ],
          "complexity": {
            "score": 1,
            "scale": "XS",
            "reasoning": "Simple analysis and definitions.",
            "recommendedSubtasks": 0
          },
          "dependencies": [],
          "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "GET /api/bandwidth returns current Mbps and 5-min history",
            "Response time under 200ms",
            "Proper error handling for missing telemetry data"
          ],
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "Requires data access, formatting, and integration with frontend.",
            "recommendedSubtasks": 3,
            "expansionPrompt": "Split into endpoint definition, data retrieval, and response formatting."
          },
          "dependencies": ["1.1"],
          "dependencyTypes": { "1.1": "hard" },
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
              "milestoneId": "MS-001",
              "moscow": "must",
              "businessValue": 4,
              "acceptanceCriteria": ["API contract documented with request/response schemas"],
              "complexity": {
                "score": 1,
                "scale": "XS"
              },
              "dependencies": [],
              "dependencyTypes": {},
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
              "milestoneId": "MS-001",
              "moscow": "must",
              "businessValue": 5,
              "acceptanceCriteria": [
                "Reads from telemetry source successfully",
                "5-minute rolling window computed correctly"
              ],
              "complexity": { "score": 2, "scale": "S" },
              "dependencies": ["1.2.1"],
              "dependencyTypes": { "1.2.1": "hard" },
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
              "milestoneId": "MS-001",
              "moscow": "must",
              "businessValue": 3,
              "acceptanceCriteria": ["Response matches documented API contract"],
              "complexity": { "score": 1, "scale": "XS" },
              "dependencies": ["1.2.2"],
              "dependencyTypes": { "1.2.2": "hard" },
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "WebSocket channel broadcasts bandwidth data every 5s",
            "Clients reconnect automatically on disconnect"
          ],
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "Requires pub/sub, client connections, and fallback handling.",
            "recommendedSubtasks": 2
          },
          "dependencies": ["1.2"],
          "dependencyTypes": { "1.2": "hard" },
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "Widget renders current Mbps prominently",
            "5-minute chart updates in real-time",
            "Responsive on mobile and desktop"
          ],
          "complexity": {
            "score": 3,
            "scale": "M",
            "reasoning": "UI rendering, state management, chart integration.",
            "recommendedSubtasks": 3
          },
          "dependencies": ["1.2", "1.3"],
          "dependencyTypes": { "1.2": "hard", "1.3": "soft" },
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": [
            "Visual warning appears when usage >80%",
            "Warning clears when usage drops below 80%"
          ],
          "complexity": { "score": 1, "scale": "XS" },
          "tags": ["frontend"],
          "dependencies": ["1.4"],
          "dependencyTypes": { "1.4": "hard" },
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
          "milestoneId": "MS-001",
          "moscow": "should",
          "businessValue": 3,
          "acceptanceCriteria": [
            "Historical data stored in Redis with configurable retention",
            "Data available for external reporting queries"
          ],
          "complexity": {
            "score": 2,
            "scale": "S"
          },
          "tags": ["backend", "redis"],
          "dependencies": ["1.2"],
          "dependencyTypes": { "1.2": "hard" },
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
          "milestoneId": "MS-001",
          "moscow": "should",
          "businessValue": 3,
          "acceptanceCriteria": [
            "API endpoint tests with >80% coverage",
            "WebSocket integration test passes",
            "Basic health check endpoint for monitoring"
          ],
          "complexity": {
            "score": 2,
            "scale": "S"
          },
          "tags": ["tests", "monitoring"],
          "dependencies": ["1.2", "1.3", "1.4"],
          "dependencyTypes": { "1.2": "hard", "1.3": "hard", "1.4": "soft" },
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

### Skill Compliance (Level-by-Level)

* Top-level task -> many Level 2 tasks -> Level 3 subtasks only where needed
* Complexity-driven expansion aligns with the Skill instructions

### Tasks Schema Compliance (v4.0.0)

* `status` uses allowed enum values
* `complexity` uses required fields: `score`, `scale`, `reasoning`, `recommendedSubtasks`, `expansionPrompt`
* `milestoneId` references a valid milestone from the `milestones` array
* `acceptanceCriteria` is a JSON array of strings (product view, distinct from `testStrategy`)
* `moscow` is one of: `must`, `should`, `could`, `wont`
* `businessValue` is an integer 1-5 (1=low, 5=critical)
* `dependencyTypes` maps dependency IDs to `hard`, `soft`, or `informational`
* All IDs match regex: `^[0-9]+(\.[0-9]+)*$`

### Acceptance Criteria vs Test Strategy

* `acceptanceCriteria` = **what** "done" means (product perspective): user-visible outcomes, measurable conditions
* `testStrategy` = **how** to verify (engineering perspective): frameworks, test types, coverage approach

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

## Expected Task Structure from Folder Input

```jsonc
{
  "version": "4.0.0",
  "project": {
    "id": "e-commerce-platform",
    "name": "E-Commerce Platform",
    "description": "Modern e-commerce platform with user auth, product catalog, and shopping cart."
  },
  "milestones": [
    {
      "id": "MS-001",
      "title": "Infrastructure & Auth",
      "description": "Database, cache, search setup and authentication system",
      "status": "planned",
      "phaseOrder": 1
    },
    {
      "id": "MS-002",
      "title": "Core Features",
      "description": "Product catalog with search and filtering",
      "status": "planned",
      "phaseOrder": 2
    },
    {
      "id": "MS-003",
      "title": "Cart & Checkout",
      "description": "Shopping cart, payment integration, and order flow",
      "status": "planned",
      "phaseOrder": 3
    }
  ],
  "tasks": [
    {
      "id": "1",
      "parentId": null,
      "title": "Implement user authentication system",
      "description": "Complete auth system with email/password and OAuth support as defined in features/user-auth.md",
      "status": "planned",
      "type": "feature",
      "priority": "critical",
      "milestoneId": "MS-001",
      "moscow": "must",
      "businessValue": 5,
      "acceptanceCriteria": [
        "Users can register and log in with email/password",
        "OAuth login works with Google and GitHub",
        "Password reset flow sends email and allows reset",
        "Rate limiting enforced on auth endpoints"
      ],
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multiple auth methods, security requirements, and API endpoints to implement.",
        "recommendedSubtasks": 5,
        "expansionPrompt": "Split into registration, login, OAuth, password reset, and session management."
      },
      "dependencies": [],
      "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "Valid registration creates user and returns JWT",
            "Duplicate email returns 409",
            "Invalid input returns 422 with field errors"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": [],
          "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "Valid credentials return JWT token",
            "Invalid credentials return 401",
            "Remember-me extends token TTL"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["1.1"],
          "dependencyTypes": { "1.1": "hard" },
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
          "milestoneId": "MS-001",
          "moscow": "should",
          "businessValue": 4,
          "acceptanceCriteria": [
            "Google OAuth redirects and creates/links user account",
            "GitHub OAuth redirects and creates/links user account",
            "Existing email accounts can link OAuth providers"
          ],
          "complexity": { "score": 3, "scale": "M" },
          "dependencies": ["1.1"],
          "dependencyTypes": { "1.1": "hard" },
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": [
            "Reset request sends email with valid token",
            "Token expires after 60 minutes",
            "Valid token allows password change"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["1.1"],
          "dependencyTypes": { "1.1": "hard" },
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
      "milestoneId": "MS-002",
      "moscow": "must",
      "businessValue": 5,
      "acceptanceCriteria": [
        "Products listed with pagination",
        "Category and price filters work",
        "Full-text search returns relevant results",
        "Admin can create, update, delete products"
      ],
      "complexity": {
        "score": 4,
        "scale": "L",
        "reasoning": "Multiple endpoints, Meilisearch integration, admin features.",
        "recommendedSubtasks": 4
      },
      "dependencies": [],
      "dependencyTypes": {},
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
          "milestoneId": "MS-002",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": ["Migration creates products table with all columns from schema"],
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": [],
          "dependencyTypes": {},
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
          "milestoneId": "MS-002",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "Pagination returns correct page size and total count",
            "Category filter narrows results correctly",
            "Price range filter works with min/max params"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["2.1"],
          "dependencyTypes": { "2.1": "hard" },
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
          "milestoneId": "MS-002",
          "moscow": "should",
          "businessValue": 4,
          "acceptanceCriteria": [
            "Search returns relevant products for keyword queries",
            "Search results include relevance ranking"
          ],
          "complexity": { "score": 3, "scale": "M" },
          "dependencies": ["2.1"],
          "dependencyTypes": { "2.1": "hard" },
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
          "milestoneId": "MS-002",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": [
            "Admin can create product with all required fields",
            "Admin can update product details",
            "Admin can soft-delete product"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["2.1", "1"],
          "dependencyTypes": { "2.1": "hard", "1": "soft" },
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
      "milestoneId": "MS-003",
      "moscow": "must",
      "businessValue": 5,
      "acceptanceCriteria": [
        "Users can add/remove/update cart items",
        "Guest cart works with session storage",
        "Checkout completes Stripe payment",
        "Order confirmation email sent"
      ],
      "complexity": {
        "score": 5,
        "scale": "XL",
        "reasoning": "Cart state management, guest/user carts, payment integration, order flow.",
        "recommendedSubtasks": 5
      },
      "dependencies": ["1", "2"],
      "dependencyTypes": { "1": "hard", "2": "soft" },
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
          "milestoneId": "MS-003",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": ["Migration creates cart_items table with FK to users and products"],
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": [],
          "dependencyTypes": {},
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
          "milestoneId": "MS-003",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "Add item to cart with quantity",
            "Update item quantity",
            "Remove item from cart",
            "Get cart returns all items with totals"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["3.1"],
          "dependencyTypes": { "3.1": "hard" },
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
          "milestoneId": "MS-003",
          "moscow": "should",
          "businessValue": 3,
          "acceptanceCriteria": [
            "Guest users can add items to cart",
            "Cart persists across page reloads via session",
            "Guest cart merges with user cart on login"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": ["3.2"],
          "dependencyTypes": { "3.2": "hard" },
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
          "milestoneId": "MS-003",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": [
            "Checkout creates Stripe payment intent",
            "Successful payment creates order record",
            "Failed payment returns error without creating order"
          ],
          "complexity": { "score": 4, "scale": "L" },
          "dependencies": ["3.2"],
          "dependencyTypes": { "3.2": "hard" },
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
          "milestoneId": "MS-003",
          "moscow": "should",
          "businessValue": 3,
          "acceptanceCriteria": [
            "Email sent within 30 seconds of successful payment",
            "Email contains order summary and payment receipt"
          ],
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": ["3.4"],
          "dependencyTypes": { "3.4": "hard" },
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
      "milestoneId": "MS-001",
      "moscow": "must",
      "businessValue": 5,
      "acceptanceCriteria": [
        "PostgreSQL database running and accessible",
        "Redis cache configured",
        "Meilisearch running and indexable"
      ],
      "complexity": {
        "score": 2,
        "scale": "S",
        "reasoning": "Standard Laravel setup with additional services."
      },
      "dependencies": [],
      "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 5,
          "acceptanceCriteria": ["Database connection works", "Base migrations run successfully"],
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": [],
          "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": ["Redis connection works", "Cache driver set to Redis"],
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": [],
          "dependencyTypes": {},
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
          "milestoneId": "MS-001",
          "moscow": "should",
          "businessValue": 3,
          "acceptanceCriteria": ["Meilisearch container running", "Scout configured with Meilisearch driver"],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": [],
          "dependencyTypes": {},
          "subtasks": []
        }
      ]
    },

    // Cross-cutting concerns epic generated from Phase 2 analysis
    {
      "id": "5",
      "parentId": null,
      "title": "Cross-cutting concerns",
      "description": "Shared infrastructure concerns identified during PRD analysis (error handling, security, monitoring).",
      "status": "planned",
      "type": "chore",
      "priority": "high",
      "milestoneId": "MS-001",
      "moscow": "must",
      "businessValue": 4,
      "acceptanceCriteria": [
        "Consistent error handling across all API endpoints",
        "Security headers and CORS configured",
        "Request logging and monitoring in place"
      ],
      "complexity": { "score": 3, "scale": "M" },
      "dependencies": ["4"],
      "dependencyTypes": { "4": "soft" },
      "tags": ["cross-cutting", "security", "monitoring"],
      "subtasks": [
        {
          "id": "5.1",
          "parentId": "5",
          "title": "Implement API error handling strategy",
          "description": "Consistent error response format, exception handler, and validation error mapping.",
          "status": "planned",
          "type": "chore",
          "priority": "high",
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": [
            "All API errors return JSON with code, message, and details",
            "Validation errors map to field-level messages"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": [],
          "dependencyTypes": {},
          "subtasks": []
        },
        {
          "id": "5.2",
          "parentId": "5",
          "title": "Configure security headers and CORS",
          "description": "Set up CSRF, CORS, security headers middleware.",
          "status": "planned",
          "type": "chore",
          "priority": "high",
          "milestoneId": "MS-001",
          "moscow": "must",
          "businessValue": 4,
          "acceptanceCriteria": [
            "CORS allows frontend origin only",
            "Security headers (X-Frame-Options, CSP) set"
          ],
          "complexity": { "score": 1, "scale": "XS" },
          "dependencies": [],
          "dependencyTypes": {},
          "subtasks": []
        },
        {
          "id": "5.3",
          "parentId": "5",
          "title": "Set up request logging and monitoring",
          "description": "Laravel Telescope for development, structured logging for production.",
          "status": "planned",
          "type": "chore",
          "priority": "medium",
          "milestoneId": "MS-001",
          "moscow": "should",
          "businessValue": 3,
          "acceptanceCriteria": [
            "Telescope installed and configured for dev",
            "Structured JSON logging for production"
          ],
          "complexity": { "score": 2, "scale": "S" },
          "dependencies": [],
          "dependencyTypes": {},
          "subtasks": []
        }
      ]
    }
  ]
}
```

---

## Key Points for Folder Input

### Cross-File Dependencies
- Tasks reference content from multiple files (e.g., task 3.1 references `database/schema.md`)
- Dependencies are identified across feature boundaries (e.g., cart depends on auth and products)
- `dependencyTypes` distinguish hard blocks from soft (informational) dependencies

### Folder Structure Informs Organization
- Features from `features/` folder become top-level task epics
- Infrastructure from `architecture.md` becomes its own epic
- API endpoints from `api/endpoints.md` are distributed to relevant features
- Cross-cutting concerns from analysis become a separate epic

### MoSCoW and Milestones
- MoSCoW classification drives milestone assignment (must -> MVP, should -> Enhancement)
- `milestoneId` is inherited from parent epic unless overridden at subtask level
- `businessValue` enables prioritization within the same MoSCoW tier

### Acceptance Criteria
- Every task has `acceptanceCriteria` (product view: what "done" means)
- `testStrategy` remains separate (engineering view: how to verify)
- Leaf tasks have specific, measurable criteria
- Parent tasks have summary-level criteria

---

# Example 3: Macro Analysis Phase Output

This example shows the artifacts produced by Phases 2-4 of the planning flow: **PRD Analysis**, **Macro Architectural Questions**, and **Milestone Definition**. These phases run before any tasks are generated.

## Plan Analysis Record

Stored in the `plan_analyses` table after Phase 2:

```json
{
  "id": "PA-001",
  "prd_source": "docs/e-commerce-platform/",
  "prd_hash": "sha256:a4f8e2c9b1d3...",
  "tech_stack": ["laravel", "react", "typescript", "postgresql", "redis", "meilisearch", "stripe"],
  "assumptions": [
    {
      "description": "Laravel Socialite available for OAuth integration",
      "confidence": "high",
      "impact": "medium"
    },
    {
      "description": "Meilisearch will be hosted alongside the application",
      "confidence": "medium",
      "impact": "high"
    },
    {
      "description": "Stripe is the only payment gateway needed",
      "confidence": "high",
      "impact": "high"
    }
  ],
  "risks": [
    {
      "description": "Meilisearch index sync lag could cause stale search results",
      "severity": "medium",
      "likelihood": "medium",
      "mitigation": "Use Scout queue for async indexing with near-real-time updates"
    },
    {
      "description": "Guest-to-user cart merge logic has edge cases (duplicate items, price changes)",
      "severity": "low",
      "likelihood": "high",
      "mitigation": "Define merge strategy: sum quantities, use current prices"
    }
  ],
  "ambiguities": [
    {
      "requirement": "OAuth integration (Google, GitHub)",
      "question": "Should OAuth be mandatory or optional alongside email/password?",
      "resolution": "Optional - users can register with email only"
    },
    {
      "requirement": "Persistent shopping cart",
      "question": "How long should guest carts persist?",
      "resolution": "30 days via session cookie"
    },
    {
      "requirement": "Calculate totals with tax",
      "question": "Tax calculation: flat rate or location-based?",
      "resolution": "Flat rate initially, location-based in future phase"
    }
  ],
  "nfrs": [
    { "category": "performance", "requirement": "API response under 300ms p95", "priority": "high" },
    { "category": "security", "requirement": "OWASP Top 10 compliance", "priority": "critical" },
    { "category": "accessibility", "requirement": "WCAG 2.1 AA for public pages", "priority": "medium" }
  ],
  "scope_in": "User auth, product catalog, shopping cart, Stripe checkout, admin product CRUD",
  "scope_out": "Multi-tenancy, internationalization, multiple payment gateways, mobile app, analytics dashboard",
  "cross_cutting": [
    {
      "concern": "Error handling",
      "affected_epics": ["1", "2", "3"],
      "strategy": "Consistent JSON error responses with exception handler"
    },
    {
      "concern": "Security headers and CORS",
      "affected_epics": ["1", "2", "3"],
      "strategy": "Middleware for CSRF, CORS, security headers"
    },
    {
      "concern": "Request logging",
      "affected_epics": ["1", "2", "3"],
      "strategy": "Telescope for dev, structured logging for production"
    }
  ],
  "decisions": [
    {
      "question": "Session driver?",
      "answer": "Redis",
      "rationale": "Already in stack for caching, consistent infrastructure",
      "memory_id": "M-0010"
    },
    {
      "question": "API authentication method?",
      "answer": "JWT via Laravel Sanctum",
      "rationale": "Sanctum provides SPA + API token support with minimal setup",
      "memory_id": "M-0011"
    },
    {
      "question": "Queue driver?",
      "answer": "Redis",
      "rationale": "Already in stack, sufficient for expected volume",
      "memory_id": "M-0012"
    }
  ],
  "milestone_ids": ["MS-001", "MS-002", "MS-003"]
}
```

## Macro Questions Asked (Phase 3)

The following questions were identified from ambiguities and presented to the user via `AskUserQuestion` during Phase 3:

**Batch 1:**
| Question | Answer | Memory Created |
|----------|--------|----------------|
| Should OAuth be mandatory or optional alongside email/password? | Optional | M-0013 (architecture, importance: 4) |
| Tax calculation: flat rate or location-based? | Flat rate initially | M-0014 (architecture, importance: 4) |

**Batch 2:**
| Question | Answer | Memory Created |
|----------|--------|----------------|
| How long should guest carts persist? | 30 days via session cookie | M-0015 (architecture, importance: 3) |

Questions already answered by the PRD or existing memories were skipped (e.g., tech stack choices, database engine, cache driver).

## Milestones Created (Phase 4)

Based on MoSCoW classification of identified epics:

| ID | Title | MoSCoW Source | Phase Order | Status |
|----|-------|---------------|-------------|--------|
| MS-001 | Infrastructure & Auth | must | 1 | planned |
| MS-002 | Core Features | must | 2 | planned |
| MS-003 | Cart & Checkout | must | 3 | planned |

MoSCoW assignment for each epic:
- **must**: Auth (1), Products (2), Cart (3), Infrastructure (4), Cross-cutting (5)
- **should**: OAuth subtask (1.3), Meilisearch search (2.3), Guest cart (3.3), Order email (3.5), Meilisearch setup (4.3), Monitoring (5.3)
- **could**: (none in this project)
- **wont**: Multi-tenancy, i18n, mobile app (excluded from scope)

## Decisions Stored as Memories

Each macro decision is stored in the `memories` table for reuse across tasks:

```sql
INSERT INTO memories (id, title, kind, why_important, body, source_type, source_name, source_via, auto_updatable, importance, confidence, status, scope, tags, links)
VALUES (
    'M-0010',
    'Decision: Session driver = Redis',
    'decision',
    'Affects session storage, cart persistence, and cache consistency',
    'Use Redis as session driver. Rationale: Already in stack for caching, provides consistent infrastructure for sessions and cache.',
    'agent', 'plan-analysis', 'taskmanager:plan', 1,
    5, 1.0, 'active',
    '{"tasks": ["1", "3.3"]}',
    '["redis", "session", "decision"]',
    '[]'
);
```

The `scope.tasks` field ensures this memory is automatically loaded when executing tasks 1 (auth) and 3.3 (guest cart).

## Cross-Cutting Concerns Epic

Generated as task epic 5 in the task tree (see Example 2 above). Each concern identified in `plan_analyses.cross_cutting` becomes a subtask under this epic. The epic is assigned to the earliest relevant milestone (MS-001) to ensure cross-cutting infrastructure is built before feature development.
