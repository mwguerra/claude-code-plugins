#!/usr/bin/env bun
/**
 * Persona Generation Script
 * Creates marketing personas based on SEO data and project analysis
 */

import {
  ensureDir,
  readJson,
  writeJson,
  fileExists,
  getPostDevDir,
  loadPostDevPlan,
  savePostDevPlan,
  log,
  logSuccess,
  logError,
  logWarning,
  logInfo,
  logProgress,
  parseArgs,
} from "./utils";
import type { Persona, Strategy, SEOPlan, PostDevelopmentPlan } from "./types";

// ============================================================================
// Persona Templates
// ============================================================================

interface PersonaTemplate {
  type: "primary" | "secondary" | "edge";
  market: "B2B" | "B2C" | "B2D" | "B2G";
  role: string;
  characteristics: string[];
}

const PERSONA_TEMPLATES: PersonaTemplate[] = [
  // B2B Templates
  {
    type: "primary",
    market: "B2B",
    role: "Decision Maker",
    characteristics: [
      "C-level or VP",
      "Budget authority",
      "Strategic thinker",
      "Risk-averse",
      "ROI focused",
    ],
  },
  {
    type: "secondary",
    market: "B2B",
    role: "Technical Evaluator",
    characteristics: [
      "Technical lead",
      "Hands-on evaluation",
      "Integration concerns",
      "Security focused",
      "Documentation lover",
    ],
  },
  {
    type: "edge",
    market: "B2B",
    role: "End User Champion",
    characteristics: [
      "Daily user",
      "Workflow optimizer",
      "Team influencer",
      "Adoption driver",
      "Feature requester",
    ],
  },

  // B2C Templates
  {
    type: "primary",
    market: "B2C",
    role: "Early Adopter",
    characteristics: [
      "Tech-savvy",
      "Trend follower",
      "Social sharer",
      "Premium payer",
      "Feature explorer",
    ],
  },
  {
    type: "secondary",
    market: "B2C",
    role: "Mainstream User",
    characteristics: [
      "Value conscious",
      "Ease-of-use focused",
      "Word-of-mouth driven",
      "Support seeker",
      "Practical needs",
    ],
  },
  {
    type: "edge",
    market: "B2C",
    role: "Power User",
    characteristics: [
      "Heavy usage",
      "Advanced features",
      "Community member",
      "Beta tester",
      "Feedback provider",
    ],
  },

  // B2D (Developer) Templates
  {
    type: "primary",
    market: "B2D",
    role: "Senior Developer",
    characteristics: [
      "Architecture decisions",
      "Tool selection",
      "Best practices",
      "Code quality",
      "Team mentor",
    ],
  },
  {
    type: "secondary",
    market: "B2D",
    role: "Indie Developer",
    characteristics: [
      "Solo projects",
      "Cost conscious",
      "Time-saver seeker",
      "Documentation reader",
      "Community active",
    ],
  },
];

// ============================================================================
// Persona Generation
// ============================================================================

interface PersonaInput {
  projectName: string;
  projectDescription: string;
  features: string[];
  keywords: string[];
  targetMarket: string;
}

/**
 * Generate a complete persona from template
 */
function generatePersona(
  template: PersonaTemplate,
  input: PersonaInput,
  index: number
): Persona {
  const id = `${template.market.toLowerCase()}-${template.role.toLowerCase().replace(/\s+/g, "-")}-${index}`;

  // Generate demographic data based on template
  const demographics = generateDemographics(template);

  // Generate psychographics based on template and input
  const psychographics = generatePsychographics(template, input);

  // Generate behavior patterns
  const behavior = generateBehavior(template, input);

  // Generate customer journey
  const journey = generateJourney(template, input);

  // Generate messaging framework
  const messaging = generateMessaging(template, input);

  return {
    id,
    name: generatePersonaName(template),
    type: template.type,
    market: template.market,
    demographics,
    psychographics,
    behavior,
    journey,
    messaging,
    createdAt: new Date().toISOString(),
  };
}

/**
 * Generate persona name
 */
