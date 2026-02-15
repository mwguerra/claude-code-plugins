# Deliberation Protocol Reference

How councils debate, reach verdicts, and how modes affect behavior.

---

## Standard Mode

The default deliberation mode. Balanced, thorough, structured.

### Flow

1. **Council Head receives question** (2 min)
   - Strip emotion, restate neutrally
   - Classify type and urgency
   - Select councils (2-4)
   - Ask clarifying questions if needed
   - Define evaluation criteria

2. **Councils deliberate in parallel** (5-10 min each)
   - Each council applies their perspective independently
   - Research if tools available and relevant
   - Apply the decision framework for this type
   - Each member archetype contributes their lens
   - Produce structured verdict with position, reasoning, risks, conditions

3. **Master of Councils synthesizes** (3-5 min)
   - Map all verdicts
   - Find consensus and conflicts
   - Apply configured weights
   - Surface critical tradeoffs
   - Make recommendation with confidence and risk levels
   - Define next action

4. **Record to database**
   - Persist all verdicts, synthesis, and recommendation
   - Set outcome to 'pending'

### Council Expectations in Standard Mode
- Thorough but not exhaustive
- Research when it adds genuine value
- Cover both upside and downside
- Provide clear position (SUPPORT/OPPOSE/NEUTRAL/SUPPORT WITH CONDITIONS)
- Identify 2-3 key risks
- State conditions for support

---

## Conflict Mode

Adversarial deliberation. Councils attack each other's arguments.

### How It Differs from Standard
- Councils are instructed to find and attack WEAK ARGUMENTS
- Each council must:
  - Challenge assumptions made by other councils
  - Demand evidence for claims
  - Point out logical fallacies
  - Present the strongest possible counter-argument
- The Master of Councils highlights irreconcilable tensions
- Useful when you suspect you're rationalizing a decision you've already made

### Council Behavior in Conflict Mode
- **Intelligence:** "Prove this technology choice isn't based on hype"
- **Business:** "Show me the numbers. Gut feelings don't count."
- **Life:** "You're hiding the personal cost. Let's talk about it."
- **Security:** "You haven't thought about what happens when this fails."

### When to Use Conflict Mode
- You suspect you're seeking validation rather than advice
- The decision feels "too obvious" (might be a blind spot)
- Stakes are very high and you need stress-tested reasoning
- You've been avoiding a hard conversation with yourself

---

## Ultra Mode

Maximum depth. All councils consulted, full research enabled.

### How It Differs from Standard
- ALL four councils are consulted regardless of decision type
- Extended research time - councils should actively search for data
- Master of Councils applies enhanced synthesis with deeper conflict analysis
- Used for life-changing, irreversible, or extremely high-stakes decisions

### Council Behavior in Ultra Mode
- All councils participate, even if the question isn't in their domain
  - Intelligence weighs in on personal decisions (systems thinking angle)
  - Life weighs in on business decisions (sustainability angle)
  - Security weighs in on career decisions (risk angle)
  - Business weighs in on personal decisions (opportunity cost angle)
- Research is mandatory for councils with tools
- Each council produces extended analysis (more detail than standard)

### When to Use Ultra Mode
- Career-defining decisions (quitting a job, starting a company)
- Major financial commitments (significant investment, debt)
- Irreversible life changes (relocation, major relationships)
- Strategic pivots that affect multiple life areas

---

## Quick Mode

Fast 5-minute decision. Essentials only.

### How It Differs from Standard
- Council Head picks only 1-2 most relevant councils
- No clarifying questions (unless critical)
- No research (even if tools available)
- Each council provides 2-3 bullet points maximum
- Master goes straight to recommendation
- Abbreviated output format

### Council Behavior in Quick Mode
- Skip the detailed analysis framework
- Provide your gut verdict plus top 2-3 supporting points
- Skip risks unless one is truly critical
- No conditions - just the recommendation

### Quick Mode Output

```markdown
## Quick Decision

**Question:** [question]
**Type:** [type] | **Urgency:** [urgency]

**[Council 1] says:** [SUPPORT/OPPOSE] - [2-3 bullet points]

**[Council 2] says:** [SUPPORT/OPPOSE] - [2-3 bullet points]

**Recommendation:** [Clear action]
**Confidence:** [level]
**Next Step:** [what to do now]
```

### When to Use Quick Mode
- Low-stakes decisions you're overthinking
- Meeting/scheduling decisions
- Simple yes/no questions
- When you need a quick gut check, not deep analysis

---

## Pre-mortem Mode

Assume the decision was made AND FAILED. Explain why.

### How It Differs from Standard
- The decision is NOT being evaluated for whether to do it
- The decision has ALREADY been made (or is being considered as if it was)
- Every council assumes it's 2 years from now and the decision was a disaster
- Each council explains HOW and WHY it failed from their perspective
- The Master synthesizes a unified failure narrative

