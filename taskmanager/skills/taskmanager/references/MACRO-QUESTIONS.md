# Macro Architectural Question Bank

This reference defines framework-specific questions the plan command asks during Phase 3 (Macro Architectural Questions). The AI selects relevant questions based on the detected tech stack from Phase 2, skipping any already answered by the PRD or existing memories.

Questions are asked via **AskUserQuestion** (batched, 1-4 per call). Each answer is stored as a memory with the specified kind and importance.

---

## General (always relevant)

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| What is the deployment target (cloud provider, PaaS, self-hosted, etc.)? | Always | architecture | 5 |
| Is there an existing CI/CD pipeline, or should one be designed? | Always | architecture | 4 |
| What monitoring/observability approach is expected (logs, metrics, tracing)? | Always | architecture | 4 |
| What environments are needed (dev, staging, production)? | Always | convention | 3 |
| Are there budget or infrastructure constraints that affect technology choices? | When scope is large | constraint | 4 |

---

## Laravel / PHP

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| Filament panel structure: single admin panel, multi-panel (admin + customer), or guest-accessible panel? | When Filament detected | architecture | 5 |
| Queue driver preference (Redis, database, SQS, sync for dev)? | When Laravel detected | architecture | 4 |
| Broadcasting driver preference (Reverb, Pusher, Ably, none)? | When real-time features mentioned | architecture | 4 |
| File storage driver (local, S3, R2, custom)? | When file uploads mentioned | architecture | 4 |
| Mail driver (SMTP, Mailgun, SES, Resend, log for dev)? | When email features mentioned | architecture | 3 |
| Session driver (database, Redis, file, cookie)? | When auth mentioned | architecture | 3 |
| Which Laravel version and PHP version are targeted? | When not specified in PRD | constraint | 4 |
| Multi-tenancy approach (single DB with tenant_id, separate DBs, subdomain-based)? | When multi-tenant mentioned | architecture | 5 |

---

## Filament

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| Filament version (v4 or v5)? | When Filament detected and version unclear | constraint | 5 |
| Should resources use soft deletes with trash/restore functionality? | When CRUD resources planned | convention | 3 |
| Is tenant-aware Filament needed (panel per tenant)? | When multi-tenancy mentioned | architecture | 5 |
| Should forms use wizard/step layout for complex creation flows? | When complex forms mentioned | convention | 3 |

---

## React / Vue / Angular (Frontend SPA)

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| SPA, SSR (Next.js/Nuxt), or hybrid rendering? | When React/Vue/Angular detected | architecture | 5 |
| State management approach (Redux, Zustand, Pinia, Context, signals)? | When frontend detected | architecture | 4 |
| Component library preference (shadcn/ui, MUI, Ant Design, Headless UI, custom)? | When UI mentioned | architecture | 4 |
| Form handling library (React Hook Form, Formik, VeeValidate, native)? | When forms mentioned | convention | 3 |
| Routing approach (file-based, manual, nested layouts)? | When multi-page app | architecture | 3 |

---

## API Design

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| REST vs GraphQL vs tRPC? | When API mentioned | architecture | 5 |
| API versioning strategy (URL path, header, none)? | When public API | convention | 4 |
| Authentication method for API (session, JWT, API keys, OAuth2)? | When API auth needed | architecture | 5 |
| Rate limiting strategy (per-user, per-IP, tiered)? | When public-facing API | architecture | 4 |
| API documentation approach (OpenAPI/Swagger, auto-generated, manual)? | When API planned | convention | 3 |

---

## Database

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| Database engine (PostgreSQL, MySQL, SQLite, MongoDB)? | When not specified | architecture | 5 |
| Are read replicas or connection pooling needed? | When high-traffic expected | architecture | 4 |
| Migration strategy (framework migrations, raw SQL, schema-first)? | When DB work planned | convention | 3 |
| Seeding approach (factories, fixtures, static seeds)? | When testing mentioned | convention | 3 |
| Soft deletes globally or per-model? | When data retention mentioned | convention | 3 |

---

## Authentication & Authorization

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| Auth approach: session-based, JWT, OAuth2 provider, or third-party (Auth0, Clerk)? | When auth mentioned | architecture | 5 |
| Role/permission system (Spatie, Bouncer, custom, policy-based)? | When roles/permissions mentioned | architecture | 5 |
| Multi-factor authentication required? | When security is high priority | architecture | 4 |
| Social login providers needed (Google, GitHub, Facebook, Apple)? | When OAuth/social login mentioned | architecture | 3 |

---

## Frontend / CSS / UX

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| CSS framework (Tailwind, Bootstrap, vanilla, CSS-in-JS)? | When frontend detected | convention | 4 |
| Responsive strategy (mobile-first, desktop-first, adaptive)? | When UI mentioned | convention | 3 |
| Internationalization (i18n) needed? If yes, which languages? | When mentioned or global audience | architecture | 4 |
| Dark mode support required? | When UI/theming mentioned | convention | 3 |
| Accessibility level target (WCAG 2.1 A, AA, AAA)? | When accessibility mentioned | constraint | 4 |

---

## DevOps / Infrastructure

| Question | When to Ask | Memory Kind | Importance |
|----------|-------------|-------------|------------|
| Containerization approach (Docker, Podman, none)? | When deployment discussed | architecture | 4 |
| Container orchestration (Kubernetes, Docker Compose, ECS, none)? | When scaling discussed | architecture | 4 |
| CDN or asset pipeline (Vite, Webpack, CDN provider)? | When frontend detected | convention | 3 |
| Secret management approach (env files, vault, cloud secrets manager)? | When security discussed | architecture | 4 |

---

## Usage Notes

1. **Selection is AI-driven**: The plan command uses judgment to select 4-12 relevant questions based on the detected tech stack. Not all questions in a category are asked.

2. **Skip already-answered**: Questions whose answers are evident from the PRD content or existing memories (kind: architecture/decision, importance >= 4) are skipped.

3. **Batching**: Questions are presented via AskUserQuestion in batches of 1-4 per call to avoid overwhelming the user.

4. **Memory storage**: Each answer becomes a memory with:
   - `source_type`: `'user'`
   - `source_via`: `'taskmanager:plan:macro-questions'`
   - `auto_updatable`: `0` (user-provided)
   - `confidence`: `1.0` (direct user answer)
   - `importance`: As specified in the table above
   - `kind`: As specified in the table above

5. **Decision linking**: Answers are also stored in `plan_analyses.decisions` as:
   ```json
   {"question": "...", "answer": "...", "rationale": "User decision", "memory_id": "M-XXXX"}
   ```
