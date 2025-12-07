---
name: article-writer-agent
description: Autonomous agent that processes article tasks from the queue, creating multi-language technical articles with author-specific voice and status tracking.
---

# Article Writer Agent

Autonomously process article tasks from `.article_writer/article_tasks.json`.

## Activation Triggers

- `Process next N pending articles`
- `Process article ID X`
- `Process all pending articles in area "Y"`
- `Process all pending articles by author "Z"`
- `Show article queue status`

## Prerequisites

Before running, verify:
1. Plugin initialized: `.article_writer/` exists
2. Authors configured: `.article_writer/authors.json` has entries
3. Valid task queue: `.article_writer/article_tasks.json`

## Workflow

### 1. Initialize Session

1. Load and validate `article_tasks.json`
2. Load `authors.json`
3. Create backup: `article_tasks.backup.json`
4. Report queue status

### 2. Select Articles

Filter by mode where `status: "pending"`:
- **By count**: First N pending
- **By ID**: Specific article
- **By area**: All pending in category
- **By author**: All pending for author ID
- **By difficulty**: All at specified level

### 3. Process Each Article

For each selected article:

```
a. Determine author:
   - If task has author.id, use that
   - Otherwise, use first author in authors.json
b. Load author profile
c. Update status: "pending" → "in_progress"
d. Save JSON immediately
e. Use Skill(article-writer):
   - Research: Search web for docs, news, tutorials
   - Draft: Write initial draft in primary language
   - Example: Create practical example (code/document)
   - Integrate: Update draft with example code/content
   - Review: Check flow, voice compliance, accuracy
   - Translate: Create other language versions
f. On success:
   - status → "draft"
   - output_folder → folder path
   - output_files → per-language paths
   - sources_used → array of researched URLs
   - example → example info (type, path, files)
   - written_at → now
g. On failure:
   - Keep "in_progress"
   - Add error_note
   - Continue to next
h. Save JSON after each
```

### 4. Build Article Context

```
Title: {title}
Subject: {subject}
Area: {area}
Difficulty: {difficulty}
Content Type: {content_type}
Estimated Effort: {estimated_effort}
Target Versions: {versions}
Prerequisites: {prerequisites}
Reference URLs: {reference_urls}
Tags: {tags}

Author: {author.name}
Primary Language: {author.languages[0]}
Translations: {author.languages[1:]}
Tone: Formality {tone.formality}/10, Opinionated {tone.opinionated}/10
```

### 4b. Apply Author Voice

**Use all author profile data when writing:**

1. **Manual Profile Data**
   - Match `tone.formality` (1=casual, 10=formal)
   - Match `tone.opinionated` (1=hedging, 10=strong opinions)
   - Use `phrases.signature` naturally
   - Avoid `phrases.avoid` completely
   - Assume reader knows `vocabulary.use_freely`
   - Explain `vocabulary.always_explain` on first use

2. **Voice Analysis Data** (if present)
   - Match `sentence_structure.avg_length` and `variety`
   - Reflect `communication_style` traits in tone
   - Sprinkle `characteristic_expressions` naturally (don't overuse)
   - Use patterns from `sentence_starters`
   - Prefer words from `signature_vocabulary`

**Example voice application:**

If author has:
```json
{
  "tone": { "formality": 4, "opinionated": 7 },
  "voice_analysis": {
    "sentence_structure": { "avg_length": 14, "variety": "moderate" },
    "communication_style": [{ "trait": "enthusiasm", "percentage": 32 }],
    "characteristic_expressions": ["na prática", "o ponto é"],
    "sentence_starters": ["Então", "O interessante é"]
  }
}
```

Then write:
- Conversational but confident (formality 4, opinionated 7)
- Medium-length sentences (~14 words average)
- With enthusiasm and energy
- Using "na prática" and "o ponto é" occasionally
- Starting some sentences with "Então" or "O interessante é"

### 5. Web Research Phase

For each article, search the web for:

1. **Official Documentation**
   - Search: "[technology] [topic] documentation"
   - Prioritize primary sources

2. **Recent Updates** (within 1 year)
   - Search: "[technology] [topic] 2024" or "2025"
   - Look for version-specific changes

3. **Best Practices**
   - Search: "[technology] [topic] best practices"
   - Find community recommendations

4. **Record All Sources**
   - Track every URL used
   - Note summary and how it was used
   - Save to task's sources_used array

### 6. Example Creation Phase

**Use Skill(example-creator) for this phase.**

> **CRITICAL: Examples must be COMPLETE, RUNNABLE applications.**

1. **Determine example type** from article content
2. **Load defaults** from `settings.json`
3. **For code examples:**
   ```bash
   # Execute scaffold_command from settings
   composer create-project laravel/laravel code --prefer-dist
   
   # Execute post_scaffold commands
   cd code
   composer require pestphp/pest --dev
   # etc.
   ```
4. **Add article-specific code** on top of scaffolded project
5. **Verify example works:**
   - Dependencies install
   - Application runs
   - Tests pass
6. **Update task** with example info including `verified: true`

**Never create partial projects with just a few files.**

### 7. Multi-Language Flow

For author with `languages: ["pt_BR", "en_US"]`:

1. Write article in pt_BR (primary)
2. Save as `{slug}.pt_BR.md`
3. Record in output_files
4. Translate to en_US
5. Save as `{slug}.en_US.md`
6. Record with translated_at timestamp

### 8. Progress Tracking

Log to `.article_writer/.processing-log.json`:

```json
{
  "session_id": "uuid",
  "started_at": "ISO",
  "mode": "batch|single|area|author",
  "processed": [
    {
      "id": 1,
      "author": "mwguerra",
      "languages_completed": ["pt_BR", "en_US"],
      "sources_found": 5,
      "example_created": true,
      "duration_seconds": 180
    }
  ],
  "errors": []
}
```

### 9. Completion

After batch:
1. Update `metadata.last_updated`
2. Report: processed, succeeded, failed
3. List languages completed per article
4. List errors
5. Suggest next actions

## Status Flow

```
pending → in_progress → draft → review → published
               ↓
           archived
```

## Commands During Processing

- `pause` - Finish current article and all its translations, then stop
- `skip` - Archive current, continue
- `status` - Show progress
- `abort` - Stop immediately

## Error Recovery

If interrupted:
1. Find `status: "in_progress"` articles
2. Check if output files exist
3. If all languages exist → update to "draft"
4. If partial → note which languages missing
5. If none → reset to "pending"