### Council Behavior in Pre-mortem Mode
- **Intelligence:** "The technology bet failed because..."
- **Business:** "The business collapsed because..."
- **Life:** "Your health/relationships suffered because..."
- **Security:** "The risk materialized and you weren't prepared because..."

### Pre-mortem Output

```markdown
## Pre-mortem Analysis

**Decision:** [what was decided]
**Scenario:** It's [date + 2 years]. This decision failed catastrophically.

### How Intelligence Saw It Fail
[Detailed failure scenario from technology/systems perspective]

### How Business Saw It Fail
[Detailed failure scenario from financial/market perspective]

### How Life Saw It Fail
[Detailed failure scenario from personal/health/family perspective]

### How Security Saw It Fail
[Detailed failure scenario from risk/legal/continuity perspective]

### The Unified Failure Story
[Master's synthesis: how all these failure modes combined]

### What Would Have Prevented Failure
1. [Preventive measure 1]
2. [Preventive measure 2]
3. [Preventive measure 3]

### Should You Proceed Anyway?
[YES/NO with reasoning - even after the pre-mortem, is this still worth doing?]
```

### When to Use Pre-mortem Mode
- Before finalizing a major commitment
- When you feel overconfident about a decision
- To stress-test a plan before execution
- As a regular practice for all significant decisions

---

## Verdict Positions

Each council must declare a clear position:

| Position | Meaning |
|----------|---------|
| **SUPPORT** | Council recommends proceeding |
| **OPPOSE** | Council recommends against proceeding |
| **NEUTRAL** | Council sees balanced pros and cons, no strong position |
| **SUPPORT WITH CONDITIONS** | Council supports only if specific conditions are met |

### Rules for Positions
- NEUTRAL is allowed but should be rare. Most decisions have a lean.
- SUPPORT WITH CONDITIONS must explicitly list the conditions.
- OPPOSE must explain what would change their mind.
- In conflict mode, NEUTRAL is not allowed - pick a side.

---

## Confidence Levels

| Level | Meaning |
|-------|---------|
| **LOW** | Limited information, novel situation, low conviction |
| **MEDIUM** | Reasonable information, some uncertainty remains |
| **HIGH** | Strong evidence, clear reasoning, high conviction |

### Confidence Calibration
- HIGH should mean "I would bet significant money on this"
- LOW should mean "I could easily be wrong, here's my best guess"
- MEDIUM should mean "more likely right than wrong, but not certain"

---

## Weight Application

The Master of Councils applies weights when synthesizing:

### Default Weights
- Intelligence: 25%
- Business: 25%
- Life: 25%
- Security: 25%

### How Weights Work
- Weights represent the user's current life-phase priorities
- A council at 35% weight has more influence than one at 15%
- BUT weights don't override evidence - a 15%-weight council with strong evidence still matters
- The Master can explicitly override weights with justification

### Weight Override Rules
- If one council has HIGH confidence and others have LOW, the high-confidence council gets more weight regardless
- If a security risk is existential (company-killing), it overrides all weights
- If life/health impact is severe, the Life Council gets elevated regardless of weight
- The Master must explain any weight overrides in the synthesis

### Life Phase Examples
- **Early startup phase:** Business 35%, Intelligence 30%, Security 20%, Life 15%
- **Family growth phase:** Life 35%, Security 25%, Business 25%, Intelligence 15%
- **Scaling phase:** Business 30%, Intelligence 30%, Security 25%, Life 15%
- **Balanced/stable phase:** Equal 25% each

---

## Outcome Tracking Protocol

After a decision is made, the follow-up system tracks what happened:

### Recording Outcomes
- **success** - The decision worked as intended or better
- **partial** - Some aspects worked, others didn't
- **fail** - The decision did not achieve its goals
- **abandoned** - The decision was never fully implemented

### Council Accuracy Scoring
For each council that participated:
- If council SUPPORTED and outcome is SUCCESS → council was accurate
- If council OPPOSED and outcome is FAIL → council was accurate
- If council SUPPORTED and outcome is FAIL → council was inaccurate
- If council OPPOSED and outcome is SUCCESS → council was inaccurate
- PARTIAL outcomes → no accuracy score (ambiguous)
- NEUTRAL positions → no accuracy score (didn't commit)
- SUPPORT WITH CONDITIONS → accurate only if conditions were met/not met as predicted

### Pattern Analysis (requires 5+ decisions with outcomes)
The system can analyze:
- Which council is most accurate overall
- Which council is most accurate per decision type
- Whether the user tends to ignore specific councils
- Whether high-confidence recommendations correlate with better outcomes
- Systematic blind spots (areas where outcomes are consistently worse than expected)
