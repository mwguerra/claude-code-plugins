#!/usr/bin/env bun
/**
 * SEO Analysis Script
 * Analyzes project routes and generates SEO recommendations
 */

import { chromium, type Page } from "playwright";
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
import type { SEOPlan, SEOPageData, PostDevelopmentPlan } from "./types";

// ============================================================================
// Route Discovery
// ============================================================================

interface DiscoveredRoute {
  path: string;
  name: string;
  title?: string;
  description?: string;
  hasContent: boolean;
}

/**
 * Discover routes by crawling the application
 */
async function discoverRoutes(baseUrl: string): Promise<DiscoveredRoute[]> {
  const routes: DiscoveredRoute[] = [];
  const visited = new Set<string>();
  const toVisit: string[] = ["/"];

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  logInfo("Starting route discovery...");

  while (toVisit.length > 0 && visited.size < 50) {
    const path = toVisit.shift()!;
    if (visited.has(path)) continue;
    visited.add(path);

    try {
      const url = new URL(path, baseUrl).toString();
      logProgress(`Crawling: ${path}`);

      await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });

      // Get page info
      const title = await page.title();
      const description = await page
        .$eval('meta[name="description"]', (el) => el.getAttribute("content"))
        .catch(() => undefined);

      // Check if page has meaningful content
      const bodyText = await page.evaluate(() => document.body.innerText);
      const hasContent = bodyText.trim().length > 100;

      routes.push({
        path,
        name: pathToName(path),
        title: title || undefined,
        description: description || undefined,
        hasContent,
      });

      // Find internal links
      const links = await page.$$eval("a[href]", (anchors) =>
        anchors
          .map((a) => a.getAttribute("href"))
          .filter((href): href is string => href !== null)
      );

      for (const href of links) {
        try {
          const linkUrl = new URL(href, url);
          // Only follow internal links
          if (linkUrl.origin === new URL(baseUrl).origin) {
            const linkPath = linkUrl.pathname;
            if (
              !visited.has(linkPath) &&
              !toVisit.includes(linkPath) &&
              !linkPath.includes(".") && // Skip files
              !linkPath.startsWith("/api/") // Skip API routes
            ) {
              toVisit.push(linkPath);
            }
          }
        } catch {
          // Invalid URL, skip
        }
      }
    } catch (error) {
      logWarning(`Failed to crawl ${path}: ${error}`);
    }
  }

  await browser.close();
  logSuccess(`Discovered ${routes.length} routes`);
  return routes;
}

/**
 * Convert path to human-readable name
 */
function pathToName(path: string): string {
  if (path === "/") return "Home";
  return path
    .split("/")
    .filter(Boolean)
    .map((segment) =>
      segment
        .replace(/-/g, " ")
        .replace(/\b\w/g, (c) => c.toUpperCase())
    )
    .join(" - ");
}

// ============================================================================
// SEO Analysis
// ============================================================================

interface SEOIssue {
  type: "error" | "warning" | "suggestion";
  message: string;
  fix?: string;
}

/**
 * Analyze a page for SEO issues
 */
