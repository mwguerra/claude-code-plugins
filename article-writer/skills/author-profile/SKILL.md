---
name: author-profile
description: Create and manage author profiles for consistent writing tone across articles. Use when setting up authors, checking profiles, or ensuring articles match the author's established voice. Replaces voice-profile.
---

# Author Profile

Create and maintain consistent author voice across all articles.

## Profile Location

Stored in: `.article_writer/authors.json`

Schema: `.article_writer/schemas/authors.schema.json`

## Creating an Author

Ask questions in conversational groups (2-3 at a time):

### Identity
1. What name/identifier for this author? (e.g., "mwguerra")
2. Display name? (e.g., "MW Guerra")
3. Professional role(s)?
4. Years/areas of experience?
5. Expertise areas?

### Languages
6. Primary writing language? (e.g., pt_BR, en_US)
7. Translation target languages?

### Tone (1-10)
8. Casual (1) vs Formal (10)?
9. Neutral (1) vs Opinionated (10)?

### Vocabulary
10. Terms readers know (use freely)?
11. Terms to always explain?

### Style
12. Signature phrases?
13. Phrases to avoid?

### Positions
14. Strong technology opinions?
15. Topics to stay neutral on?

### Example
16. Write 2-3 sentences in your voice as example.

## Author JSON Structure

```json
{
  "id": "author-slug",
  "name": "Display Name",
  "languages": ["pt_BR", "en_US"],
  "role": "Senior Developer",
  "experience": "10+ years",
  "expertise": ["Laravel", "PHP", "Architecture"],
  "tone": {
    "formality": 4,
    "opinionated": 7
  },
  "vocabulary": {
    "use_freely": ["Controllers", "Middleware", "API"],
    "always_explain": ["DDD", "CQRS", "Event Sourcing"]
  },
  "phrases": {
    "signature": ["Na prática...", "Vamos direto ao ponto:"],
    "avoid": ["Simplesmente", "É só fazer..."]
  },
  "opinions": {
    "strong_positions": ["Tests are essential", "Fat models are bad"],
    "stay_neutral": ["Tabs vs spaces", "IDE preferences"]
  },
  "example_voice": "Sample paragraph in author's voice..."
}
```

## Adding Author via Script

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/init.ts --author '{"id":"slug","name":"Name","languages":["en_US"]}'
```

## Multi-Language Workflow

1. Article written in author's primary language (first in array)
2. After completion, translated to other languages
3. Each file named: `{slug}.{language}.md`

Example for author with `["pt_BR", "en_US"]`:
```
content/articles/2025_01_15_rate-limiting/
├── rate-limiting.pt_BR.md    # Primary (written first)
└── rate-limiting.en_US.md    # Translation
```

## Using Author in Articles

When writing:
1. Load author from `.article_writer/authors.json`
2. If no author specified in task, use first author
3. Apply tone, vocabulary, and phrases from profile
4. Write in primary language first
5. Translate to other languages after completion

## Default Author

If article task doesn't specify author:
- First author in `authors.json` is used
- Their language settings apply
- Their voice/tone is followed

## Updating Authors

Update when:
- Writing style evolves
- New expertise develops
- Feedback indicates tone mismatch
- Language preferences change
