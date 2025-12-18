#!/usr/bin/env bun
/**
 * Landing Page Design Script
 * Creates persona-specific landing page specifications
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
import type { LandingPage, Persona, Strategy, Article } from "./types";

// ============================================================================
// Section Types and Templates
// ============================================================================

interface SectionTemplate {
  name: string;
  required: boolean;
  variants: string[];
  purpose: string;
}

const SECTION_TEMPLATES: SectionTemplate[] = [
  {
    name: "hero",
    required: true,
    variants: ["split", "centered", "video", "animated"],
    purpose: "Capture attention and communicate value proposition",
  },
  {
    name: "pain-points",
    required: true,
    variants: ["cards", "list", "comparison"],
    purpose: "Validate the problem and create empathy",
  },
  {
    name: "solution",
    required: true,
    variants: ["overview", "demo", "visual"],
    purpose: "Introduce the product as the solution",
  },
  {
    name: "features",
    required: true,
    variants: ["alternating", "grid", "tabs", "comparison"],
    purpose: "Showcase key features and benefits",
  },
  {
    name: "social-proof",
    required: true,
    variants: ["testimonials", "logos", "stats", "reviews"],
    purpose: "Build trust and credibility",
  },
  {
    name: "how-it-works",
    required: false,
    variants: ["steps", "timeline", "video"],
    purpose: "Explain the process simply",
  },
  {
    name: "faq",
    required: false,
    variants: ["accordion", "grid", "categories"],
    purpose: "Address objections and questions",
  },
  {
    name: "pricing",
    required: false,
    variants: ["tiers", "comparison", "simple"],
    purpose: "Present pricing options clearly",
  },
  {
    name: "final-cta",
    required: true,
    variants: ["centered", "split", "sticky"],
    purpose: "Drive conversion action",
  },
];

// ============================================================================
// Design System
// ============================================================================

interface DesignSystem {
  colorScheme: "light" | "dark" | "both";
  primaryColor: string;
  style: string;
  typography: {
    headingFont: string;
    bodyFont: string;
    sizes: {
      h1: string;
      h2: string;
      h3: string;
      body: string;
    };
  };
  spacing: {
    sectionPadding: string;
    elementGap: string;
  };
}

const DEFAULT_DESIGN_SYSTEMS: Record<string, DesignSystem> = {
  modern: {
    colorScheme: "light",
    primaryColor: "#3B82F6",
    style: "clean, minimal, modern",
    typography: {
      headingFont: "Inter, system-ui, sans-serif",
      bodyFont: "Inter, system-ui, sans-serif",
      sizes: {
        h1: "4rem",
        h2: "2.5rem",
        h3: "1.5rem",
        body: "1rem",
      },
    },
    spacing: {
      sectionPadding: "6rem",
      elementGap: "2rem",
    },
  },
  bold: {
    colorScheme: "dark",
    primaryColor: "#8B5CF6",
    style: "bold, high-contrast, impactful",
    typography: {
      headingFont: "Poppins, sans-serif",
      bodyFont: "Inter, system-ui, sans-serif",
      sizes: {
        h1: "5rem",
        h2: "3rem",
        h3: "1.75rem",
        body: "1.125rem",
      },
    },
    spacing: {
      sectionPadding: "8rem",
      elementGap: "2.5rem",
    },
  },
  professional: {
    colorScheme: "light",
    primaryColor: "#0F172A",
    style: "professional, trustworthy, enterprise",
    typography: {
      headingFont: "Söhne, system-ui, sans-serif",
      bodyFont: "Inter, system-ui, sans-serif",
      sizes: {
        h1: "3.5rem",
        h2: "2.25rem",
        h3: "1.5rem",
        body: "1rem",
      },
    },
    spacing: {
      sectionPadding: "5rem",
      elementGap: "1.5rem",
    },
  },
};

// ============================================================================
// Copy Generation
// ============================================================================

interface SectionCopy {
  headline: string;
  subheadline?: string;
  body?: string;
  cta?: string;
  items?: Array<{
    title: string;
    description: string;
    icon?: string;
  }>;
}

/**
 * Generate hero section copy
 */
