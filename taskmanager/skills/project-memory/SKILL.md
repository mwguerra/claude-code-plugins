---
name: project-memory
description: >
  Manage .taskmanager/memories.json for this project. Create, update, and query
  reusable project-level memories (constraints, decisions, conventions, bugfixes)
  so other agents, commands, and skills can reuse them instead of re-deriving.
allowed-tools: [Read, Write, Edit, Glob, Grep]
---

# Project Memory Skill

You manage the **project-wide memory** for this repository.

Your goal is to:

1. Keep `.taskmanager/memories.json` valid, structured, and consistent with its JSON Schema.
2. Make it easy for other agents/skills/commands to **discover relevant memories** based on the current work.
3. Capture new long-lived knowledge (constraints, decisions, bugfixes, conventions) whenever it appears.
4. Track how often memories are used so the most important ones surface naturally.

Always work relative to the project root.

---

## Files you own

- `.taskmanager/memories.json`

You MAY read the JSON Schema:

- `.taskmanager/schemas/memories.schema.json`

Do not delete or rename any `.taskmanager` files.

---

## Memory model

`.taskmanager/memories.json` is a JSON document with:

- `version` – semantic version of the memory file format.
- `project` – object with `id`, `name`, optional `description`.
- `memories` – array of memory entries.

Each **memory entry** has (see schema for exact types):

- `id` – stable ID, e.g. `"M-0001"`.
- `title` – short summary (<= 140 chars).
- `kind` – one of: `constraint`, `decision`, `bugfix`, `workaround`,
  `convention`, `architecture`, `process`, `integration`, `anti-pattern`, `other`.
- `whyImportant` – concise explanation of why this memory matters.
- `body` – detailed description / rationale / examples.
- `tags` – free-form tags, e.g. `["testing", "laravel", "pest"]`.
- `scope` – object describing where this applies:
  - `project` – project ID or name.
  - `files` – paths/globs, e.g. `["app/", "tests/Feature/"]`.
  - `tasks` – task IDs like `"1"`, `"2.3"`, `"4.1.2"`.
  - `commands` – names/paths of commands this is relevant to.
  - `agents` – names of agents this is relevant to.
  - `domains` – conceptual areas, e.g. `["testing", "architecture"]`.
- `source` – object describing who set this:
  - `type` – `"user" | "agent" | "command" | "hook" | "other"`.
  - `name` – human/agent/command identifier.
  - `via` – free-text, e.g. `"cli"`, `"tests/run-test-suite"`.
- `importance` – integer 1–5 (how critical).
- `confidence` – float 0–1 (how sure we are).
- `status` – `"active" | "deprecated" | "superseded" | "draft"`.
- `supersededBy` – optional ID of newer memory.
- `links` – optional links to docs/PRs/etc.
- `createdAt`, `updatedAt`, `lastUsedAt` – ISO timestamps.
- `useCount` – integer usage counter.

You MUST keep the file consistent with the `MWGuerraTaskManagerMemories` JSON Schema.

---

## Responsibilities

### 1. Load & validate

When you start working:

1. Use `Read` to load `.taskmanager/memories.json` if it exists.
2. If it does not exist:
   - Initialize a minimal, valid structure:
     - `version`
     - `project` (with plausible `id`/`name` from context)
     - empty `memories` array.
3. Use the schema at `.taskmanager/schemas/memories.schema.json` as the **contract**:
   - Ensure required fields exist.
   - Do not introduce extra top-level properties.
   - Fix minor inconsistencies when safe (e.g., missing `useCount` → set to 0).

If you cannot make the JSON valid without guessing, prefer to **explain the inconsistency** in comments/logs rather than silently discarding data.

### 2. Query for relevant memories

Given a natural-language description of the current work (files, task IDs, domains):

1. Parse the description into:
   - Candidate `domains` (e.g. testing, performance, security, architecture).
   - Candidate `files` / directories.
   - Task IDs, if present.
2. Filter `memories` to those where:
   - `status = "active"`, and
   - At least one of the following intersects:
     - `scope.domains` with inferred domains
     - `scope.files` with affected files/dirs
     - `scope.tasks` with relevant task IDs
     - `tags` with inferred keywords.
3. Prefer:
   - Higher `importance`.
   - Higher `useCount`.
   - More recent `lastUsedAt`.
4. Return a compact summary (bullet list) with:
   - `id`, `title`, `kind`, `whyImportant`.
   - Any key constraints or decisions that MUST be respected.

You should **never** dump the entire memory file into context unless explicitly asked; always select the smallest relevant subset.

### 3. Create a new memory

When a user or another skill makes a decision that should persist for future work:

1. Check whether a similar memory already exists (matching `kind` + overlapping `tags`/`scope`).
2. If it is truly new:
   - Generate the next ID (`M-0001`, `M-0002`, …) without reusing IDs.
   - Create a well-structured entry with:
     - Clear `title`, `kind`, `whyImportant`, `body`.
     - Scoped `tags` and `scope`.
     - Accurate `source` (`type`, `name`, `via` if known).
     - Reasonable `importance` and `confidence` (default importance 3, confidence 0.8+).
     - `status = "active"` (or `"draft"` if still tentative).
     - `createdAt` and `updatedAt` set to current time.
     - `lastUsedAt = null`, `useCount = 0`.
3. Append to the `memories` array and write the file back.

When in doubt whether something deserves a memory, ask: **“Will this decision/convention matter for future tasks?”** If yes, create a memory.

### 4. Update or supersede an existing memory

When an existing memory is refined or corrected:

1. If it’s a small correction:
   - Update the existing entry (`body`, `tags`, `scope`, etc.).
   - Bump `updatedAt`.
2. If it’s a substantial change or reversal:
   - Create a new memory entry with the updated decision.
   - Mark the old one:
     - `status = "superseded"` or `"deprecated"`.
     - `supersededBy = "<new-id>"`.
   - Keep both entries in the file for history.

Never silently rewrite history in a way that hides past decisions.

### 5. Track usage

Whenever a memory directly influences planning or execution:

1. Find the corresponding entry by `id`.
2. Increment `useCount` (e.g., `useCount += 1`).
3. Set `lastUsedAt` to current ISO timestamp.
4. Write the updated file back.

This allows future tools to treat highly-used, high-importance memories as more trustworthy.

---

## How other skills/commands should use this

When planning or executing non-trivial work (new features, refactors, risky changes):

1. Summarize the intent in a short description:
   - Files/directories involved.
   - Task IDs (if any).
   - Domains (e.g. testing, performance, architecture).
2. Use this skill to query for relevant memories.
3. Apply those memories as **constraints and prior decisions** when:
   - Creating task trees.
   - Designing architecture.
   - Writing or refactoring code.
   - Setting up tests, infra, or workflows.
4. If a new decision emerges that future work should follow:
   - Call this skill again to create or update a memory entry.

This way, `.taskmanager/memories.json` becomes the single, durable “project brain” that all agents/commands/skills can rely on.
