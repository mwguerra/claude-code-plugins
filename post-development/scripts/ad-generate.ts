#!/usr/bin/env bun
/**
 * Ad Generation Script
 * Creates social media ad specifications for each persona and platform
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
import type { Ad, Persona, Strategy } from "./types";

// ============================================================================
// Platform Specifications
// ============================================================================

interface PlatformSpec {
  name: string;
  formats: FormatSpec[];
}

interface FormatSpec {
  name: string;
  dimensions: { width: number; height: number };
  aspectRatio: string;
  maxTextLength: {
    primary: number;
    headline?: number;
    description?: number;
  };
  hashtagLimit?: number;
  features: string[];
}

const PLATFORM_SPECS: PlatformSpec[] = [
  {
    name: "instagram",
    formats: [
      {
        name: "feed",
        dimensions: { width: 1080, height: 1080 },
        aspectRatio: "1:1",
        maxTextLength: { primary: 2200, headline: 40 },
        hashtagLimit: 30,
        features: ["image", "carousel", "video"],
      },
      {
        name: "stories",
        dimensions: { width: 1080, height: 1920 },
        aspectRatio: "9:16",
        maxTextLength: { primary: 125 },
        features: ["image", "video", "sticker", "poll"],
      },
      {
        name: "reels",
        dimensions: { width: 1080, height: 1920 },
        aspectRatio: "9:16",
        maxTextLength: { primary: 2200 },
        hashtagLimit: 30,
        features: ["video", "audio", "effects"],
      },
    ],
  },
  {
    name: "facebook",
    formats: [
      {
        name: "feed",
        dimensions: { width: 1200, height: 630 },
        aspectRatio: "1.91:1",
        maxTextLength: { primary: 125, headline: 27, description: 27 },
        features: ["image", "carousel", "video", "link"],
      },
      {
        name: "stories",
        dimensions: { width: 1080, height: 1920 },
        aspectRatio: "9:16",
        maxTextLength: { primary: 125 },
        features: ["image", "video"],
      },
    ],
  },
  {
    name: "linkedin",
    formats: [
      {
        name: "single-image",
        dimensions: { width: 1200, height: 627 },
        aspectRatio: "1.91:1",
        maxTextLength: { primary: 600, headline: 70, description: 100 },
        features: ["image", "link"],
      },
      {
        name: "carousel",
        dimensions: { width: 1080, height: 1080 },
        aspectRatio: "1:1",
        maxTextLength: { primary: 255, headline: 45 },
        features: ["carousel", "link"],
      },
    ],
  },
  {
    name: "twitter",
    formats: [
      {
        name: "single-image",
        dimensions: { width: 1200, height: 675 },
        aspectRatio: "16:9",
        maxTextLength: { primary: 280 },
        hashtagLimit: 2,
        features: ["image", "link"],
      },
      {
        name: "carousel",
        dimensions: { width: 800, height: 800 },
        aspectRatio: "1:1",
        maxTextLength: { primary: 280 },
        features: ["carousel"],
      },
    ],
  },
];

// ============================================================================
// Copy Frameworks
// ============================================================================

type CopyFramework = "PAS" | "BAB" | "FAB" | "AIDA";

interface CopyTemplate {
  framework: CopyFramework;
  structure: {
    hook: string;
    body: string;
    cta: string;
  };
}

/**
 * Generate copy using PAS framework (Problem-Agitate-Solve)
 */
function generatePASCopy(
  persona: Persona,
  projectName: string,
  feature: string
): { primary: string; headline: string } {
  const problem = persona.psychographics.challenges[0] || "struggling with efficiency";
  const agitate = `Every day wasted on ${problem.toLowerCase()} is money lost.`;
  const solve = `${projectName} ${feature.toLowerCase()}.`;

  return {
    primary: `${problem}?\n\n${agitate}\n\n${solve}`,
    headline: `Stop ${problem.split(" ").slice(0, 3).join(" ")}`,
  };
}

/**
 * Generate copy using BAB framework (Before-After-Bridge)
 */
