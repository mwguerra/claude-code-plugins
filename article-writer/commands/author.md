---
description: Manage author profiles - add manually, extract from transcripts, list, show, or edit authors
allowed-tools: Skill(author-profile), Skill(voice-extractor), Bash(bun:*)
argument-hint: <add | analyze | list | show ID | edit ID | remove ID>
---

# Author Management

Manage author profiles in `.article_writer/authors.json`.

## Usage

### Add new author (manual questionnaire)
```
/article-writer:author add
```

### Extract voice from transcripts
```
/article-writer:author analyze --speaker "Name" transcripts/*.txt
/article-writer:author analyze --speaker "Name" --author-id existing-id transcript.txt
/article-writer:author analyze --list-speakers transcript.txt
```

### List all authors
```
/article-writer:author list
```

### Show author details
```
/article-writer:author show mwguerra
```

### Edit existing author
```
/article-writer:author edit mwguerra
```

### Remove author
```
/article-writer:author remove mwguerra
```

## Author Profile Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | ✓ | Unique slug-like identifier |
| name | string | ✓ | Display name |
| languages | array | ✓ | Writing languages (first is primary) |
| role | string/array | | Professional role(s) |
| experience | string/array | | Years/areas of experience |
| expertise | string/array | | Areas of expertise |
| tone.formality | 1-10 | | Casual (1) to Formal (10) |
| tone.opinionated | 1-10 | | Neutral (1) to Opinionated (10) |
| vocabulary.use_freely | array | | Terms readers know |
| vocabulary.always_explain | array | | Terms to explain |
| phrases.signature | array | | Phrases to use |
| phrases.avoid | array | | Phrases to never use |
| opinions.strong_positions | array | | Topics with strong views |
| opinions.stay_neutral | array | | Topics to be neutral on |
| example_voice | string | | Sample paragraph in voice |
| voice_analysis | object | | Data extracted from transcripts |

## Voice Analysis (from Transcripts)

Extract authentic voice patterns from podcasts, interviews, meetings:

```bash
# List speakers in transcripts
/article-writer:author analyze --list-speakers podcast.txt

# Create new author from voice analysis
/article-writer:author analyze --speaker "John Smith" podcast.txt interview.txt

# Enhance existing author with more transcript data  
/article-writer:author analyze --speaker "John" --author-id john-smith new_recording.txt
```

### What Gets Extracted

| Data | Description |
|------|-------------|
| sentence_structure | Average length, variety, question frequency |
| communication_style | Enthusiasm, hedging, directness, analytical, etc. |
| characteristic_expressions | "you know", "I think", "the thing is" |
| sentence_starters | "So the...", "I think...", "But the..." |
| signature_vocabulary | Words that characterize the speaker |

### Transcript Formats Supported

- Plain text: `Speaker: text`
- Timestamped: `[00:01:23] Speaker: text`
- WhatsApp: `[17:30, 12/6/2025] Speaker: text`
- SRT subtitles: Standard subtitle format

### Recommended Data

- **Minimum**: 50 speaking turns
- **Good**: 100+ turns, 5,000+ words
- **Best**: Multiple contexts (different topics/conversations)

## Multi-Language Support

Authors define their writing languages:
- First language is primary (article written here first)
- Other languages are translation targets
- Each article file includes language code: `article.pt_BR.md`

Example:
```json
{
  "languages": ["pt_BR", "en_US", "es_ES"]
}
```

Creates:
- `article-name.pt_BR.md` (primary, written first)
- `article-name.en_US.md` (translated)
- `article-name.es_ES.md` (translated)

## Default Author

When creating articles:
- If no author specified, uses first author in authors.json
- Articles inherit author's language settings
- Voice/tone follows author profile

## Workflow Examples

### Create Author from Transcripts

```
User: /article-writer:author analyze --speaker "Marcelo" podcasts/*.txt

Claude: Analyzing 5 transcripts for "Marcelo"...
Found 234 speaking turns (18,450 words).

Voice Analysis:
- Style: Moderate sentences (~14 words)
- Tone: Enthusiastic (32%), Analytical (28%)
- Expressions: "na prática", "tipo assim", "o ponto é"
- Vocabulary: código, arquitetura, implementação

Now I need identity info:
1. Author ID (slug)?
2. Display name?
3. Languages?
4. Expertise areas?
```

### Enhance Existing Author

```
User: /article-writer:author analyze --speaker "John" --author-id john-dev new_interview.txt

Claude: Adding voice data to existing author "john-dev"...

Current profile has: 0 voice samples
New analysis: 87 speaking turns

Suggested updates:
- Add 12 characteristic expressions
- Add 8 signature vocabulary words
- Update tone: formality 5→4, opinionated 5→7

Apply these updates? (yes/no/review)
```