function generateHeroCopy(
  persona: Persona,
  projectName: string,
  features: string[]
): SectionCopy {
  const problem = persona.psychographics.challenges[0] || "your biggest challenge";
  const goal = persona.psychographics.goals[0] || "achieve your goals";

  // Headline frameworks
  const headlines = [
    `Stop ${problem.split(" ").slice(0, 4).join(" ")}. Start ${goal.split(" ").slice(0, 3).join(" ")}.`,
    `${goal.charAt(0).toUpperCase() + goal.slice(1)} Without the Hassle`,
    `The ${persona.demographics.jobTitle}'s Secret to ${goal.split(" ").slice(0, 3).join(" ")}`,
  ];

  return {
    headline: headlines[Math.floor(Math.random() * headlines.length)],
    subheadline: `${projectName} helps ${persona.demographics.jobTitle}s ${features[0]?.toLowerCase() || "work smarter"} in half the time.`,
    body: persona.messaging.primary,
    cta: persona.messaging.cta.decision,
  };
}

/**
 * Generate pain points section copy
 */
function generatePainPointsCopy(persona: Persona): SectionCopy {
  return {
    headline: "Sound Familiar?",
    subheadline: `We understand the challenges ${persona.demographics.jobTitle}s face every day.`,
    items: persona.psychographics.challenges.slice(0, 4).map((challenge, i) => ({
      title: challenge,
      description: `${persona.psychographics.fears[i % persona.psychographics.fears.length] || "This leads to wasted time and frustration."}`,
      icon: ["🔥", "⏰", "😤", "💸"][i],
    })),
  };
}

/**
 * Generate solution section copy
 */
function generateSolutionCopy(
  persona: Persona,
  projectName: string,
  features: string[]
): SectionCopy {
  return {
    headline: `Introducing ${projectName}`,
    subheadline: persona.messaging.logical,
    body: `${projectName} was built from the ground up to help ${persona.demographics.jobTitle}s like you ${persona.psychographics.goals[0]?.toLowerCase() || "succeed"}. No more ${persona.psychographics.challenges[0]?.toLowerCase() || "struggling"}. Just results.`,
    cta: "See How It Works",
  };
}

/**
 * Generate features section copy
 */
function generateFeaturesCopy(
  persona: Persona,
  features: string[]
): SectionCopy {
  return {
    headline: "Everything You Need",
    subheadline: `Powerful features designed for ${persona.demographics.jobTitle}s who demand results.`,
    items: features.slice(0, 6).map((feature, i) => ({
      title: feature,
      description: `${persona.psychographics.goals[i % persona.psychographics.goals.length] || "Achieve more in less time."}`,
      icon: ["✨", "🚀", "💡", "🎯", "⚡", "🔒"][i],
    })),
  };
}

/**
 * Generate social proof section copy
 */
function generateSocialProofCopy(persona: Persona): SectionCopy {
  return {
    headline: "Trusted by Teams Like Yours",
    subheadline: `Join thousands of ${persona.demographics.jobTitle}s who've transformed their workflow.`,
    items: [
      {
        title: '"Game-changer for our team"',
        description: `— ${persona.demographics.jobTitle} at Fortune 500 Company`,
      },
      {
        title: '"Cut our workload by 50%"',
        description: `— ${persona.demographics.jobTitle} at Fast-Growing Startup`,
      },
      {
        title: '"Best investment we made this year"',
        description: `— ${persona.demographics.jobTitle} at Industry Leader`,
      },
    ],
  };
}

/**
 * Generate how it works section copy
 */
