# Platform Voice Adjustment Guide

How to adapt an author's voice for different social media platforms.

## Tone Adjustment System

Each platform has a `tone_adjustment` with `formality_offset` and `opinionated_offset`. These are applied to the author's base tone:

```
effective_formality = clamp(base_formality + formality_offset, 1, 10)
effective_opinionated = clamp(base_opinionated + opinionated_offset, 1, 10)
```

### Default Adjustments

| Platform | Formality Offset | Opinionated Offset | Result (from base 5/5) |
|----------|-----------------|-------------------|----------------------|
| Blog | 0 | 0 | 5/5 |
| LinkedIn | +1 | 0 | 6/5 |
| Instagram | -2 | +1 | 3/6 |
| X/Twitter | -1 | +1 | 4/6 |

## LinkedIn Voice Guidelines

**Shift: Slightly more formal, same opinion level**

- Use complete sentences
- Professional but not corporate
- First-person storytelling is okay (and encouraged)
- Avoid jargon without context
- "I" and "we" are fine; avoid "u" or text-speak
- Longer paragraphs are acceptable (2-3 sentences)
- Share lessons learned, not just tips

**Sentence style:**
- Medium to long sentences
- Mix declarative and reflective
- "Here's what I learned..." / "The key insight was..."

**What changes from blog:**
- More personal anecdotes
- More direct address to the reader
- Hook is essential (scroll-stopping first line)
- CTA at the end (discussion prompt)

## Instagram Voice Guidelines

**Shift: More casual, more opinionated**

- Shorter sentences
- More direct and punchy
- Emojis are part of the vocabulary
- Use line breaks generously
- Text should work as "slides" mentally
- Strong opinions get more engagement
- Question the reader directly

**Sentence style:**
- Short, punchy sentences
- Fragments are okay: "Rate limiting. Not optional."
- Imperatives: "Stop doing X. Start doing Y."
- Questions: "Ever had your server crash at 3am?"

**What changes from blog:**
- Much shorter
- No code blocks in caption (save for carousel)
- Visual thinking — every point should be "slide-able"
- Emojis as bullet points or emphasis
- Hashtags are a discovery mechanism (20-30)

## X/Twitter Voice Guidelines

**Shift: More casual, more opinionated**

- Extremely concise
- Every word must earn its place
- Hot takes get engagement
- Strong opinions are expected
- Contrarian angles work well
- Thread format allows depth

**Sentence style:**
- Very short sentences
- Fragments are the norm
- "X is overrated." / "Here's why."
- Line breaks for dramatic effect

**What changes from blog:**
- Extreme brevity (280 chars per tweet)
- Threads allow depth but each tweet must stand alone
- More opinionated — take a stance
- Numbering tweets helps readability
- Hook tweet determines if anyone reads the rest
- End with engagement prompt

## Voice Analysis Integration

When the author has `voice_analysis` data, still apply it but adjust intensity:

| Voice Element | Blog | LinkedIn | Instagram | X/Twitter |
|---------------|------|----------|-----------|-----------|
| Signature phrases | Full | Full | Shortened | If fits in 280 chars |
| Characteristic expressions | Natural frequency | Natural | Occasional | Rare (space constraint) |
| Sentence starters | Full variety | Full | Simplified | Minimal |
| Signature vocabulary | Full | Full | Key terms only | Key terms only |
| Question ratio | As analyzed | Slightly higher | Higher (engagement) | Higher (engagement) |

## Example Transformation

### Author base tone: Formality 4, Opinionated 7

**Blog (4/7):**
> Rate limiting is one of those things most devs skip until it's too late. I've seen production servers go down twice because nobody bothered to add a simple middleware. The thing is, Laravel makes this ridiculously easy.

**LinkedIn (5/7):**
> Rate limiting might be the most overlooked aspect of API development. In my experience building production APIs, I've seen servers go down because this one simple step was skipped. Laravel makes the implementation straightforward — here's how I approach it.

**Instagram (2/8):**
> Your API has NO rate limiting?? One script = server down. I've seen it happen TWICE. Laravel makes this stupid easy. Swipe for the fix.

**X/Twitter (3/8):**
> Your API has no rate limiting.
>
> One script. Server down.
>
> I've seen it happen twice. Both times it was preventable.
>
> Laravel's built-in middleware takes 2 minutes to add.

## Rules That Never Change (Across All Platforms)

1. **Never use phrases from `phrases.avoid`** — even casually
2. **Vocabulary rules still apply** — don't explain terms from `use_freely`
3. **Strong positions** from `opinions.strong_positions` — express them (more strongly on X/Instagram)
4. **Neutral topics** from `opinions.stay_neutral` — stay neutral even on opinionated platforms
5. **Author name/persona** — maintain consistent identity across all platforms