function generateBABCopy(
  persona: Persona,
  projectName: string,
  feature: string
): { primary: string; headline: string } {
  const before = persona.psychographics.challenges[0] || "Manual processes";
  const after = persona.psychographics.goals[0] || "Streamlined workflows";
  const bridge = `${projectName} makes it happen with ${feature.toLowerCase()}.`;

  return {
    primary: `Before: ${before}\n\nAfter: ${after}\n\n${bridge}`,
    headline: `From ${before.split(" ").slice(0, 2).join(" ")} to Success`,
  };
}

/**
 * Generate copy using FAB framework (Features-Advantages-Benefits)
 */
function generateFABCopy(
  persona: Persona,
  projectName: string,
  feature: string
): { primary: string; headline: string } {
  const advantage = "saves you hours every week";
  const benefit = persona.psychographics.goals[0] || "achieve your goals faster";

  return {
    primary: `${projectName} ${feature.toLowerCase()}.\n\nThis ${advantage}.\n\nSo you can ${benefit.toLowerCase()}.`,
    headline: `${feature} That Actually Works`,
  };
}

// ============================================================================
// Ad Generation
// ============================================================================

/**
 * Generate ad for specific persona, platform, and format
 */
function generateAd(
  persona: Persona,
  platform: PlatformSpec,
  format: FormatSpec,
  projectName: string,
  features: string[],
  screenshots: string[],
  index: number
): Ad {
  const id = `ad-${platform.name}-${format.name}-${persona.id}-${index}`;

  // Select copy framework based on persona type
  const framework: CopyFramework =
    persona.type === "primary" ? "PAS" : persona.type === "secondary" ? "BAB" : "FAB";

  // Generate copy
  const feature = features[index % features.length] || "powerful features";
  let copy: { primary: string; headline: string };

  switch (framework) {
    case "PAS":
      copy = generatePASCopy(persona, projectName, feature);
      break;
    case "BAB":
      copy = generateBABCopy(persona, projectName, feature);
      break;
    default:
      copy = generateFABCopy(persona, projectName, feature);
  }

  // Truncate to platform limits
  if (copy.primary.length > format.maxTextLength.primary) {
    copy.primary = copy.primary.substring(0, format.maxTextLength.primary - 3) + "...";
  }
  if (format.maxTextLength.headline && copy.headline.length > format.maxTextLength.headline) {
    copy.headline = copy.headline.substring(0, format.maxTextLength.headline - 3) + "...";
  }

  // Generate hashtags
  const hashtags =
    format.hashtagLimit && format.hashtagLimit > 0
      ? generateHashtags(persona, projectName, format.hashtagLimit)
      : [];

  // Select screenshot
  const screenshotIndex = index % Math.max(screenshots.length, 1);
  const screenshot = screenshots[screenshotIndex] || "screenshot-placeholder.png";

  // Generate targeting
  const targeting = generateTargeting(persona, platform.name);

  // Create ad
  const ad: Ad = {
    id,
    platform: platform.name,
    format: format.name,
    persona: persona.id,
    dimensions: format.dimensions,
    creative: {
      type: "image",
      source: screenshot,
      overlay: {
        headline: copy.headline,
        subheadline: persona.messaging.primary,
        cta: persona.messaging.cta.consideration,
        logo: true,
      },
    },
    copy: {
      primary: copy.primary,
      headline: copy.headline,
      cta: persona.messaging.cta.consideration,
      hashtags,
    },
    targeting,
    variations: generateVariations(copy, persona),
    createdAt: new Date().toISOString(),
  };

  return ad;
}

/**
 * Generate hashtags based on persona and project
 */
function generateHashtags(
  persona: Persona,
  projectName: string,
  limit: number
): string[] {
  const hashtags: string[] = [];

  // Brand hashtag
  hashtags.push(`#${projectName.replace(/\s+/g, "")}`);

  // Industry hashtags based on market
  const industryTags: Record<string, string[]> = {
    B2B: ["#SaaS", "#BusinessGrowth", "#Productivity", "#Enterprise", "#B2B"],
    B2C: ["#LifeHack", "#MustHave", "#Trending", "#Essential", "#NewApp"],
    B2D: ["#DevTools", "#Coding", "#Developer", "#Programming", "#Tech"],
  };

  hashtags.push(...(industryTags[persona.market] || industryTags["B2B"]).slice(0, limit - 2));

  // Persona-specific hashtag
  if (persona.demographics.industry) {
    hashtags.push(`#${persona.demographics.industry.replace(/\s+/g, "")}`);
  }

  return hashtags.slice(0, limit);
}