function generatePersonaName(template: PersonaTemplate): string {
  const names: Record<string, string[]> = {
    "Decision Maker": ["Executive Emma", "Director David", "VP Victoria"],
    "Technical Evaluator": ["Tech Lead Tom", "Architect Anna", "Engineer Eric"],
    "End User Champion": ["Manager Mike", "Team Lead Tina", "Coordinator Chris"],
    "Early Adopter": ["Trendsetter Taylor", "Innovator Ian", "Pioneer Paula"],
    "Mainstream User": ["Everyday Emily", "Regular Ryan", "Typical Tracy"],
    "Power User": ["Expert Eddie", "Pro Patricia", "Advanced Alex"],
    "Senior Developer": ["Dev Lead Dana", "Principal Pete", "Staff Sarah"],
    "Indie Developer": ["Solo Sam", "Freelance Fiona", "Independent Ivan"],
  };

  const options = names[template.role] || ["User"];
  return options[Math.floor(Math.random() * options.length)];
}

/**
 * Generate demographic data
 */
function generateDemographics(template: PersonaTemplate): Persona["demographics"] {
  const baseDemo: Record<string, Partial<Persona["demographics"]>> = {
    "B2B": {
      ageRange: "35-50",
      education: "Bachelor's or MBA",
      incomeRange: "$100,000-$200,000",
      location: "Urban/Suburban",
    },
    "B2C": {
      ageRange: "25-45",
      education: "Bachelor's",
      incomeRange: "$50,000-$100,000",
      location: "Urban",
    },
    "B2D": {
      ageRange: "25-40",
      education: "Bachelor's in CS/Engineering",
      incomeRange: "$80,000-$180,000",
      location: "Urban/Remote",
    },
  };

  return {
    ageRange: baseDemo[template.market]?.ageRange || "25-45",
    education: baseDemo[template.market]?.education || "Bachelor's",
    jobTitle: template.role,
    incomeRange: baseDemo[template.market]?.incomeRange || "$50,000-$100,000",
    location: baseDemo[template.market]?.location || "Urban",
    industry: template.market === "B2B" ? "Technology/SaaS" : "Various",
  };
}

/**
 * Generate psychographics
 */
function generatePsychographics(
  template: PersonaTemplate,
  input: PersonaInput
): Persona["psychographics"] {
  const baseGoals: Record<string, string[]> = {
    "Decision Maker": [
      "Reduce operational costs",
      "Improve team productivity",
      "Stay competitive",
      "Minimize risk",
    ],
    "Technical Evaluator": [
      "Find reliable solutions",
      "Ensure scalability",
      "Maintain security",
      "Simplify integration",
    ],
    "End User Champion": [
      "Streamline workflows",
      "Save time on tasks",
      "Reduce frustration",
      "Look good to leadership",
    ],
    "Early Adopter": [
      "Be first with new tech",
      "Gain competitive edge",
      "Share discoveries",
      "Optimize everything",
    ],
    "Mainstream User": [
      "Solve specific problem",
      "Save money",
      "Easy to use",
      "Reliable support",
    ],
    "Senior Developer": [
      "Write better code",
      "Ship faster",
      "Reduce tech debt",
      "Mentor team",
    ],
  };

  const baseChallenges: Record<string, string[]> = {
    "Decision Maker": [
      "Too many options",
      "Proving ROI",
      "Change management",
      "Budget constraints",
    ],
    "Technical Evaluator": [
      "Integration complexity",
      "Documentation quality",
      "Vendor lock-in",
      "Performance concerns",
    ],
    "End User Champion": [
      "Learning curves",
      "Workflow disruption",
      "Feature gaps",
      "Support response time",
    ],
    "Early Adopter": [
      "Stability issues",
      "Limited features",
      "Pricing changes",
      "Platform risk",
    ],
    "Mainstream User": [
      "Complexity",
      "Cost",
      "Time to learn",
      "Privacy concerns",
    ],
    "Senior Developer": [
      "Time constraints",
      "Legacy systems",
      "Team adoption",
      "Documentation",
    ],
  };

  return {
    values: template.characteristics.slice(0, 3),
    goals: (baseGoals[template.role] || ["Solve problems", "Save time"]).map(
      (g) => `${g} with ${input.projectName}`
    ),
    challenges: baseChallenges[template.role] || ["Finding right solution"],
    fears: [
      "Wasting time on wrong solution",
      "Implementation failure",
      "Hidden costs",
    ],
    motivations: [
      `${input.projectName} addresses ${input.keywords[0] || "their needs"}`,
      "Clear value proposition",
      "Trusted by peers",
    ],
  };
}

/**
 * Generate behavior patterns
 */
