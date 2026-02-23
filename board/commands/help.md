---
allowed-tools: []
description: Show the Board of Advisors structure, council members, and a worked deliberation example
---

# Board Help Command

You are implementing `board:help`. This command explains the Board of Advisors system to the user.

When invoked, display the ENTIRE content below exactly as written (in markdown). Do not summarize or shorten it.

---

Display this to the user:

```markdown
# Board of Advisors

Your personal advisory council for life and business decisions.

The Board doesn't just give you an answer — it gives you **perspectives you'd miss on your own**, tracks what you decided, and learns over time which perspectives predict reality best.

---

## How It Works

```
                          ┌─────────────┐
                          │     YOU      │
                          │  ask a big   │
                          │  question    │
                          └──────┬───────┘
                                 │
                                 ▼
                       ┌─────────────────┐
                       │  COUNCIL HEAD   │
                       │  (Orchestrator) │
                       │                 │
                       │ • Strips emotion│
                       │ • Classifies    │
                       │ • Routes        │
                       │ • Clarifies     │
                       └────────┬────────┘
                                │
             ┌──────────┬───────┴───────┬──────────┐
             ▼          ▼               ▼          ▼
      ┌────────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
      │INTELLIGENCE│ │ BUSINESS │ │   LIFE   │ │ SECURITY │
      │  COUNCIL   │ │ COUNCIL  │ │ COUNCIL  │ │ COUNCIL  │
      │            │ │          │ │          │ │          │
      │ 5 members  │ │ 5 members│ │ 5 members│ │ 5 members│
      │ Can search │ │Can search│ │ No tools │ │Can search│
      │ & research │ │& research│ │ (wisdom) │ │& analyze │
      └─────┬──────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
            │              │            │            │
            └──────┬───────┴────────────┴──────┬─────┘
                   │                           │
                   ▼                           │
          ┌──────────────────┐                 │
          │    MASTER OF     │◄────────────────┘
          │    COUNCILS      │
          │  (Synthesizer)   │
          │                  │
          │ • Finds consensus│
          │ • Maps conflicts │
          │ • Weighs tradeoffs│
          │ • Recommends     │
          └────────┬─────────┘
                   │
                   ▼
          ┌──────────────────┐
          │  DECISION RECORD │
          │  (SQLite DB)     │
          │                  │
          │ Persisted forever│
          │ Track outcomes   │
          │ Learn over time  │
          └──────────────────┘
