# Technical Content Creation Process

Detailed instructions for each phase of article creation.

---

## Phase 0: Initialization

**Trigger:** User provides a topic

**Actions:**

1. Generate slug from topic (lowercase, dashes, no stop words)
2. Get timestamp using the timestamp skill
3. Create folder using the script:
   ```bash
   bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/create-article-folder.ts docs/articles/YYYY_MM_DD_<slug>
   ```
4. Check for voice profile at `docs/voice_profile.md`
   - If exists: Copy to article's `00_context/voice_profile.md`
   - If not: Ask user key questions and create one at `docs/voice_profile.md`
5. Ask clarifying questions:
   - Target audience (role, experience level)
   - Article type (tutorial, deep-dive, opinion, comparison)
   - Specific requirements or angles
   - Timeline constraints

---

## Phase 1: Context Loading

**Actions:**

1. Search for user's previous articles on related topics
2. Document prior positions in `00_context/content_history.md`
3. Ask about editorial calendar context
4. Write `00_context/editorial_context.md`

---

## Phase 2: Planning

**Article Types:**

| Type | Reader Goal | Approach |
|------|-------------|----------|
| Tutorial | Accomplish task | Direct, working code first |
| Deep-Dive | Understand why | Build mental models |
| Problem/Solution | Fix error | Lead with solution |
| Opinion/Strategy | Gain perspective | Establish credibility |
| Comparison | Make decision | Fair, declare biases |

**CHECKPOINT:** Present outline for user approval before proceeding.

---

## Phase 3: Research

**Source Priority:**
1. Official documentation
2. Source repositories
3. Academic papers / RFCs
4. Reputable tech publications
5. Conference talks
6. Community resources

**CHECKPOINT:** Share key findings, ask about gaps.

---

## Phase 4: Drafting

**Writing Rules:**
- No paragraph over 4 sentences
- Technical terms explained on first use
- Code tested and commented
- Match voice profile tone

**Write to:** `03_drafts/draft_v1.md`

---

## Phase 5: Review

Run the checklist script:

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/run-checklist.ts docs/articles/YYYY_MM_DD_slug
```

---

## Phase 6: Finalization

Write final article to `<article_slug>.md` in the article folder root.
