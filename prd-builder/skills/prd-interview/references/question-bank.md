# PRD Interview Question Bank

Comprehensive question library organized by category. Use AskUserQuestion tool with 2-4 questions per round, adapting based on previous answers.

## Category 1: Problem & Context

### Core Questions

**What problem are you solving?**
- Header: "Problem"
- Options:
  - Pain point in existing workflow
  - Missing capability users need
  - Performance/efficiency issue
  - Compliance/security requirement

**Who experiences this problem most acutely?**
- Header: "Who"
- Options:
  - End users directly
  - Internal team members
  - Business stakeholders
  - External partners/clients

**What's the current workaround?**
- Header: "Workaround"
- Options:
  - Manual process
  - Third-party tool
  - No solution exists
  - Suboptimal existing feature

**Why solve this now?**
- Header: "Timing"
- Options:
  - Customer demand/feedback
  - Competitive pressure
  - Strategic priority
  - Technical debt reaching critical

### Follow-up Questions

**How frequently does this problem occur?**
- Header: "Frequency"
- Options: Daily, Weekly, Monthly, Occasionally

**What's the impact when this problem occurs?**
- Header: "Impact"
- Options: Lost revenue, User frustration, Wasted time, Compliance risk

**Are there seasonal or contextual factors?**
- Header: "Context"
- Options: Yes - seasonal, Yes - event-driven, Yes - user-specific, No patterns

---

## Category 2: Users & Customers

### Core Questions

**Who is the primary user?**
- Header: "Primary User"
- Options:
  - End consumers (B2C)
  - Business users (B2B)
  - Internal employees
  - Developers/technical users

**What's their technical proficiency?**
- Header: "Tech Level"
- Options:
  - Non-technical
  - Basic computer skills
  - Power users
  - Technical/developers

**What's their primary goal when using this?**
- Header: "User Goal"
- Options:
  - Complete a task quickly
  - Make informed decisions
  - Collaborate with others
  - Monitor/track something

**Are there secondary user types?**
- Header: "Secondary"
- multiSelect: true
- Options:
  - Administrators
  - Managers/supervisors
  - Support staff
  - External auditors

### Follow-up Questions

**What devices will users access this from?**
- Header: "Devices"
- multiSelect: true
- Options: Desktop, Mobile, Tablet, API/programmatic

**What's the typical session duration?**
- Header: "Session"
- Options: Quick (<1 min), Short (1-5 min), Medium (5-15 min), Extended (15+ min)

**What are their biggest frustrations with current solutions?**
- Header: "Frustrations"
- multiSelect: true
- Options: Too slow, Too complex, Missing features, Unreliable

---

## Category 3: Solution & Features

### Core Questions

**What's the core feature that solves the main problem?**
- Header: "Core Feature"
- Free text recommended - ask open-ended

**What's the MVP scope?**
- Header: "MVP Scope"
- Options:
  - Single core feature only
  - Core + 1-2 supporting features
  - Full feature set, simplified UX
  - Vertical slice (one complete flow)

**How should features be prioritized?**
- Header: "Priority"
- Options:
  - Must-have (P0) only for MVP
  - Must-have + key nice-to-haves
  - Full feature set phased
  - User-driven prioritization

**What's explicitly out of scope?**
- Header: "Out of Scope"
- multiSelect: true
- Options:
  - Mobile support initially
  - Advanced analytics
  - Third-party integrations
  - Multi-language support

### Follow-up Questions

**For each major feature, ask:**
- What triggers this feature?
- What's the expected outcome?
- What data does it need?
- What errors could occur?

**What differentiates this from alternatives?**
- Header: "Differentiator"
- Options: Speed, Simplicity, Integration, Cost, Quality

---

## Category 4: Technical Implementation

### Core Questions

**What's the target architecture?**
- Header: "Architecture"
- Options:
  - Monolithic application
  - Microservices
  - Serverless functions
  - Hybrid approach

**What's the primary tech stack?**
- Header: "Stack"
- Options:
  - Laravel + Filament
  - Node.js + React
  - Python + Django
  - Other (specify)

**What external integrations are needed?**
- Header: "Integrations"
- multiSelect: true
- Options:
  - Authentication (OAuth, SSO)
  - Payment processing
  - Email/notifications
  - Third-party APIs

**What are the main technical constraints?**
- Header: "Constraints"
- multiSelect: true
- Options:
  - Must work offline
  - Real-time requirements
  - Legacy system compatibility
  - Specific compliance (HIPAA, GDPR)

### Follow-up Questions

**What's the expected data volume?**
- Header: "Data Scale"
- Options: Small (<1GB), Medium (1-100GB), Large (100GB-1TB), Massive (1TB+)

**What's the expected concurrent user load?**
- Header: "Concurrency"
- Options: Low (<100), Medium (100-1K), High (1K-10K), Very High (10K+)

**Are there specific performance requirements?**
- Header: "Performance"
- Options:
  - Response time <100ms
  - Response time <1s
  - Batch processing OK
  - No specific requirements

**What's the deployment target?**
- Header: "Deployment"
- Options: Cloud (AWS/GCP/Azure), Self-hosted, Hybrid, Edge/distributed

---

## Category 5: Business & Value