```

---

## The Four Councils & Their Members

### Intelligence Council (cyan)
*Focus: long-term leverage, knowledge compounding, technology, optionality*
*Tools: can read codebase, search the web*

| Member | How They Think | What They Watch For |
|--------|---------------|-------------------|
| **The Technologist** | Modern, scalable, future-proof. "Will this be the standard in 5 years or a dead end?" | Technical debt, vendor lock-in, outdated stacks |
| **The Systems Thinker** | Everything is connected. "What are the second and third-order effects?" | Cascading failures, bottlenecks, unintended consequences |
| **The AI Strategist** | Automation, asymmetric advantage. "Can AI do this instead? Does AI change the equation?" | Opportunities to leverage AI, moats that AI erodes |
| **The Researcher** | Evidence over opinion. "What does the data say? What's the base rate for success here?" | Decisions made on gut feeling, unfounded assumptions |
| **The Historian** | Pattern matching. "How have similar decisions played out before? What failed and why?" | Repeating mistakes, ignoring lessons of history |

### Business Council (green)
*Focus: revenue, market positioning, risk vs return, viability, growth*
*Tools: can read codebase, search the web for market data*

| Member | How They Think | What They Watch For |
|--------|---------------|-------------------|
| **The CFO** | Cash is oxygen. "What's the P&L impact? When does this break even? What's the burn?" | Hidden costs, negative margins, cash flow gaps |
| **The Startup Founder** | Speed wins. "Can we test this in a week? Are we overthinking this?" | Over-engineering, analysis paralysis, building before validating |
| **The Product Strategist** | Position beats product. "Why would someone choose us? What's our unfair advantage?" | Commoditization, unclear positioning, feature parity traps |
| **The Investor** | Every resource allocation should return. "What's the ROI? Does this scale? Is this 10x or 2x?" | Linear businesses disguised as exponential, no competitive moat |
| **The Sales Mind** | Nothing happens until someone buys. "Will people pay for this? What's the main objection?" | Products nobody asked for, pricing disconnected from value |

### Life Council (yellow)
*Focus: health, family, happiness, sustainability, meaning*
*Tools: NONE — wisdom doesn't come from web searches*

| Member | How They Think | What They Watch For |
|--------|---------------|-------------------|
| **The Doctor** | Health is the foundation. "What will this do to your sleep, your body, your cognitive function?" | Burnout signals, health neglect, unsustainable pace |
| **The Psychologist** | Understand the WHY. "Why do you REALLY want this? What emotion is driving this decision?" | Avoidance patterns, sunk cost fallacy, fear-based decisions |
| **The Father** | Presence is the gift. "How will your family experience this? Will you be there for the moments that matter?" | Sacrifice of relationships, missed milestones, emotional absence |
| **Future Marcelo** | 20 years ahead. "Looking back from 2046, will you regret doing this or not doing it?" | Choices made from fear, playing it too safe, missed meaningful risks |
| **The Minimalist** | Less is more. "Does this simplify or complicate your life? Is this essential or just interesting?" | Overcommitment, complexity addiction, FOMO-driven decisions |

### Security Council (red)
*Focus: catastrophe prevention, risk mitigation, legal, continuity*
*Tools: can read codebase and contracts for risk analysis*

| Member | How They Think | What They Watch For |
|--------|---------------|-------------------|
| **The Paranoid Engineer** | If it can break, it will. "What's the single point of failure? What breaks at 3 AM?" | Untested assumptions, missing failovers, brittle dependencies |
| **The Lawyer** | If it's not in writing, it doesn't exist. "What's the legal exposure? Who owns the IP?" | Verbal agreements, missing contracts, liability gaps |
| **The Incident Commander** | It's about responding well. "What's the incident response plan? How fast can we roll back?" | No runbook, no communication chain, "this can't fail" thinking |
| **The Risk Analyst** | Risk = Probability × Impact. "What's the expected value? Black Swan or known risk?" | Low-probability high-impact risks being ignored |
| **The Backup Guy** | Always have Plan B, C, and D. "Can we undo this? What's the exit plan?" | Irreversible commitments, burned bridges, no exit strategy |

---

## Deliberation Modes

| Mode | When to Use | What Happens |
|------|------------|-------------|
| **standard** | Most decisions | 2-4 councils, balanced analysis, full structured output |
| **quick** | Low-stakes, overthinking | 1-2 councils, top points only, straight to recommendation |
| **conflict** | Suspect you're rationalizing | Councils attack each other's arguments, demand proof |
| **ultra** | Life-changing, irreversible | All 4 councils, full research, maximum depth |
| **premortem** | Stress-testing a decision | Assume it's 2 years later and it FAILED — explain why |

---

## Worked Example

**User:** "Board, I'm thinking about dropping all my consulting clients to go full-time on my SaaS product."

### Council Head Briefing

> **Clean Problem:** Whether to transition from consulting income (stable, proven) to full-time SaaS development (uncertain, potentially higher upside) by terminating all current client relationships.
>
> **Type:** career | **Urgency:** medium | **Mode:** standard
>
> **Councils Required:** All four — this touches career, finances, family, and risk.

### Intelligence Council [SUPPORT]

> **The Systems Thinker:** Consulting is linear income (trade hours for dollars). SaaS is a system that compounds — once built, each new customer costs near-zero to serve. The leverage difference is 10x over 5 years.
>
> **The AI Strategist:** Consulting is increasingly commoditized by AI. Your own SaaS product IS the moat. Build it before the window closes.
>
> **The Historian:** Most successful SaaS founders had a "jump" moment. Those who kept one foot in consulting often never shipped.
>
> **Risk:** If the SaaS fails, re-acquiring consulting clients takes 3-6 months. Your skills don't expire, but your pipeline does.

### Business Council [SUPPORT WITH CONDITIONS]

> **The CFO:** Current consulting revenue: ~$15k/month. SaaS revenue: $0. You need 12 months of runway saved before cutting income to zero. Do you have $180k in reserves?
>
> **The Startup Founder:** SUPPORT — but don't drop ALL clients. Keep your best 1-2 clients at 30% capacity for 6 months. This funds the build without killing momentum.
>
> **The Sales Mind:** Your consulting clients are your first SaaS prospects. Don't burn the bridge — transform the relationship. "I'm building a product that does what I do for you, but better and cheaper."
>
> **Condition:** Maintain 6+ months runway at all times. If it drops below 3 months, take a client.

### Life Council [NEUTRAL]

> **The Doctor:** Full-time on your own product will be MORE intense than consulting, not less. The dopamine of building is addictive. Set hard boundaries now or you'll work 80-hour weeks "because you love it."
>
> **The Father:** Your kids won't remember whether you were consulting or building a SaaS. They'll remember if you were present at dinner. Make sure the change doesn't mean "more work" disguised as "my work."
>
> **Future Marcelo (2046):** "I'd rather have tried and failed than spent another decade trading hours for dollars. The regret of not trying would be worse."
>
> **The Psychologist:** Check your motivation. Is this about building something meaningful, or is it running away from a client you hate? The answer matters.

### Security Council [SUPPORT WITH CONDITIONS]

> **The Risk Analyst:**
> | Threat | Probability | Severity | Mitigation |
> |--------|-----------|----------|------------|
> | SaaS doesn't find market fit | 40% | HIGH | Validate with 10 paying users before quitting |
> | Run out of money | 25% | CRITICAL | 12-month runway minimum |
> | Can't get clients back | 15% | MEDIUM | Leave on good terms, keep 1-2 relationships |
>
> **The Backup Guy:** Keep your consulting brand alive. Don't delete the website. Don't burn bridges. If SaaS fails at month 9, you can restart consulting in 4-6 weeks if relationships are warm.
>
> **Non-negotiable:** Do NOT drop clients until you have at least 5 paying SaaS users proving demand exists.

### Master of Councils — Final Synthesis

> **Consensus:** All councils agree that SaaS has higher long-term leverage than consulting. Nobody thinks staying in consulting forever is the right path.
>
> **Conflict:** Intelligence says "jump now, momentum matters" vs. Business/Security say "phase the transition, don't cut income to zero."
>
> **Critical Tradeoffs:**
> 1. Speed of SaaS development vs. financial safety — you can have momentum OR certainty, not both at 100%
> 2. Client relationships vs. focus — every hour consulting is an hour not building
>
> **What Must Be True:**
> 1. You have 6+ months of runway saved
> 2. At least 5 people have paid for the SaaS (not just "said they would")
> 3. Your family understands and supports the transition
>
> ### Recommendation: PROCEED — but phase it over 3 months
>
> Month 1-2: Reduce to 2 best clients (50% capacity). Ship SaaS MVP.
> Month 3: If 5+ paying users exist, drop to 1 client or zero.
> Month 4+: Full-time SaaS. Keep consulting brand warm as insurance.
>
> **Confidence:** HIGH | **Risk Level:** MEDIUM
>
> **Next Action:** Calculate your exact runway in months. If it's under 6, the timeline shifts. Open a spreadsheet tonight.

*Decision recorded as DEC-001. Track the outcome later with `/board:board followup DEC-001 --outcome success|partial|fail`*

---

## Commands

| Command | What It Does |
|---------|-------------|
| `/board:board ask "question"` | Full deliberation (add `--mode conflict\|ultra` for variants) |
| `/board:board quick "question"` | Fast 5-minute take, essentials only |
| `/board:board premortem "decision"` | Assume it failed in 2 years — explain why |
| `/board:board review weekly\|monthly\|quarterly` | Periodic review of recent decisions |
| `/board:board compass` | Life direction check — where are you focusing? blind spots? |
| `/board:board history [--stats\|--patterns]` | View past decisions and analytics |
| `/board:board followup DEC-XXX --outcome success\|partial\|fail` | Record what actually happened |
| `/board:board config show\|weights\|mode\|councils` | View and change settings |
| `/board:board init` | Initialize the database (auto-runs if needed) |
| `/board:board help` | This screen |

### Natural Language

You can also just talk to the board:
- *"Board, I'm thinking about..."*
- *"Ask the board about..."*
- *"What would my advisors say about..."*

For high-impact decisions detected in conversation, Claude will ask if you want the board involved.

---

## The Learning Loop

```
Ask → Decide → Act → Follow Up → Review → Improve
 │                      │            │
 │                      │            └─ Which councils predicted reality?
 │                      └─ /board followup DEC-XXX --outcome ...
 └─ /board ask "..."
```

Over time, the board reveals:
- Which councils predict reality best for which types of decisions
- Where your blind spots are (decisions that consistently go worse than expected)
- What areas of life you're neglecting (no decisions = avoiding something?)

The more you use it, the smarter it gets.
```