function generateHowItWorksCopy(projectName: string): SectionCopy {
  return {
    headline: "Get Started in 3 Simple Steps",
    subheadline: `Getting up and running with ${projectName} takes minutes, not days.`,
    items: [
      {
        title: "1. Sign Up",
        description: "Create your free account in under 30 seconds. No credit card required.",
        icon: "📝",
      },
      {
        title: "2. Connect",
        description: "Integrate with your existing tools and import your data effortlessly.",
        icon: "🔗",
      },
      {
        title: "3. Transform",
        description: "Watch as your productivity soars and problems disappear.",
        icon: "🚀",
      },
    ],
  };
}

/**
 * Generate FAQ section copy
 */
function generateFAQCopy(persona: Persona, projectName: string): SectionCopy {
  return {
    headline: "Frequently Asked Questions",
    items: persona.behavior.objections.slice(0, 5).map((objection) => ({
      title: `What about "${objection.toLowerCase()}"?`,
      description: `We've designed ${projectName} specifically to address this concern. Here's how...`,
    })),
  };
}

/**
 * Generate pricing section copy
 */
function generatePricingCopy(persona: Persona): SectionCopy {
  const plans =
    persona.market === "B2B"
      ? [
          { title: "Starter", description: "For small teams getting started" },
          { title: "Professional", description: "For growing teams that need more" },
          { title: "Enterprise", description: "For organizations that need everything" },
        ]
      : [
          { title: "Free", description: "Get started at no cost" },
          { title: "Pro", description: "For power users who want more" },
          { title: "Team", description: "For teams that collaborate" },
        ];

  return {
    headline: "Simple, Transparent Pricing",
    subheadline: "Choose the plan that fits your needs. Upgrade or downgrade anytime.",
    items: plans,
  };
}

/**
 * Generate final CTA section copy
 */
function generateFinalCTACopy(
  persona: Persona,
  projectName: string
): SectionCopy {
  return {
    headline: `Ready to ${persona.psychographics.goals[0]?.toLowerCase() || "Get Started"}?`,
    subheadline: `Join thousands of ${persona.demographics.jobTitle}s who've already transformed their workflow with ${projectName}.`,
    cta: persona.messaging.cta.decision,
    body: "No credit card required. Free 14-day trial. Cancel anytime.",
  };
}

// ============================================================================
// Wireframe Generation
// ============================================================================

/**
 * Generate ASCII wireframe for landing page
 */
