# Documentation Patterns Reference

## Documentation Types

| Type | Purpose | When to Use |
|------|---------|-------------|
| **README** | Project overview, quick start | Every project root |
| **API Reference** | Endpoint specs, request/response | REST/GraphQL APIs |
| **Architecture** | System design, ADRs | Complex systems, major decisions |
| **User Guide** | Step-by-step instructions | End-user-facing features |
| **Developer Guide** | Contributing, local setup | Open source, team onboarding |
| **Model/Schema** | Data structures, relationships | Database-backed apps |
| **Component** | Props, events, usage | UI libraries, component systems |
| **Changelog** | Version history, breaking changes | Published packages, releases |
| **Configuration** | Environment variables, options | Configurable apps, libraries |

## File Organization by Project Type

### Laravel Projects
```
docs/
├── README.md
├── api/
│   ├── authentication.md
│   ├── users.md
│   └── [resource].md
├── models/
│   ├── user.md
│   └── [model].md
├── guides/
│   ├── installation.md
│   ├── deployment.md
│   └── [topic].md
├── architecture/
│   ├── overview.md
│   └── decisions/
│       └── [ADR-001-title].md
└── development/
    ├── contributing.md
    ├── testing.md
    └── coding-standards.md
```

Key files to document:
- Routes (`routes/api.php`, `routes/web.php`) → `docs/api/`
- Models (`app/Models/`) → `docs/models/`
- Config files (`config/`) → `docs/configuration.md`
- Migrations → Referenced in model docs

### Node.js Projects
```
docs/
├── README.md
├── api/
│   ├── endpoints.md
│   └── [resource].md
├── guides/
│   ├── getting-started.md
│   └── [topic].md
├── architecture/
│   └── overview.md
└── development/
    ├── contributing.md
    └── testing.md
```

Key files to document:
- Route handlers → `docs/api/`
- Middleware → `docs/architecture/`
- Package exports → `docs/api/`
- Environment variables → `docs/configuration.md`

### React/Vue/Frontend Projects
```
docs/
├── README.md
├── components/
│   ├── index.md
│   └── [ComponentName].md
├── guides/
│   ├── getting-started.md
│   ├── theming.md
│   └── [topic].md
├── architecture/
│   ├── state-management.md
│   └── routing.md
└── development/
    ├── contributing.md
    └── testing.md
```

Key files to document:
- Components (`src/components/`) → `docs/components/`
- Hooks/composables → `docs/api/`
- Store/state → `docs/architecture/`
- Theme/config → `docs/guides/theming.md`

## Markdown Best Practices

### Headers
- Use ATX-style (`#`) exclusively
- Never skip levels (h1 → h3 without h2)
- One h1 per file (the document title)
- Use sentence case for headers

### Code Blocks
- Always specify language: ` ```php `, ` ```bash `, ` ```json `
- Include complete, runnable examples
- Show imports and setup needed
- Add comments for non-obvious lines
- Show expected output when helpful

### Links
- Use relative paths for internal links: `[Models](../models/user.md)`
- Use reference-style links for repeated URLs
- Check links during validation

### Lists
- Use `-` for unordered lists
- Use `1.` for ordered lists (auto-numbered)
- Indent nested items with 2 or 4 spaces consistently

### Tables
- Use for structured comparisons or reference data
- Align columns for readability in source
- Keep cell content concise

### Line Length
- One sentence per line (improves git diffs)
- Exception: tables and code blocks

## Template Selection Guide

| Scenario | Template | Key Sections |
|----------|----------|--------------|
| New REST endpoint | `api-endpoint` | Method, URL, params, request body, response, errors, example |
| New database model | `model` | Properties, types, relationships, scopes, accessors, validations |
| New UI component | `component` | Props, events, slots, usage examples, screenshots |
| New service class | `service` | Purpose, methods, dependencies, configuration, usage |
| Project README | `readme` | Description, features, install, quick start, config, license |
| How-to article | `guide` | Prerequisites, steps, verification, troubleshooting |
| Design decision | `architecture` | Context, decision, consequences, alternatives considered |
| New release | `changelog` | Version, date, added, changed, deprecated, removed, fixed |

## Drift Detection Patterns

### What to Compare for Each Artifact Type

#### API Endpoints
| Documentation Claim | Code Source |
|-------------------|------------|
| Route path | `routes/*.php`, express routes, etc. |
| HTTP method | Route definition |
| Request parameters | Controller validation rules, request classes |
| Request body schema | FormRequest rules, validation middleware |
| Response format | Controller return statements |
| Authentication | Middleware stack, guards |
| Rate limiting | Middleware, throttle config |

#### Models / Entities
| Documentation Claim | Code Source |
|-------------------|------------|
| Properties / columns | Migration files, `$fillable`, `$casts` |
| Relationships | Relationship methods on model class |
| Scopes | `scope*` methods |
| Accessors / mutators | `get*Attribute`, `set*Attribute`, `Attribute::make` |
| Validation rules | FormRequest classes, `$rules` |
| Events / observers | Observer classes, `$dispatchesEvents` |

#### Components (React / Vue / Livewire)
| Documentation Claim | Code Source |
|-------------------|------------|
| Props / parameters | Component class properties, `defineProps` |
| Events emitted | `$dispatch`, `$emit`, `defineEmits` |
| Slots / children | Template `<slot>` elements, `{children}` |
| Public methods | Exposed methods, Livewire actions |
| State / data | Component state, `data()`, `useState` |

#### Configuration
| Documentation Claim | Code Source |
|-------------------|------------|
| Environment variables | `env()` calls, `.env.example` |
| Config options | `config/*.php`, config files |
| Feature flags | Feature check calls, gate definitions |
| Default values | Config defaults, `.env.example` values |

### Common Drift Causes
1. **Code refactored, docs not updated** - Most frequent. Catch with regular sync checks.
2. **Feature removed but docs remain** - Results in "Not Implemented" status.
3. **New feature added without docs** - Results in "Undocumented" status.
4. **Parameter renamed/retyped** - Results in "Partial" match with parameter mismatch.
5. **Response format changed** - Results in "Partial" match with schema difference.