async function analyzePage(
  page: Page,
  route: DiscoveredRoute
): Promise<{ data: SEOPageData; issues: SEOIssue[] }> {
  const issues: SEOIssue[] = [];

  // Extract current SEO data
  const currentTitle = await page.title();
  const currentDescription = await page
    .$eval('meta[name="description"]', (el) => el.getAttribute("content"))
    .catch(() => "");
  const h1 = await page.$eval("h1", (el) => el.textContent).catch(() => "");
  const h2s = await page.$$eval("h2", (els) => els.map((el) => el.textContent));

  // Analyze title
  if (!currentTitle) {
    issues.push({ type: "error", message: "Missing page title" });
  } else if (currentTitle.length < 30) {
    issues.push({
      type: "warning",
      message: `Title too short (${currentTitle.length} chars, recommend 50-60)`,
    });
  } else if (currentTitle.length > 60) {
    issues.push({
      type: "warning",
      message: `Title too long (${currentTitle.length} chars, recommend 50-60)`,
    });
  }

  // Analyze description
  if (!currentDescription) {
    issues.push({ type: "error", message: "Missing meta description" });
  } else if (currentDescription.length < 120) {
    issues.push({
      type: "warning",
      message: `Description too short (${currentDescription.length} chars, recommend 150-160)`,
    });
  } else if (currentDescription.length > 160) {
    issues.push({
      type: "warning",
      message: `Description too long (${currentDescription.length} chars, recommend 150-160)`,
    });
  }

  // Check H1
  if (!h1) {
    issues.push({ type: "error", message: "Missing H1 heading" });
  }

  // Check images
  const images = await page.$$eval("img", (imgs) =>
    imgs.map((img) => ({
      src: img.src,
      alt: img.alt,
      width: img.width,
      height: img.height,
    }))
  );
  const imagesWithoutAlt = images.filter((img) => !img.alt);
  if (imagesWithoutAlt.length > 0) {
    issues.push({
      type: "warning",
      message: `${imagesWithoutAlt.length} images missing alt text`,
    });
  }

  // Check internal links
  const links = await page.$$eval("a", (anchors) =>
    anchors.map((a) => ({
      href: a.href,
      text: a.textContent?.trim() || "",
    }))
  );
  const emptyLinks = links.filter((l) => !l.text);
  if (emptyLinks.length > 0) {
    issues.push({
      type: "warning",
      message: `${emptyLinks.length} links with empty anchor text`,
    });
  }

  // Generate optimized SEO data
  const optimizedTitle = generateOptimizedTitle(route, currentTitle, h1 || "");
  const optimizedDescription = generateOptimizedDescription(
    route,
    currentDescription || "",
    h1 || "",
    h2s
  );
  const keywords = extractKeywords(
    [currentTitle, currentDescription || "", h1 || "", ...h2s].filter(Boolean)
  );

  const data: SEOPageData = {
    route: route.path,
    current: {
      title: currentTitle,
      description: currentDescription || "",
      h1: h1 || "",
      h2s: h2s.filter(Boolean) as string[],
    },
    optimized: {
      title: optimizedTitle,
      description: optimizedDescription,
      keywords,
      openGraph: {
        title: optimizedTitle,
        description: optimizedDescription,
        type: route.path === "/" ? "website" : "article",
      },
      twitter: {
        card: "summary_large_image",
        title: optimizedTitle,
        description: optimizedDescription,
      },
    },
    issues,
    score: calculateSEOScore(issues),
  };

  return { data, issues };
}

/**
 * Generate optimized title
 */
function generateOptimizedTitle(
  route: DiscoveredRoute,
  currentTitle: string,
  h1: string
): string {
  // If current title is good, keep it
  if (currentTitle && currentTitle.length >= 30 && currentTitle.length <= 60) {
    return currentTitle;
  }

  // Use H1 if available
  if (h1 && h1.length >= 20 && h1.length <= 55) {
    return h1;
  }

  // Generate from route name
  return route.name.length <= 55 ? route.name : route.name.substring(0, 52) + "...";
}

/**
 * Generate optimized meta description
 */
function generateOptimizedDescription(
  route: DiscoveredRoute,
  current: string,
  h1: string,
  h2s: (string | null)[]
): string {
  // If current is good, keep it
  if (current && current.length >= 120 && current.length <= 160) {
    return current;
  }

  // Build from available content
  const parts = [h1, ...h2s.filter(Boolean)].filter(Boolean);
  if (parts.length > 0) {
    let desc = parts.join(". ");
    if (desc.length > 160) {
      desc = desc.substring(0, 157) + "...";
    }
    return desc;
  }

  return `Learn more about ${route.name.toLowerCase()}. Discover features, benefits, and how to get started.`;
}

/**
 * Extract keywords from content
 */
function extractKeywords(texts: string[]): string[] {
  const combined = texts.join(" ").toLowerCase();
  const words = combined.split(/\W+/).filter((w) => w.length > 3);

  // Count word frequency
  const freq: Record<string, number> = {};
  for (const word of words) {
    freq[word] = (freq[word] || 0) + 1;
  }

  // Filter common words and sort by frequency
  const stopWords = new Set([
    "this",
    "that",
    "with",
    "from",
    "have",
    "been",
    "were",
    "they",
    "their",
    "what",
    "when",
    "where",
    "which",
    "would",
    "could",
    "should",
    "about",
    "your",
    "more",
    "some",
    "other",
    "into",
    "only",
    "also",
    "just",
    "over",
    "such",
    "like",
    "then",
    "them",
    "these",
    "will",
  ]);

  return Object.entries(freq)
    .filter(([word]) => !stopWords.has(word))
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([word]) => word);
}

/**
 * Calculate SEO score based on issues
 */