/**
 * Generate targeting parameters
 */
function generateTargeting(
  persona: Persona,
  platform: string
): Ad["targeting"] {
  const baseTargeting = {
    demographics: {
      ageRange: persona.demographics.ageRange,
      location: persona.demographics.location || "United States",
    },
    interests: persona.psychographics.values.concat(
      persona.behavior.contentPreferences?.slice(0, 3) || []
    ),
    behaviors: persona.behavior.triggers.slice(0, 3),
  };

  // Platform-specific targeting
  if (platform === "linkedin") {
    return {
      ...baseTargeting,
      jobTitles: [persona.demographics.jobTitle],
      industries: persona.demographics.industry ? [persona.demographics.industry] : [],
      companySizes: persona.market === "B2B" ? ["51-200", "201-500", "501-1000", "1000+"] : [],
    };
  }

  return baseTargeting;
}

/**
 * Generate ad variations for A/B testing
 */
function generateVariations(
  baseCopy: { primary: string; headline: string },
  persona: Persona
): Ad["variations"] {
  return [
    {
      id: "variation-a",
      name: "Original",
      copy: baseCopy,
    },
    {
      id: "variation-b",
      name: "Emotional Appeal",
      copy: {
        primary: persona.messaging.emotional,
        headline: `Ready to ${persona.psychographics.goals[0]?.split(" ").slice(0, 3).join(" ")}?`,
      },
    },
    {
      id: "variation-c",
      name: "Logical Appeal",
      copy: {
        primary: persona.messaging.logical,
        headline: baseCopy.headline,
      },
    },
  ];
}

// ============================================================================
// Main Functions
// ============================================================================

/**
 * Generate all ads
 */
async function generateAds(): Promise<void> {
  const postDevDir = getPostDevDir();
  const adsDir = `${postDevDir}/ads`;

  // Load personas
  const personasSummaryPath = `${postDevDir}/personas/summary.json`;
  if (!(await fileExists(personasSummaryPath))) {
    logError("No personas found. Run 'persona-create.ts' first.");
    process.exit(1);
  }

  const personasSummary = await readJson<{
    personas: Array<{ id: string; name: string }>;
  }>(personasSummaryPath);

  if (!personasSummary) {
    logError("Failed to load personas summary.");
    process.exit(1);
  }

  // Load full persona data
  const personas: Persona[] = [];
  for (const p of personasSummary.personas) {
    const personaPath = `${postDevDir}/personas/personas/${p.id}.json`;
    const persona = await readJson<Persona>(personaPath);
    if (persona) {
      personas.push(persona);
    }
  }

  if (personas.length === 0) {
    logError("No persona data found.");
    process.exit(1);
  }

  // Load project info
  const plan = await loadPostDevPlan();
  if (!plan) {
    logError("No post-development plan found.");
    process.exit(1);
  }

  // Get screenshots
  const screenshotDir = `${postDevDir}/screenshots`;
  let screenshots: string[] = [];
  try {
    const files = await Bun.file(`${screenshotDir}/desktop/light`).exists()
      ? (await import("fs/promises")).readdir(`${screenshotDir}/desktop/light`)
      : [];
    screenshots = files
      .filter((f: string) => f.endsWith(".png"))
      .map((f: string) => `${screenshotDir}/desktop/light/${f}`);
  } catch {
    logWarning("No screenshots found. Using placeholders.");
    screenshots = ["placeholder.png"];
  }

  // Create directories
  await ensureDir(adsDir);
  for (const platform of PLATFORM_SPECS) {
    await ensureDir(`${adsDir}/${platform.name}`);
    for (const format of platform.formats) {
      await ensureDir(`${adsDir}/${platform.name}/${format.name}`);
    }
  }

  // Generate ads
  const allAds: Ad[] = [];
  let adIndex = 0;

  logInfo("Generating ads...");

  for (const platform of PLATFORM_SPECS) {
    for (const format of platform.formats) {
      for (const persona of personas) {
        // Generate 2 ads per persona/platform/format combination
        for (let i = 0; i < 2; i++) {
          const ad = generateAd(
            persona,
            platform,
            format,
            plan.project.name,
            plan.project.features || ["Amazing features"],
            screenshots,
            adIndex++
          );

          allAds.push(ad);

          // Save individual ad
          await writeJson(
            `${adsDir}/${platform.name}/${format.name}/${ad.id}.json`,
            ad
          );
        }
      }

      logProgress(`Created ads for ${platform.name}/${format.name}`);
    }
  }

  // Save summary
  const summary = {
    totalAds: allAds.length,
    byPlatform: PLATFORM_SPECS.map((p) => ({
      platform: p.name,
      formats: p.formats.map((f) => f.name),
      count: allAds.filter((a) => a.platform === p.name).length,
    })),
    byPersona: personas.map((p) => ({
      persona: p.id,
      name: p.name,
      count: allAds.filter((a) => a.persona === p.id).length,
    })),
    generatedAt: new Date().toISOString(),
  };

  await writeJson(`${adsDir}/summary.json`, summary);
  await writeJson(`${adsDir}/all-ads.json`, allAds);

  // Update post-dev plan
  plan.tasks.ads.status = "completed";
  plan.tasks.ads.completedAt = new Date().toISOString();
  plan.tasks.ads.output = {
    totalAds: allAds.length,
    platforms: PLATFORM_SPECS.map((p) => p.name),
  };
  await savePostDevPlan(plan);

  logSuccess(`Generated ${allAds.length} ads across ${PLATFORM_SPECS.length} platforms`);
}