function generateBehavior(
  template: PersonaTemplate,
  input: PersonaInput
): Persona["behavior"] {
  const channels: Record<string, string[]> = {
    "B2B": ["LinkedIn", "Industry publications", "Webinars", "Conferences", "Email"],
    "B2C": ["Instagram", "YouTube", "Google Search", "TikTok", "Email"],
    "B2D": ["GitHub", "Twitter/X", "Dev.to", "Hacker News", "Discord"],
  };

  return {
    decisionMaking:
      template.type === "primary"
        ? "Analytical with stakeholder input"
        : "Research-driven, peer-influenced",
    researchStyle:
      template.market === "B2D"
        ? "Documentation, code examples, GitHub stars"
        : "Reviews, case studies, demos",
    contentPreferences:
      template.market === "B2D"
        ? ["Technical docs", "Code samples", "API references"]
        : ["Case studies", "ROI calculators", "Video demos"],
    channels: channels[template.market] || channels["B2B"],
    triggers: [
      "Pain point becomes urgent",
      "Budget available",
      "Competitor using alternative",
      "Team request",
    ],
    objections: [
      "Price too high",
      "Not sure about ROI",
      "Concerned about implementation",
      "Need to convince stakeholders",
    ],
  };
}

/**
 * Generate customer journey
 */
function generateJourney(
  template: PersonaTemplate,
  input: PersonaInput
): Persona["journey"] {
  return {
    awareness: {
      touchpoints: ["Search", "Social media", "Word of mouth", "Content marketing"],
      questions: [
        `What is ${input.projectName}?`,
        `How does ${input.projectName} solve ${input.keywords[0] || "my problem"}?`,
        "Who else uses this?",
      ],
      content: ["Blog posts", "Social ads", "Explainer videos"],
    },
    consideration: {
      touchpoints: ["Website", "Demo", "Free trial", "Reviews"],
      questions: [
        "How does it compare to alternatives?",
        "What's the pricing?",
        "How long to implement?",
      ],
      content: ["Comparison guides", "Case studies", "Pricing page"],
    },
    decision: {
      touchpoints: ["Sales call", "Proposal", "Trial", "References"],
      questions: [
        "What's the total cost?",
        "What support is included?",
        "What's the contract terms?",
      ],
      content: ["ROI calculator", "Implementation guide", "Customer references"],
    },
    retention: {
      touchpoints: ["Onboarding", "Support", "Community", "Updates"],
      questions: [
        "How do I get help?",
        "What's on the roadmap?",
        "How can I do more?",
      ],
      content: ["Tutorial videos", "Knowledge base", "Webinars"],
    },
  };
}

/**
 * Generate messaging framework
 */
function generateMessaging(
  template: PersonaTemplate,
  input: PersonaInput
): Persona["messaging"] {
  const primaryMessage =
    template.type === "primary"
      ? `${input.projectName} helps ${template.role}s ${input.features[0] || "achieve their goals"}`
      : `${input.projectName} makes ${input.keywords[0] || "work"} easier`;

  return {
    primary: primaryMessage,
    emotional: `Stop struggling with ${input.keywords[0] || "complex problems"}. Start succeeding with ${input.projectName}.`,
    logical: `${input.projectName} delivers ${input.features.slice(0, 2).join(", ")} for ${template.role}s.`,
    cta: {
      awareness: "Learn More",
      consideration: "See How It Works",
      decision: "Start Free Trial",
    },
  };
}

// ============================================================================
// Strategy Generation
// ============================================================================

/**
 * Generate marketing strategy for personas
 */
