---
description: Writing domain support for taskmanager - books, articles, documentation with word count tracking and writing stage pipeline
allowed-tools: Read, Write, Edit, Glob, Grep
---

# TaskManager Writing Domain Skill

Extends the core taskmanager with writing-specific features for books, articles, documentation, and fiction.

---

## Writing Task Fields

A task may declare these writing-specific columns (all defined in `schema.sql`):

- `domain = "writing"` — Marks the task as a writing task (default is `"software"`)
- `writing_type` — e.g. `"book"`, `"article"`, `"short-story"`, `"documentation"`, `"blog-post"`, `"whitepaper"`
- `content_unit` — e.g. `"chapter"`, `"section"`, `"scene"`
- `writing_stage` — e.g. `"outline"`, `"draft"`, `"edit"` (see pipeline below)
- `target_word_count` / `current_word_count` — Word count tracking

If `domain` is omitted, treat it as `"software"` by default.

---

## Decomposing Writing Projects into Tasks

When the input PRD describes a book, article, or other writing work, decompose it hierarchically using writing-aware structure.

### Book (`writing_type = 'book'`)

Typical top-level tasks:

- Define scope & audience
- High-level outline of the whole book
- Research (if applicable)
- Draft chapters / parts
- Revision passes
- Line editing / copyediting
- Proofreading
- Publication & post-publication tasks (metadata, marketing, etc.)

Example subtree for chapters:

- `[P] Draft all chapters`
  - `[C] Draft Chapter 1` (content_unit = 'chapter')
  - `[C] Draft Chapter 2`
  - ...
- `[P] Revise all chapters`
  - `[C] Revise Chapter 1`
  - ...

### Article (`writing_type = 'article'` / `'blog-post'` / `'whitepaper'`)

Typical structure:

- Define key message and audience
- Outline article sections
- Research sources
- Draft sections (intro, body, conclusion)
- Technical review (for technical pieces)
- Edit / copyedit
- Proofread
- Prepare assets (diagrams, code samples)
- Publish & distribution

### Rules

All standard taskmanager rules still apply:

- Hierarchical depth
- Complexity (`complexity_scale`, `complexity_score`)
- Priority
- Status propagation
- Time estimation (`estimate_seconds`)

---

## Time Estimation for Writing Tasks

`estimate_seconds` is still the canonical estimate field. Base the value on:

- `complexity_scale` / `complexity_score`
- `target_word_count` (when available)
- `writing_stage` (draft vs edit vs research)
- Notes in `description` / `details`

### Heuristics (guidelines, not strict rules)

- **Drafting**: Base on target words; assume 250-500 draft words/hour for deep technical or complex fiction, higher for lighter content.
  - Example: 2000-word technical article draft → 2000 / 350 ≈ 5.7h → ~6h (21,600 seconds)
- **Revision / rewrite**: Often 50-70% of the drafting time for the same word count.
- **Editing / copyediting / proofreading**: Quicker per word; often 30-50% of the drafting time.
- **Research-heavy tasks**: Can dominate time; consider research depth (light, medium, deep) and inflate estimates accordingly.

Convert all final estimates to **seconds** in `estimate_seconds`.

As with software tasks:

- Leaf writing tasks MUST end with a non-null `estimate_seconds` once planning is complete.
- Parent writing tasks MUST get their `estimate_seconds` from the sum of their direct children.

---

## Writing Stage Pipeline

The `writing_stage` column tracks where a task is in the writing pipeline:

1. `idea`
2. `outline`
3. `research`
4. `draft`
5. `rewrite`
6. `edit`
7. `copyedit`
8. `proofread`
9. `ready-to-publish`
10. `published`

### `writing_stage` vs `status`

- Use `status` to reflect **execution state** (planned vs in-progress vs done).
- Use `writing_stage` to reflect **where in the writing pipeline** the task is.

Examples:

- "Draft Chapter 3": `status = "in-progress"`, `writing_stage = "draft"`
- "Revise Chapter 3 after beta reader feedback": `status = "planned"`, `writing_stage = "rewrite"`

Status propagation rules for parents are **domain-agnostic** and derived from children. `writing_stage` is **per-task** and not auto-propagated.

---

## Dependencies in Writing Projects

Use `dependencies` for ordering constraints, for example:

- "Draft Chapter 3" depends on "Outline Chapter 3".
- "Global structure revision" depends on all chapter drafts being done.
- "Copyedit full manuscript" depends on major revisions being done.

These dependencies directly influence the critical path calculation in the dashboard.
