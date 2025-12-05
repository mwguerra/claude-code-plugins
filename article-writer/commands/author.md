---
description: Manage author profiles for article writing - add, list, show, or edit authors
allowed-tools: Skill(author-profile), Bash(bun:*)
argument-hint: <add | list | show ID | edit ID | remove ID>
---

# Author Management

Manage author profiles in `.article_writer/authors.json`.

## Usage

**Add new author:**
```
/article-writer:author add
```

**List all authors:**
```
/article-writer:author list
```

**Show author details:**
```
/article-writer:author show mwguerra
```

**Edit existing author:**
```
/article-writer:author edit mwguerra
```

**Remove author:**
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