function generateStrategy(personas: Persona[], input: PersonaInput): Strategy {
  const primaryPersona = personas.find((p) => p.type === "primary");
  const market = primaryPersona?.market || "B2B";

  return {
    id: `strategy-${Date.now()}`,
    name: `${input.projectName} Go-to-Market Strategy`,
    targetPersonas: personas.map((p) => p.id),
    positioning: {
      statement: `For ${primaryPersona?.demographics.jobTitle || "professionals"} who ${input.features[0] || "need a solution"}, ${input.projectName} is a ${input.projectDescription} that ${input.features.slice(0, 2).join(" and ")}. Unlike alternatives, ${input.projectName} provides ${input.features[2] || "unique value"}.`,
      differentiators: input.features.slice(0, 4),
      competitiveAdvantage: `Best-in-class ${input.keywords[0] || "solution"} with focus on ${input.keywords[1] || "user experience"}`,
    },
    messagingFramework: {
      primary: `${input.projectName}: ${input.projectDescription}`,
      emotional: `Transform how you ${input.keywords[0] || "work"}`,
      logical: `${input.features.length}+ features designed for ${market} success`,
    },
    channels: {
      primary:
        market === "B2D"
          ? ["GitHub", "Twitter/X", "Dev.to"]
          : market === "B2C"
            ? ["Instagram", "TikTok", "YouTube"]
            : ["LinkedIn", "Google Ads", "Content Marketing"],
      secondary:
        market === "B2D"
          ? ["Hacker News", "Reddit", "Discord"]
          : market === "B2C"
            ? ["Facebook", "Pinterest", "Email"]
            : ["Webinars", "Events", "Partnerships"],
    },
    contentPillars: [
      {
        name: "Educational",
        description: `How to ${input.keywords[0] || "succeed"} with ${input.projectName}`,
        formats: ["Blog posts", "Tutorials", "Guides"],
      },
      {
        name: "Social Proof",
        description: "Success stories and testimonials",
        formats: ["Case studies", "Reviews", "Testimonials"],
      },
      {
        name: "Product",
        description: "Features, updates, and best practices",
        formats: ["Release notes", "Feature spotlights", "Tips"],
      },
    ],
    conversionFunnel: {
      tofu: {
        goal: "Awareness",
        content: ["Blog posts", "Social content", "Ads"],
        metrics: ["Impressions", "Clicks", "Site visits"],
      },
      mofu: {
        goal: "Consideration",
        content: ["Case studies", "Webinars", "Demos"],
        metrics: ["Sign-ups", "Demo requests", "Content downloads"],
      },
      bofu: {
        goal: "Decision",
        content: ["Free trial", "Consultation", "Pricing"],
        metrics: ["Trials", "Qualified leads", "Conversions"],
      },
    },
    createdAt: new Date().toISOString(),
  };
}

// ============================================================================
// CTA Generation
// ============================================================================

interface CTA {
  id: string;
  text: string;
  type: "primary" | "secondary" | "tertiary";
  stage: "awareness" | "consideration" | "decision";
  persona?: string;
  channel?: string;
  url: string;
}

/**
 * Generate CTAs for personas
 */
function generateCTAs(personas: Persona[], baseUrl: string): CTA[] {
  const ctas: CTA[] = [];

  for (const persona of personas) {
    // Awareness CTAs
    ctas.push({
      id: `cta-${persona.id}-awareness`,
      text: persona.messaging.cta.awareness,
      type: persona.type === "primary" ? "primary" : "secondary",
      stage: "awareness",
      persona: persona.id,
      url: `${baseUrl}?utm_source=marketing&utm_medium=cta&utm_campaign=${persona.id}&utm_content=awareness`,
    });

    // Consideration CTAs
    ctas.push({
      id: `cta-${persona.id}-consideration`,
      text: persona.messaging.cta.consideration,
      type: "primary",
      stage: "consideration",
      persona: persona.id,
      url: `${baseUrl}/demo?utm_source=marketing&utm_medium=cta&utm_campaign=${persona.id}&utm_content=consideration`,
    });

    // Decision CTAs
    ctas.push({
      id: `cta-${persona.id}-decision`,
      text: persona.messaging.cta.decision,
      type: "primary",
      stage: "decision",
      persona: persona.id,
      url: `${baseUrl}/signup?utm_source=marketing&utm_medium=cta&utm_campaign=${persona.id}&utm_content=decision`,
    });
  }

  // Channel-specific CTAs
  const channels = ["linkedin", "twitter", "google", "email"];
  for (const channel of channels) {
    ctas.push({
      id: `cta-channel-${channel}`,
      text: "Get Started",
      type: "primary",
      stage: "consideration",
      channel,
      url: `${baseUrl}?utm_source=${channel}&utm_medium=social&utm_campaign=general`,
    });
  }

  return ctas;
}

// ============================================================================
// Main Functions
// ============================================================================

/**
 * Create personas from SEO data and project info
 */