function generateWireframe(sections: LandingPage["sections"]): string {
  let wireframe = "```\n";
  wireframe += "┌─────────────────────────────────────────────────────┐\n";
  wireframe += "│                     NAVIGATION                      │\n";
  wireframe += "│  Logo            Features  Pricing  Login  [CTA]   │\n";
  wireframe += "├─────────────────────────────────────────────────────┤\n";

  for (const section of sections) {
    wireframe += `│                                                     │\n`;
    wireframe += `│  ═══════════════ ${section.type.toUpperCase().padEnd(20)} ═══════════════  │\n`;

    switch (section.type) {
      case "hero":
        wireframe += "│                                                     │\n";
        wireframe += "│     ┌─────────────────┐    ┌─────────────────┐    │\n";
        wireframe += "│     │    HEADLINE     │    │                 │    │\n";
        wireframe += "│     │   Subheadline   │    │     [IMAGE]     │    │\n";
        wireframe += "│     │                 │    │                 │    │\n";
        wireframe += "│     │  [Primary CTA]  │    │                 │    │\n";
        wireframe += "│     └─────────────────┘    └─────────────────┘    │\n";
        break;

      case "pain-points":
        wireframe += "│                                                     │\n";
        wireframe += "│     ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐           │\n";
        wireframe += "│     │ 🔥  │  │ ⏰  │  │ 😤  │  │ 💸  │           │\n";
        wireframe += "│     │Pain │  │Pain │  │Pain │  │Pain │           │\n";
        wireframe += "│     │  1  │  │  2  │  │  3  │  │  4  │           │\n";
        wireframe += "│     └─────┘  └─────┘  └─────┘  └─────┘           │\n";
        break;

      case "features":
        wireframe += "│                                                     │\n";
        wireframe += "│     [IMG]  Feature 1 ──────────────────────       │\n";
        wireframe += "│            Description text here                   │\n";
        wireframe += "│                                                     │\n";
        wireframe += "│     ────────────────────────────── Feature 2 [IMG] │\n";
        wireframe += "│                       Description text here        │\n";
        break;

      case "social-proof":
        wireframe += "│                                                     │\n";
        wireframe += "│     ┌─────────────────────────────────────────┐   │\n";
        wireframe += "│     │  ⭐⭐⭐⭐⭐  \"Testimonial quote...\"      │   │\n";
        wireframe += "│     │              — Name, Title, Company      │   │\n";
        wireframe += "│     └─────────────────────────────────────────┘   │\n";
        wireframe += "│     [Logo] [Logo] [Logo] [Logo] [Logo] [Logo]     │\n";
        break;

      case "how-it-works":
        wireframe += "│                                                     │\n";
        wireframe += "│     ①──────────▶ ②──────────▶ ③                   │\n";
        wireframe += "│    Sign Up      Connect      Transform             │\n";
        break;

      case "pricing":
        wireframe += "│                                                     │\n";
        wireframe += "│     ┌────────┐  ┌────────┐  ┌────────┐           │\n";
        wireframe += "│     │ FREE   │  │  PRO   │  │ TEAM   │           │\n";
        wireframe += "│     │  $0    │  │ $29/mo │  │ $99/mo │           │\n";
        wireframe += "│     │ [CTA]  │  │ [CTA]  │  │ [CTA]  │           │\n";
        wireframe += "│     └────────┘  └────────┘  └────────┘           │\n";
        break;

      case "final-cta":
        wireframe += "│                                                     │\n";
        wireframe += "│     ╔═════════════════════════════════════════╗   │\n";
        wireframe += "│     ║     Ready to Get Started?               ║   │\n";
        wireframe += "│     ║           [START FREE TRIAL]            ║   │\n";
        wireframe += "│     ╚═════════════════════════════════════════╝   │\n";
        break;

      default:
        wireframe += "│                                                     │\n";
        wireframe += `│     [${section.type.toUpperCase()} SECTION CONTENT]                     │\n`;
    }

    wireframe += "│                                                     │\n";
    wireframe += "├─────────────────────────────────────────────────────┤\n";
  }

  wireframe += "│                      FOOTER                         │\n";
  wireframe += "│  Links  |  Social  |  Legal  |  Newsletter          │\n";
  wireframe += "└─────────────────────────────────────────────────────┘\n";
  wireframe += "```";

  return wireframe;
}

// ============================================================================
// Main Functions
// ============================================================================

/**
 * Create landing pages for all personas
 */