/**
 * List existing ads
 */
async function listAds(): Promise<void> {
  const postDevDir = getPostDevDir();
  const summaryPath = `${postDevDir}/ads/summary.json`;

  if (!(await fileExists(summaryPath))) {
    logWarning("No ads found. Run 'ad-generate.ts' first.");
    return;
  }

  const summary = await readJson<{
    totalAds: number;
    byPlatform: Array<{ platform: string; formats: string[]; count: number }>;
    byPersona: Array<{ persona: string; name: string; count: number }>;
    generatedAt: string;
  }>(summaryPath);

  if (!summary) return;

  log("\n📢 Generated Ads\n");
  log(`Total: ${summary.totalAds} ads\n`);

  log("By Platform:");
  for (const p of summary.byPlatform) {
    log(`  📱 ${p.platform}: ${p.count} ads`);
    log(`     Formats: ${p.formats.join(", ")}`);
  }

  log("\nBy Persona:");
  for (const p of summary.byPersona) {
    log(`  👤 ${p.name}: ${p.count} ads`);
  }

  log(`\n📅 Generated: ${summary.generatedAt}`);
}

/**
 * Export ads for specific platform
 */
async function exportAds(platform: string): Promise<void> {
  const postDevDir = getPostDevDir();
  const adsDir = `${postDevDir}/ads`;
  const platformDir = `${adsDir}/${platform.toLowerCase()}`;

  if (!(await fileExists(platformDir))) {
    logError(`No ads found for platform: ${platform}`);
    return;
  }

  const exportDir = `${postDevDir}/exports/ads-${platform.toLowerCase()}`;
  await ensureDir(exportDir);

  // Copy all ads for this platform
  const { readdir, copyFile } = await import("fs/promises");
  const formats = await readdir(platformDir);

  let count = 0;
  for (const format of formats) {
    const formatDir = `${platformDir}/${format}`;
    const files = await readdir(formatDir);

    for (const file of files) {
      if (file.endsWith(".json")) {
        await copyFile(`${formatDir}/${file}`, `${exportDir}/${file}`);
        count++;
      }
    }
  }

  logSuccess(`Exported ${count} ${platform} ads to ${exportDir}`);
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || "create";

  switch (command) {
    case "create":
    case "generate":
      await generateAds();
      break;

    case "list":
      await listAds();
      break;

    case "export": {
      const platform = args._[1] || args.platform;
      if (!platform) {
        logError("Please specify a platform: instagram, facebook, linkedin, twitter");
        process.exit(1);
      }
      await exportAds(platform);
      break;
    }

    default:
      log("Usage: bun run ad-generate.ts [command] [options]");
      log("");
      log("Commands:");
      log("  create, generate    Generate all ads (default)");
      log("  list               List existing ads");
      log("  export <platform>  Export ads for specific platform");
      log("");
      log("Platforms: instagram, facebook, linkedin, twitter");
  }
}

main().catch((error) => {
  logError(`Fatal error: ${error}`);
  process.exit(1);
});