async function createPersonas(): Promise<void> {
  const postDevDir = getPostDevDir();
  const personasDir = `${postDevDir}/personas`;

  await ensureDir(personasDir);
  await ensureDir(`${personasDir}/personas`);
  await ensureDir(`${personasDir}/strategies`);
  await ensureDir(`${personasDir}/cta/by-persona`);
  await ensureDir(`${personasDir}/cta/by-channel`);

  // Load SEO data for context
  const seoPath = `${postDevDir}/seo/seo-plan.json`;
  let keywords: string[] = [];
  if (await fileExists(seoPath)) {
    const seo = await readJson<SEOPlan>(seoPath);
    if (seo) {
      keywords = seo.pages.flatMap((p) => p.optimized.keywords).slice(0, 10);
    }
  }

  // Load post-dev plan for project info
  const plan = await loadPostDevPlan();
  if (!plan) {
    logError("No post-development plan found. Run 'init.ts' first.");
    process.exit(1);
  }

  // Prepare input
  const input: PersonaInput = {
    projectName: plan.project.name,
    projectDescription: plan.project.description || "A modern application",
    features: plan.project.features || ["Easy to use", "Powerful features", "Great support"],
    keywords: keywords.length > 0 ? keywords : ["productivity", "efficiency", "automation"],
    targetMarket: "B2B", // Default, could be configurable
  };

  logInfo("Generating personas...");

  // Generate personas from templates
  const personas: Persona[] = [];
  let index = 0;

  for (const template of PERSONA_TEMPLATES.slice(0, 6)) {
    // Generate 6 personas
    const persona = generatePersona(template, input, index++);
    personas.push(persona);

    // Save individual persona
    await writeJson(`${personasDir}/personas/${persona.id}.json`, persona);
    logProgress(`Created persona: ${persona.name} (${persona.type})`);
  }

  // Generate strategy
  logInfo("Generating marketing strategy...");
  const strategy = generateStrategy(personas, input);
  await writeJson(`${personasDir}/strategies/main-strategy.json`, strategy);

  // Generate CTAs
  logInfo("Generating CTAs...");
  const ctas = generateCTAs(personas, plan.config.baseUrl);

  // Save CTAs by persona
  for (const persona of personas) {
    const personaCTAs = ctas.filter((c) => c.persona === persona.id);
    await writeJson(`${personasDir}/cta/by-persona/${persona.id}.json`, personaCTAs);
  }

  // Save CTAs by channel
  const channels = [...new Set(ctas.filter((c) => c.channel).map((c) => c.channel))];
  for (const channel of channels) {
    const channelCTAs = ctas.filter((c) => c.channel === channel);
    await writeJson(`${personasDir}/cta/by-channel/${channel}.json`, channelCTAs);
  }

  // Save all CTAs
  await writeJson(`${personasDir}/cta/all-ctas.json`, ctas);

  // Save summary
  const summary = {
    personas: personas.map((p) => ({
      id: p.id,
      name: p.name,
      type: p.type,
      market: p.market,
      role: p.demographics.jobTitle,
    })),
    strategy: {
      id: strategy.id,
      name: strategy.name,
      channels: strategy.channels,
    },
    ctaCount: ctas.length,
    generatedAt: new Date().toISOString(),
  };
  await writeJson(`${personasDir}/summary.json`, summary);

  // Update post-dev plan
  plan.tasks.personas.status = "completed";
  plan.tasks.personas.completedAt = new Date().toISOString();
  plan.tasks.personas.output = {
    personaCount: personas.length,
    strategyId: strategy.id,
    ctaCount: ctas.length,
  };
  await savePostDevPlan(plan);

  logSuccess(`Generated ${personas.length} personas, 1 strategy, and ${ctas.length} CTAs`);
}

/**
 * List existing personas
 */
async function listPersonas(): Promise<void> {
  const postDevDir = getPostDevDir();
  const summaryPath = `${postDevDir}/personas/summary.json`;

  if (!(await fileExists(summaryPath))) {
    logWarning("No personas found. Run 'persona-create.ts' first.");
    return;
  }

  const summary = await readJson<{
    personas: Array<{ id: string; name: string; type: string; market: string; role: string }>;
    strategy: { name: string };
    ctaCount: number;
    generatedAt: string;
  }>(summaryPath);

  if (!summary) return;

  log("\n👥 Marketing Personas\n");

  for (const persona of summary.personas) {
    const typeEmoji =
      persona.type === "primary" ? "⭐" : persona.type === "secondary" ? "📌" : "🔹";
    log(`${typeEmoji} ${persona.name}`);
    log(`   ID: ${persona.id}`);
    log(`   Role: ${persona.role}`);
    log(`   Market: ${persona.market}`);
    log("");
  }

  log(`📊 Strategy: ${summary.strategy.name}`);
  log(`🎯 CTAs: ${summary.ctaCount}`);
  log(`📅 Generated: ${summary.generatedAt}`);
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || "create";

  switch (command) {
    case "create":
      await createPersonas();
      break;

    case "list":
      await listPersonas();
      break;

    default:
      log("Usage: bun run persona-create.ts [command]");
      log("");
      log("Commands:");
      log("  create    Generate personas from project data (default)");
      log("  list      List existing personas");
  }
}

main().catch((error) => {
  logError(`Fatal error: ${error}`);
  process.exit(1);
});