async function createLandingPages(): Promise<void> {
  const postDevDir = getPostDevDir();
  const landingDir = `${postDevDir}/landing-pages`;

  await ensureDir(landingDir);

  // Load personas
  const personasSummaryPath = `${postDevDir}/personas/summary.json`;
  if (!(await fileExists(personasSummaryPath))) {
    logError("No personas found. Run 'persona-create.ts' first.");
    process.exit(1);
  }

  const personasSummary = await readJson<{
    personas: Array<{ id: string; name: string; type: string }>;
  }>(personasSummaryPath);

  if (!personasSummary) {
    logError("Failed to load personas summary.");
    process.exit(1);
  }

  // Load full persona data
  const personas: Persona[] = [];
  for (const p of personasSummary.personas) {
    const persona = await readJson<Persona>(
      `${postDevDir}/personas/personas/${p.id}.json`
    );
    if (persona) {
      personas.push(persona);
    }
  }

  // Load project info
  const plan = await loadPostDevPlan();
  if (!plan) {
    logError("No post-development plan found.");
    process.exit(1);
  }

  const projectName = plan.project.name;
  const features = plan.project.features || ["Amazing features", "Easy to use", "Great support"];

  logInfo("Creating landing pages...");

  const landingPages: LandingPage[] = [];

  // Create landing page for each persona (prioritize primary and secondary)
  const targetPersonas = personas.filter((p) => p.type === "primary" || p.type === "secondary");

  for (const persona of targetPersonas) {
    logProgress(`Creating landing page for: ${persona.name}`);

    // Create persona landing page directory
    const personaDir = `${landingDir}/${persona.id}`;
    await ensureDir(personaDir);
    await ensureDir(`${personaDir}/images`);

    // Select design system based on market
    const designKey =
      persona.market === "B2B"
        ? "professional"
        : persona.market === "B2D"
          ? "modern"
          : "bold";
    const design = DEFAULT_DESIGN_SYSTEMS[designKey];

    // Generate sections
    const sections: LandingPage["sections"] = [];

    // Hero
    const heroCopy = generateHeroCopy(persona, projectName, features);
    sections.push({
      type: "hero",
      variant: "split",
      copy: heroCopy,
      images: ["hero-screenshot.png"],
    });

    // Pain points
    const painCopy = generatePainPointsCopy(persona);
    sections.push({
      type: "pain-points",
      variant: "cards",
      copy: painCopy,
    });

    // Solution
    const solutionCopy = generateSolutionCopy(persona, projectName, features);
    sections.push({
      type: "solution",
      variant: "overview",
      copy: solutionCopy,
      images: ["solution-demo.png"],
    });

    // Features
    const featuresCopy = generateFeaturesCopy(persona, features);
    sections.push({
      type: "features",
      variant: "alternating",
      copy: featuresCopy,
      images: features.map((_, i) => `feature-${i + 1}.png`),
    });

    // Social proof
    const socialCopy = generateSocialProofCopy(persona);
    sections.push({
      type: "social-proof",
      variant: "testimonials",
      copy: socialCopy,
    });

    // How it works
    const howCopy = generateHowItWorksCopy(projectName);
    sections.push({
      type: "how-it-works",
      variant: "steps",
      copy: howCopy,
    });

    // FAQ
    const faqCopy = generateFAQCopy(persona, projectName);
    sections.push({
      type: "faq",
      variant: "accordion",
      copy: faqCopy,
    });

    // Pricing (only for B2B and primary personas)
    if (persona.market === "B2B" || persona.type === "primary") {
      const pricingCopy = generatePricingCopy(persona);
      sections.push({
        type: "pricing",
        variant: "tiers",
        copy: pricingCopy,
      });
    }

    // Final CTA
    const ctaCopy = generateFinalCTACopy(persona, projectName);
    sections.push({
      type: "final-cta",
      variant: "centered",
      copy: ctaCopy,
    });

    // Create landing page object
    const landingPage: LandingPage = {
      id: `landing-${persona.id}`,
      persona: persona.id,
      meta: {
        title: `${projectName} - ${persona.messaging.primary}`,
        description: persona.messaging.logical,
        ogImage: "og-image.png",
      },
      design: {
        colorScheme: design.colorScheme,
        primaryColor: design.primaryColor,
        style: design.style,
      },
      sections,
      tracking: {
        utmSource: "marketing",
        utmMedium: "landing",
        utmCampaign: persona.id,
        events: ["page_view", "cta_click", "form_submit", "scroll_depth"],
      },
      createdAt: new Date().toISOString(),
    };

    landingPages.push(landingPage);

    // Save landing page JSON
    await writeJson(`${personaDir}/landing-page.json`, landingPage);

    // Generate copy document
    let copyDoc = `# Landing Page Copy: ${persona.name}\n\n`;
    copyDoc += `**Persona:** ${persona.name} (${persona.demographics.jobTitle})\n`;
    copyDoc += `**Market:** ${persona.market}\n`;
    copyDoc += `**Style:** ${design.style}\n\n`;
    copyDoc += `---\n\n`;

    for (const section of sections) {
      copyDoc += `## ${section.type.charAt(0).toUpperCase() + section.type.slice(1)}\n\n`;
      if (section.copy.headline) copyDoc += `**Headline:** ${section.copy.headline}\n\n`;
      if (section.copy.subheadline) copyDoc += `**Subheadline:** ${section.copy.subheadline}\n\n`;
      if (section.copy.body) copyDoc += `**Body:** ${section.copy.body}\n\n`;
      if (section.copy.cta) copyDoc += `**CTA:** ${section.copy.cta}\n\n`;
      if (section.copy.items) {
        copyDoc += `**Items:**\n`;
        for (const item of section.copy.items) {
          copyDoc += `- ${item.icon || ""} **${item.title}**: ${item.description}\n`;
        }
        copyDoc += `\n`;
      }
      copyDoc += `---\n\n`;
    }

    await Bun.write(`${personaDir}/copy.md`, copyDoc);

    // Generate wireframe
    const wireframe = generateWireframe(sections);
    await Bun.write(`${personaDir}/wireframe.md`, `# Wireframe: ${persona.name}\n\n${wireframe}`);
  }

  // Save summary
  const summary = {
    totalPages: landingPages.length,
    pages: landingPages.map((lp) => ({
      id: lp.id,
      persona: lp.persona,
      sections: lp.sections.length,
    })),
    generatedAt: new Date().toISOString(),
  };

  await writeJson(`${landingDir}/summary.json`, summary);

  // Update post-dev plan
  plan.tasks.landing.status = "completed";
  plan.tasks.landing.completedAt = new Date().toISOString();
  plan.tasks.landing.output = {
    pageCount: landingPages.length,
    personas: landingPages.map((lp) => lp.persona),
  };
  await savePostDevPlan(plan);

  logSuccess(`Created ${landingPages.length} landing pages`);
}

