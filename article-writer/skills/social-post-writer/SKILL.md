---
description: Create platform-optimized social media posts for LinkedIn, Instagram, or X/Twitter with author voice adaptation
---

# Social Post Writer Skill

Create social media content optimized for LinkedIn, Instagram, or X/Twitter. Posts can be standalone (from a topic) or derived from an existing blog article.

## Workflow

### Standalone Mode

```
Initialize → Plan → Research (light) → Draft → Review → Translate → Finalize
```

### Derive Mode

```
Initialize → Read Source Article → Plan Adaptation → Draft → Review → Translate → Finalize
```

## Phase 1: Initialize

1. **Load author profile** from database
2. **Load platform defaults** from settings (`platform_defaults.<platform>`)
3. **Calculate effective tone**:
   ```
   effective_formality = clamp(author.formality + platform.tone_adjustment.formality_offset, 1, 10)
   effective_opinionated = clamp(author.opinionated + platform.tone_adjustment.opinionated_offset, 1, 10)
   ```
4. **Create folder structure**:
   - Standalone: Use `create-article-folder.ts --platform <platform>`
   - Derive: Use `create-article-folder.ts --platform <platform> --derive-from <id>`

## Phase 2: Plan / Plan Adaptation

### Standalone

- Identify the core message (1 sentence)
- Define the target audience for this platform
- Outline the key points (3-5)
- Choose the structure template for the platform

### Derive Mode

- Read the source blog article completely
- Extract: main thesis, key arguments, supporting examples, takeaways
- Select which themes translate best to this platform
- Plan adaptation strategy (what to keep, what to restructure, what to drop)

## Phase 3: Research (Light)

- Skip for derive mode (source article already researched)
- For standalone: 2-3 targeted searches, not the full blog research process
- Focus on current data, trending angles, platform-specific context

## Phase 4: Draft

### Voice Adjustment

Apply the effective tone calculated in Phase 1. See `references/platform-voice-guide.md` for detailed guidelines per platform.

### Platform-Specific Drafting

See the platform reference files for structure templates:

- **LinkedIn**: `references/linkedin-format.md`
- **Instagram**: `references/instagram-format.md`
- **X/Twitter**: `references/x-format.md`

### Output File Naming

| Platform | Files |
|----------|-------|
| LinkedIn | `{slug}.linkedin.{lang}.md` |
| Instagram | `{slug}.instagram.{lang}.md` + `{slug}.instagram.carousel.{lang}.md` |
| X/Twitter | `{slug}.x.tweet.{lang}.md` + `{slug}.x.thread.{lang}.md` |

## Phase 5: Review

**Platform Constraint Compliance Checklist:**

- [ ] Character/word limits met
- [ ] Hashtag count within range
- [ ] Required structural elements present (hook, CTA, etc.)
- [ ] Tone matches effective tone (not base author tone)
- [ ] No blog-article assumptions (e.g., "as we discussed in section 3")
- [ ] Platform-appropriate formatting (line breaks, emoji usage)

**For derive mode additionally:**
- [ ] Content stands alone (reader doesn't need the blog article)
- [ ] Key value proposition preserved from source
- [ ] No orphaned references to companion project or code examples

## Phase 6: Translate

- Translate to each additional language in author's profile
- Maintain platform constraints in all languages
- Hashtags: keep some universal, translate others
- Emojis: keep as-is (universal)

## Phase 7: Finalize

### Database Update

Insert article row with:
- `platform`: "linkedin" | "instagram" | "x"
- `derived_from`: source article ID (if derive mode)
- `platform_data`: JSON with platform-specific structured content
- `status`: "draft"
- `output_folder`: folder path
- `output_files`: per-language file paths

### Platform Data JSON Structures

**LinkedIn:**
```json
{
  "hook": "Opening 2-3 lines...",
  "body": "Main content...",
  "cta": "Call to action...",
  "hashtags": ["#Laravel", "#WebDev", "#PHP"],
  "word_count": 580
}
```

**Instagram:**
```json
{
  "caption": {
    "text": "Full caption text...",
    "visible_preview": "First 125 chars...",
    "hashtags": ["#laravel", "#php", "#webdev", "..."],
    "char_count": 1850
  },
  "carousel": {
    "slide_count": 7,
    "slides": [
      { "number": 1, "title": "Rate Limiting in Laravel", "body": "...", "visual_direction": "..." },
      { "number": 2, "title": "Why It Matters", "body": "...", "visual_direction": "..." }
    ]
  }
}
```

**X/Twitter:**
```json
{
  "tweet": {
    "text": "Single tweet text...",
    "char_count": 265,
    "hashtags": ["#Laravel", "#PHP"]
  },
  "thread": {
    "tweet_count": 8,
    "tweets": [
      { "number": 1, "text": "Thread opener...", "char_count": 275 },
      { "number": 2, "text": "Key point 1...", "char_count": 260 }
    ]
  }
}
```

## Companion Projects

Social posts do **NOT** get companion projects. If derived from a blog article that has one, link to it:

> "Full working example in the blog post: [link]"

## Scripts Reference

```bash
# Create folder for standalone social post
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts <path> --platform linkedin

# Create social/ subfolder for derived post
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts <path> --platform instagram --derive-from 42

# Load platform defaults
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/show.ts settings linkedin

# Set article status
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/article-stats.ts --set-status draft <id>
```