function calculateSEOScore(issues: SEOIssue[]): number {
  let score = 100;
  for (const issue of issues) {
    switch (issue.type) {
      case "error":
        score -= 15;
        break;
      case "warning":
        score -= 5;
        break;
      case "suggestion":
        score -= 2;
        break;
    }
  }
  return Math.max(0, score);
}

// ============================================================================
// Asset Generation
// ============================================================================

interface FaviconSpec {
  sizes: string[];
  colors: {
    primary: string;
    background: string;
  };
  style: string;
}

interface OGImageSpec {
  route: string;
  dimensions: { width: number; height: number };
  template: string;
  text: {
    title: string;
    subtitle?: string;
  };
}

/**
 * Generate favicon specification
 */
function generateFaviconSpec(): FaviconSpec {
  return {
    sizes: ["16x16", "32x32", "48x48", "180x180", "192x192", "512x512"],
    colors: {
      primary: "#000000",
      background: "#ffffff",
    },
    style: "minimal",
  };
}

/**
 * Generate OG image specifications for each route
 */
function generateOGImageSpecs(pages: SEOPageData[]): OGImageSpec[] {
  return pages.map((page) => ({
    route: page.route,
    dimensions: { width: 1200, height: 630 },
    template: "default",
    text: {
      title: page.optimized.title,
      subtitle: page.optimized.description.substring(0, 100),
    },
  }));
}

// ============================================================================
// Sitemap Generation
// ============================================================================

/**
 * Generate XML sitemap
 */
function generateSitemap(baseUrl: string, pages: SEOPageData[]): string {
  const lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  ];

  for (const page of pages) {
    const url = new URL(page.route, baseUrl).toString();
    const priority = page.route === "/" ? "1.0" : "0.8";
    const changefreq = page.route === "/" ? "daily" : "weekly";

    lines.push("  <url>");
    lines.push(`    <loc>${url}</loc>`);
    lines.push(`    <changefreq>${changefreq}</changefreq>`);
    lines.push(`    <priority>${priority}</priority>`);
    lines.push("  </url>");
  }

  lines.push("</urlset>");
  return lines.join("\n");
}

/**
 * Generate meta tags HTML snippet
 */
function generateMetaTags(page: SEOPageData, baseUrl: string): string {
  const url = new URL(page.route, baseUrl).toString();

  return `
<!-- Primary Meta Tags -->
<title>${page.optimized.title}</title>
<meta name="title" content="${page.optimized.title}">
<meta name="description" content="${page.optimized.description}">
<meta name="keywords" content="${page.optimized.keywords.join(", ")}">

<!-- Open Graph / Facebook -->
<meta property="og:type" content="${page.optimized.openGraph?.type || "website"}">
<meta property="og:url" content="${url}">
<meta property="og:title" content="${page.optimized.openGraph?.title || page.optimized.title}">
<meta property="og:description" content="${page.optimized.openGraph?.description || page.optimized.description}">
<meta property="og:image" content="${baseUrl}/og-images${page.route === "/" ? "/home" : page.route}.png">

<!-- Twitter -->
<meta property="twitter:card" content="${page.optimized.twitter?.card || "summary_large_image"}">
<meta property="twitter:url" content="${url}">
<meta property="twitter:title" content="${page.optimized.twitter?.title || page.optimized.title}">
<meta property="twitter:description" content="${page.optimized.twitter?.description || page.optimized.description}">
<meta property="twitter:image" content="${baseUrl}/og-images${page.route === "/" ? "/home" : page.route}.png">
`.trim();
}

// ============================================================================
// Main Functions
// ============================================================================

/**
 * Run full SEO analysis
 */