/**
 * List existing landing pages
 */
async function listLandingPages(): Promise<void> {
  const postDevDir = getPostDevDir();
  const summaryPath = `${postDevDir}/landing-pages/summary.json`;

  if (!(await fileExists(summaryPath))) {
    logWarning("No landing pages found. Run 'landing-design.ts' first.");
    return;
  }

  const summary = await readJson<{
    totalPages: number;
    pages: Array<{ id: string; persona: string; sections: number }>;
    generatedAt: string;
  }>(summaryPath);

  if (!summary) return;

  log("\n🎨 Generated Landing Pages\n");

  for (const page of summary.pages) {
    log(`📄 ${page.id}`);
    log(`   Persona: ${page.persona}`);
    log(`   Sections: ${page.sections}`);
    log("");
  }

  log(`📅 Generated: ${summary.generatedAt}`);
}

/**
 * Export landing pages
 */
async function exportLandingPages(): Promise<void> {
  const postDevDir = getPostDevDir();
  const landingDir = `${postDevDir}/landing-pages`;
  const exportDir = `${postDevDir}/exports/landing-pages`;

  await ensureDir(exportDir);

  const { readdir, copyFile } = await import("fs/promises");

  // Get all persona directories
  const items = await readdir(landingDir);
  const personaDirs = items.filter((i) => !i.endsWith(".json"));

  for (const dir of personaDirs) {
    const srcDir = `${landingDir}/${dir}`;
    const destDir = `${exportDir}/${dir}`;
    await ensureDir(destDir);

    // Copy files
    const files = await readdir(srcDir);
    for (const file of files) {
      if (file.endsWith(".json") || file.endsWith(".md")) {
        await copyFile(`${srcDir}/${file}`, `${destDir}/${file}`);
      }
    }
  }

  logSuccess(`Exported ${personaDirs.length} landing pages to ${exportDir}`);
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || "create";

  switch (command) {
    case "create":
      await createLandingPages();
      break;

    case "list":
      await listLandingPages();
      break;

    case "export":
      await exportLandingPages();
      break;

    default:
      log("Usage: bun run landing-design.ts [command]");
      log("");
      log("Commands:");
      log("  create    Generate all landing pages (default)");
      log("  list      List existing landing pages");
      log("  export    Export landing pages");
  }
}

main().catch((error) => {
  logError(`Fatal error: ${error}`);
  process.exit(1);
});
