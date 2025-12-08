---
description: Manage author profiles - add manually, extract from transcripts, list, show, or edit authors
allowed-tools: Skill(author-profile), Skill(voice-extractor), Bash(bun:*)
argument-hint: <add | analyze | list | show ID | edit ID | remove ID>
---

# Author Management

Manage author profiles in `.article_writer/authors.json`.

**File location:** `.article_writer/authors.json`
**Schema:** `.article_writer/schemas/authors.schema.json`
**Documentation:** [docs/COMMANDS.md](../docs/COMMANDS.md#article-writerauthor)

## Commands

### List all authors

```bash
/article-writer:author list
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts authors`

Shows all authors with: ID, name, languages, expertise, tone, and voice analysis status.

### Show single author

```bash
/article-writer:author show <id>
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts author <id>`

Shows complete profile: identity, languages, tone (visual scale), vocabulary, phrases, opinions, voice analysis data.

### Add new author (questionnaire)

```bash
/article-writer:author add
```

Uses: `Skill(author-profile)`

Interactive questionnaire covering:
1. Identity (id, name, role, experience, expertise)
2. Languages (primary + translations)
3. Tone (formality 1-10, opinionated 1-10)
4. Vocabulary (use freely, always explain)
5. Phrases (signature, avoid)
6. Opinions (strong positions, stay neutral)
7. Example voice paragraph

### Extract voice from transcripts

```bash
/article-writer:author analyze --list-speakers transcript.txt
/article-writer:author analyze --speaker "Name" transcript.txt
/article-writer:author analyze --speaker "Speaker Name" --author-id marcelo-guerra path/to/transcript.txt
```

Runs: `bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/voice-extractor.ts`

Uses: `Skill(voice-extractor)`

Extracts from transcripts:
- Sentence structure (length, variety, question frequency)
- Communication style (enthusiasm, analytical, directness, etc.)
- Characteristic expressions
- Sentence starters
- Signature vocabulary

**Supported formats:** Plain text, timestamped, WhatsApp, SRT subtitles

### Edit author

```bash
/article-writer:author edit <id>
```

Interactive editing, or use direct commands:

```bash
# Change a value
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts set-author <id> <path> <value>

# Add a phrase
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/config.ts add-phrase <id> signature "New phrase"
```

### Remove author

```bash
/article-writer:author remove <id>
```

Confirms before removing.

## Author Fields Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✓ | Unique slug identifier (lowercase, hyphens) |
| `name` | string | ✓ | Display name |
| `languages` | array | ✓ | Writing languages (first = primary) |
| `role` | string/array | | Professional role(s) |
| `experience` | string/array | | Years/areas of experience |
| `expertise` | string/array | | Areas of expertise |
| `tone.formality` | 1-10 | | 1=casual, 10=formal |
| `tone.opinionated` | 1-10 | | 1=neutral, 10=opinionated |
| `vocabulary.use_freely` | array | | Terms readers know |
| `vocabulary.always_explain` | array | | Terms to explain first use |
| `phrases.signature` | array | | Phrases to use naturally |
| `phrases.avoid` | array | | Phrases to never use |
| `opinions.strong_positions` | array | | Topics with strong views |
| `opinions.stay_neutral` | array | | Topics to be neutral on |
| `example_voice` | string | | Sample paragraph in voice |
| `voice_analysis` | object | | Data from transcript extraction |

## Default Author

The first author in `authors.json` is used when no author is specified for an article.