### Core Questions

**What's the primary value proposition?**
- Header: "Value"
- Options:
  - Save time/increase efficiency
  - Reduce costs
  - Generate new revenue
  - Improve quality/accuracy

**How will success be measured?**
- Header: "Metrics"
- multiSelect: true
- Options:
  - User adoption rate
  - Time saved per task
  - Revenue generated
  - Error reduction

**Is there a revenue model?**
- Header: "Revenue"
- Options:
  - Subscription (SaaS)
  - One-time purchase
  - Freemium
  - Internal tool (no direct revenue)

**What's the pricing strategy?**
- Header: "Pricing"
- Options:
  - Free tier + paid upgrades
  - Flat monthly rate
  - Usage-based pricing
  - Enterprise custom pricing

### Follow-up Questions (skip for internal tools)

**What's the target customer acquisition cost?**
- Header: "CAC"
- Options: <$10, $10-50, $50-200, $200+

**What's the expected customer lifetime value?**
- Header: "LTV"
- Options: <$100, $100-500, $500-2000, $2000+

---

## Category 6: UX & Design

### Core Questions

**What's the primary interaction model?**
- Header: "Interaction"
- Options:
  - Form-based input
  - Dashboard/monitoring
  - Conversational/chat
  - Visual/drag-drop

**What's the visual style direction?**
- Header: "Style"
- Options:
  - Minimal/clean
  - Data-dense/professional
  - Playful/engaging
  - Match existing brand

**What accessibility requirements exist?**
- Header: "A11y"
- multiSelect: true
- Options:
  - WCAG 2.1 AA compliance
  - Screen reader support
  - Keyboard navigation
  - Color blindness support

**What are the responsive requirements?**
- Header: "Responsive"
- Options:
  - Desktop-first, mobile-friendly
  - Mobile-first
  - Desktop-only acceptable
  - Fully responsive all breakpoints

### Follow-up Questions

**What's the expected user flow complexity?**
- Header: "Flow"
- Options: Linear (1-2 steps), Branching (3-5 steps), Complex (5+ steps), Wizard-style

**Are there existing design system/components to use?**
- Header: "Design System"
- Options: Yes - comprehensive, Yes - partial, No - create new, Use framework default

---

## Category 7: Risks & Concerns

### Core Questions

**What are the main technical risks?**
- Header: "Tech Risks"
- multiSelect: true
- Options:
  - Scalability uncertainty
  - Third-party API reliability
  - Data migration complexity
  - Performance unknowns

**What are the main business risks?**
- Header: "Biz Risks"
- multiSelect: true
- Options:
  - Market timing
  - Competition response
  - Resource availability
  - Stakeholder alignment

**What dependencies could block progress?**
- Header: "Blockers"
- multiSelect: true
- Options:
  - External API access
  - Design assets
  - Legal/compliance approval
  - Infrastructure setup

**What assumptions are we making?**
- Header: "Assumptions"
- multiSelect: true
- Options:
  - Users want this feature
  - Technical approach is feasible
  - Resources will be available
  - Timeline is realistic

### Follow-up Questions

**What's the mitigation strategy for top risks?**
- Ask open-ended for each major risk identified

**What's the fallback if primary approach fails?**
- Header: "Fallback"
- Options: Simplified version, Alternative tech, Partner solution, Delay launch

---

## Category 8: Testing & Quality

### Core Questions

**What testing approach is required?**
- Header: "Testing"
- multiSelect: true
- Options:
  - Unit tests (Pest/PHPUnit)
  - Integration tests
  - E2E tests (Playwright)
  - Manual QA

**What are the key acceptance criteria?**
- Ask open-ended per major feature

**What's the minimum test coverage target?**
- Header: "Coverage"
- Options: 80%+ (comprehensive), 60-80% (solid), 40-60% (basic), No specific target

**What edge cases need special attention?**
- Header: "Edge Cases"
- multiSelect: true
- Options:
  - Empty states
  - Error handling
  - Concurrent access
  - Large data volumes

### Follow-up Questions

**What performance benchmarks must be met?**
- Header: "Benchmarks"
- Options: Strict SLAs, General guidelines, Best effort, N/A

**What security testing is required?**
- Header: "Security"
- multiSelect: true
- Options: Penetration testing, OWASP compliance, Dependency scanning, Code review

**What's the rollback strategy if issues found post-launch?**
- Header: "Rollback"
- Options: Feature flags, Database restore, Blue-green deployment, Manual revert

---

## Interview Pacing

### Recommended Flow

1. **Opening (1 round)**: Problem & Context overview
2. **Discovery (2-3 rounds)**: Users, Solution core
3. **Deep dive (3-4 rounds)**: Technical, Features detail
4. **Validation (2-3 rounds)**: Business, UX, Risks
5. **Closing (1-2 rounds)**: Testing, final questions

### Adaptive Shortcuts

**For features**: Compress Business to 1 round max
**For bugfixes**: Skip Business, UX to 1 round, focus Testing
**For internal tools**: Skip pricing questions entirely
**For backend-only**: Minimize UX category

### Question Batching

Aim for 2-4 questions per AskUserQuestion call:
- Related questions together
- Mix of single-select and multi-select
- Include one open-ended when appropriate