async function runSEOAnalysis(baseUrl: string): Promise<SEOPlan> {
  const postDevDir = getPostDevDir();
  const seoDir = `${postDevDir}/seo`;

  await ensureDir(seoDir);
  await ensureDir(`${seoDir}/pages`);
  await ensureDir(`${seoDir}/assets`);

  // Discover routes
  const routes = await discoverRoutes(baseUrl);

  // Analyze each route
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  const pages: SEOPageData[] = [];
  let totalScore = 0;

  for (const route of routes) {
    try {
      logProgress(`Analyzing: ${route.path}`);
      const url = new URL(route.path, baseUrl).toString();
      await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });

      const { data } = await analyzePage(page, route);
      pages.push(data);
      totalScore += data.score;

      // Save individual page analysis
      await writeJson(`${seoDir}/pages/${route.name.toLowerCase().replace(/\s+/g, "-")}.json`, data);
    } catch (error) {
      logWarning(`Failed to analyze ${route.path}: ${error}`);
    }
  }

  await browser.close();

  // Generate assets
  const faviconSpec = generateFaviconSpec();
  const ogImageSpecs = generateOGImageSpecs(pages);

  await writeJson(`${seoDir}/assets/favicon-spec.json`, faviconSpec);
  await writeJson(`${seoDir}/assets/og-images-spec.json`, ogImageSpecs);

  // Generate sitemap
  const sitemap = generateSitemap(baseUrl, pages);
  await Bun.write(`${seoDir}/sitemap.xml`, sitemap);

  // Generate meta tags for each page
  let allMetaTags = "";
  for (const pageData of pages) {
    allMetaTags += `\n\n<!-- ${pageData.route} -->\n`;
    allMetaTags += generateMetaTags(pageData, baseUrl);
  }
  await Bun.write(`${seoDir}/meta-tags.html`, allMetaTags.trim());

  // Create SEO plan
  const plan: SEOPlan = {
    baseUrl,
    discoveredRoutes: routes.map((r) => r.path),
    pages,
    assets: {
      favicon: faviconSpec,
      ogImages: ogImageSpecs,
    },
    sitemap: `${seoDir}/sitemap.xml`,
    averageScore: pages.length > 0 ? Math.round(totalScore / pages.length) : 0,
    generatedAt: new Date().toISOString(),
  };

  // Save plan
  await writeJson(`${seoDir}/seo-plan.json`, plan);

  // Update main post-dev plan
  const postDevPlan = await loadPostDevPlan();
  if (postDevPlan) {
    postDevPlan.tasks.seo.status = "completed";
    postDevPlan.tasks.seo.completedAt = new Date().toISOString();
    postDevPlan.tasks.seo.output = {
      pagesAnalyzed: pages.length,
      averageScore: plan.averageScore,
      sitemapPath: plan.sitemap,
    };
    await savePostDevPlan(postDevPlan);
  }

  logSuccess(`SEO analysis complete! Average score: ${plan.averageScore}/100`);
  return plan;
}

/**
 * Show SEO status
 */
async function showStatus(): Promise<void> {
  const postDevDir = getPostDevDir();
  const planPath = `${postDevDir}/seo/seo-plan.json`;

  if (!(await fileExists(planPath))) {
    logWarning("No SEO analysis found. Run 'seo-analyze.ts' first.");
    return;
  }

  const plan = await readJson<SEOPlan>(planPath);
  if (!plan) return;

  log("\n📊 SEO Analysis Status\n");
  log(`Base URL: ${plan.baseUrl}`);
  log(`Routes analyzed: ${plan.pages.length}`);
  log(`Average score: ${plan.averageScore}/100`);
  log(`Generated: ${plan.generatedAt}`);

  log("\n📄 Page Scores:");
  for (const page of plan.pages) {
    const emoji = page.score >= 80 ? "✅" : page.score >= 60 ? "⚠️" : "❌";
    log(`  ${emoji} ${page.route}: ${page.score}/100`);
    if (page.issues.length > 0) {
      for (const issue of page.issues.slice(0, 3)) {
        log(`     - ${issue.message}`);
      }
    }
  }

  log(`\n📁 Output files:`);
  log(`  - ${postDevDir}/seo/seo-plan.json`);
  log(`  - ${postDevDir}/seo/sitemap.xml`);
  log(`  - ${postDevDir}/seo/meta-tags.html`);
  log(`  - ${postDevDir}/seo/pages/*.json`);
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || "run";

  switch (command) {
    case "run":
    case "analyze": {
      let baseUrl = args["base-url"] || args.url;

      if (!baseUrl) {
        const plan = await loadPostDevPlan();
        baseUrl = plan?.config.baseUrl;
      }

      if (!baseUrl) {
        logError("No base URL provided. Use --base-url or run 'init.ts' first.");
        process.exit(1);
      }

      await runSEOAnalysis(baseUrl);
      break;
    }

    case "status":
      await showStatus();
      break;

    default:
      log("Usage: bun run seo-analyze.ts [command] [options]");
      log("");
      log("Commands:");
      log("  run, analyze  Run SEO analysis (default)");
      log("  status        Show analysis status");
      log("");
      log("Options:");
      log("  --base-url    Base URL of the application");
  }
}

main().catch((error) => {
  logError(`Fatal error: ${error}`);
  process.exit(1);
});
