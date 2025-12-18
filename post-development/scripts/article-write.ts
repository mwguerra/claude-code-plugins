#!/usr/bin/env bun
/**
 * Article Writing Script
 * Creates showcase articles for content marketing
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
import type { Article, Persona, SEOPlan } from "./types";

// ============================================================================
// Article Types and Templates
// ============================================================================

type ArticleType = "problem-solution" | "feature-deep-dive" | "case-study";

interface ArticleTemplate {
  type: ArticleType;
  stage: "awareness" | "consideration" | "decision";
  wordCount: { min: number; max: number };
  structure: {
    hook: { words: number; purpose: string };
    sections: Array<{
      name: string;
      words: number;
      purpose: string;
      required: boolean;
    }>;
    conclusion: { words: number; purpose: string };
  };
  tone: string;
  imageCount: { min: number; max: number };
}

const ARTICLE_TEMPLATES: Record<ArticleType, ArticleTemplate> = {
  "problem-solution": {
    type: "problem-solution",
    stage: "awareness",
    wordCount: { min: 1500, max: 2000 },
    structure: {
      hook: {
        words: 100,
        purpose: "Relatable scenario showing the problem",
      },
      sections: [
        {
          name: "The Problem",
          words: 300,
          purpose: "Deep dive into the pain point",
          required: true,
        },
        {
          name: "Why It Matters",
          words: 250,
          purpose: "Stakes and consequences",
          required: true,
        },
        {
          name: "Common Solutions",
          words: 300,
          purpose: "What people try (and why it fails)",
          required: true,
        },
        {
          name: "A Better Way",
          words: 400,
          purpose: "Introduce the solution approach",
          required: true,
        },
        {
          name: "How It Works",
          words: 300,
          purpose: "High-level explanation",
          required: true,
        },
      ],
      conclusion: {
        words: 150,
        purpose: "Call to action and next steps",
      },
    },
    tone: "Empathetic, understanding, solution-oriented",
    imageCount: { min: 3, max: 5 },
  },
  "feature-deep-dive": {
    type: "feature-deep-dive",
    stage: "consideration",
    wordCount: { min: 1500, max: 2000 },
    structure: {
      hook: {
        words: 80,
        purpose: "Why this feature matters",
      },
      sections: [
        {
          name: "Overview",
          words: 200,
          purpose: "What the feature does",
          required: true,
        },
        {
          name: "Key Benefits",
          words: 300,
          purpose: "Benefits with examples",
          required: true,
        },
        {
          name: "How to Use It",
          words: 400,
          purpose: "Step-by-step guide with screenshots",
          required: true,
        },
        {
          name: "Best Practices",
          words: 250,
          purpose: "Tips for getting the most value",
          required: true,
        },
        {
          name: "Advanced Tips",
          words: 200,
          purpose: "Power user techniques",
          required: false,
        },
      ],
      conclusion: {
        words: 150,
        purpose: "Summary and CTA",
      },
    },
    tone: "Educational, practical, enthusiastic",
    imageCount: { min: 4, max: 7 },
  },
  "case-study": {
    type: "case-study",
    stage: "decision",
    wordCount: { min: 1500, max: 2000 },
    structure: {
      hook: {
        words: 100,
        purpose: "Impressive result or transformation",
      },
      sections: [
        {
          name: "The Challenge",
          words: 250,
          purpose: "Customer's situation before",
          required: true,
        },
        {
          name: "Why They Chose Us",
          words: 200,
          purpose: "Decision process and criteria",
          required: true,
        },
        {
          name: "Implementation",
          words: 300,
          purpose: "How they got started",
          required: true,
        },
        {
          name: "Results",
          words: 300,
          purpose: "Quantifiable outcomes",
          required: true,
        },
        {
          name: "Key Takeaways",
          words: 200,
          purpose: "Lessons and insights",
          required: true,
        },
      ],
      conclusion: {
        words: 150,
        purpose: "Quote from customer and CTA",
      },
    },
    tone: "Professional, credible, inspiring",
    imageCount: { min: 2, max: 4 },
  },
};

// ============================================================================
// Content Generation
// ============================================================================

interface ArticleSection {
  heading: string;
  purpose: string;
  wordCount: number;
  content: string;
  images: string[];
}

interface GeneratedArticle {
  metadata: {
    type: ArticleType;
    persona: string;
    stage: string;
    readTime: number;
    wordCount: number;
  };
  seo: {
    metaTitle: string;
    metaDescription: string;
    keywords: string[];
  };
  structure: {
    hook: string;
    sections: ArticleSection[];
    conclusion: string;
  };
  ctas: Array<{
    type: "soft" | "related" | "strong";
    text: string;
    placement: string;
  }>;
  images: Array<{
    id: string;
    description: string;
    placement: string;
    alt: string;
  }>;
}

/**
 * Generate article outline
 */
function generateOutline(
  template: ArticleTemplate,
  persona: Persona,
  projectName: string,
  features: string[],
  keywords: string[]
): string {
  let outline = `# Article Outline: ${template.type}\n\n`;
  outline += `**Target Persona:** ${persona.name} (${persona.demographics.jobTitle})\n`;
  outline += `**Funnel Stage:** ${template.stage}\n`;
  outline += `**Word Count:** ${template.wordCount.min}-${template.wordCount.max}\n`;
  outline += `**Tone:** ${template.tone}\n\n`;

  outline += `## Hook (${template.structure.hook.words} words)\n`;
  outline += `Purpose: ${template.structure.hook.purpose}\n\n`;

  for (const section of template.structure.sections) {
    outline += `## ${section.name} (${section.words} words)\n`;
    outline += `Purpose: ${section.purpose}\n`;
    outline += `Required: ${section.required ? "Yes" : "No"}\n\n`;
  }

  outline += `## Conclusion (${template.structure.conclusion.words} words)\n`;
  outline += `Purpose: ${template.structure.conclusion.purpose}\n\n`;

  outline += `## SEO Keywords\n`;
  for (const keyword of keywords.slice(0, 5)) {
    outline += `- ${keyword}\n`;
  }

  outline += `\n## CTA Placements\n`;
  outline += `- Soft CTA after section 2\n`;
  outline += `- Related content CTA after section 4\n`;
  outline += `- Strong CTA in conclusion\n`;

  return outline;
}

/**
 * Generate placeholder content for article
 */
function generatePlaceholderContent(
  template: ArticleTemplate,
  persona: Persona,
  projectName: string,
  features: string[],
  keywords: string[]
): GeneratedArticle {
  const primaryKeyword = keywords[0] || "solution";
  const primaryFeature = features[0] || "powerful features";
  const challenge = persona.psychographics.challenges[0] || "common challenges";

  // Generate hook based on type
  let hook: string;
  switch (template.type) {
    case "problem-solution":
      hook = `You're staring at your screen, frustrated. ${challenge} has eaten up another hour of your day. Sound familiar? You're not alone. Thousands of ${persona.demographics.jobTitle}s face this exact scenario every single day. But what if there was a better way?`;
      break;
    case "feature-deep-dive":
      hook = `${primaryFeature} isn't just another checkbox on a feature list—it's the difference between spending hours on manual work and having more time for what actually matters. Here's how to make it work for you.`;
      break;
    case "case-study":
      hook = `When [Company Name] first reached out to us, they were struggling with ${challenge}. Six months later, they've reduced their workload by 50% and saved over $100,000. This is their story.`;
      break;
  }

  // Generate sections
  const sections: ArticleSection[] = template.structure.sections.map((s, i) => ({
    heading: s.name,
    purpose: s.purpose,
    wordCount: s.words,
    content: `[Content for "${s.name}" section - approximately ${s.words} words about ${s.purpose.toLowerCase()}. Focus on ${primaryKeyword} and how ${projectName} addresses ${persona.demographics.jobTitle}'s needs.]`,
    images: i % 2 === 0 ? [`image-${i + 1}.png`] : [],
  }));

  // Generate conclusion
  const conclusion = `${projectName} transforms how ${persona.demographics.jobTitle}s handle ${challenge.toLowerCase()}. With ${primaryFeature.toLowerCase()}, you can finally focus on what matters most.\n\nReady to see the difference for yourself? [CTA: Start your free trial today]`;

  // Calculate word count and read time
  const wordCount = template.wordCount.min + Math.floor(Math.random() * (template.wordCount.max - template.wordCount.min));
  const readTime = Math.ceil(wordCount / 200);

  return {
    metadata: {
      type: template.type,
      persona: persona.id,
      stage: template.stage,
      readTime,
      wordCount,
    },
    seo: {
      metaTitle: `${primaryKeyword.charAt(0).toUpperCase() + primaryKeyword.slice(1)}: A Complete Guide for ${persona.demographics.jobTitle}s | ${projectName}`,
      metaDescription: `Discover how ${projectName} helps ${persona.demographics.jobTitle}s overcome ${challenge.toLowerCase()}. Learn actionable strategies and see real results.`,
      keywords: keywords.slice(0, 8),
    },
    structure: {
      hook,
      sections,
      conclusion,
    },
    ctas: [
      {
        type: "soft",
        text: "Want to learn more? Check out our getting started guide.",
        placement: "After section 2",
      },
      {
        type: "related",
        text: `Related: How ${persona.name} solved ${challenge}`,
        placement: "After section 4",
      },
      {
        type: "strong",
        text: "Start your free trial today",
        placement: "Conclusion",
      },
    ],
    images: [
      {
        id: "hero-image",
        description: `Hero image showing ${projectName} interface`,
        placement: "Top of article",
        alt: `${projectName} dashboard overview`,
      },
      {
        id: "feature-screenshot",
        description: `Screenshot demonstrating ${primaryFeature}`,
        placement: "How It Works section",
        alt: `${primaryFeature} in action`,
      },
      {
        id: "results-chart",
        description: "Chart or graph showing results/benefits",
        placement: "Results/Benefits section",
        alt: `Results achieved with ${projectName}`,
      },
    ],
  };
}

/**
 * Generate full article markdown
 */
function generateArticleMarkdown(article: GeneratedArticle, projectName: string): string {
  let md = `# ${article.seo.metaTitle.split("|")[0].trim()}\n\n`;
  md += `*${article.metadata.readTime} min read*\n\n`;
  md += `---\n\n`;

  // Hook
  md += `${article.structure.hook}\n\n`;

  // Sections
  for (let i = 0; i < article.structure.sections.length; i++) {
    const section = article.structure.sections[i];
    md += `## ${section.heading}\n\n`;
    md += `${section.content}\n\n`;

    // Add images
    for (const img of section.images) {
      md += `![${img}](./images/${img})\n\n`;
    }

    // Add CTAs at appropriate positions
    const cta = article.ctas.find((c) => c.placement.includes(`section ${i + 1}`));
    if (cta) {
      md += `> 💡 **${cta.type === "soft" ? "Pro Tip" : cta.type === "related" ? "Related" : "Get Started"}:** ${cta.text}\n\n`;
    }
  }

  // Conclusion
  md += `## Conclusion\n\n`;
  md += `${article.structure.conclusion}\n\n`;

  // Final CTA
  const finalCta = article.ctas.find((c) => c.placement === "Conclusion");
  if (finalCta) {
    md += `---\n\n`;
    md += `**Ready to transform your workflow?** [${finalCta.text}](/${projectName.toLowerCase().replace(/\s+/g, "-")}/signup)\n`;
  }

  return md;
}

// ============================================================================
// Main Functions
// ============================================================================

/**
 * Create all articles
 */
async function createArticles(): Promise<void> {
  const postDevDir = getPostDevDir();
  const articlesDir = `${postDevDir}/articles`;

  await ensureDir(articlesDir);

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

  // Get primary persona
  const primaryPersonaInfo = personasSummary.personas.find((p) => p.type === "primary");
  if (!primaryPersonaInfo) {
    logError("No primary persona found.");
    process.exit(1);
  }

  const persona = await readJson<Persona>(
    `${postDevDir}/personas/personas/${primaryPersonaInfo.id}.json`
  );
  if (!persona) {
    logError("Failed to load primary persona.");
    process.exit(1);
  }

  // Load SEO data for keywords
  const seoPath = `${postDevDir}/seo/seo-plan.json`;
  let keywords: string[] = [];
  if (await fileExists(seoPath)) {
    const seo = await readJson<SEOPlan>(seoPath);
    if (seo) {
      keywords = seo.pages.flatMap((p) => p.optimized.keywords).slice(0, 15);
    }
  }
  if (keywords.length === 0) {
    keywords = ["productivity", "efficiency", "automation", "workflow", "solution"];
  }

  // Load project info
  const plan = await loadPostDevPlan();
  if (!plan) {
    logError("No post-development plan found.");
    process.exit(1);
  }

  const projectName = plan.project.name;
  const features = plan.project.features || ["Amazing features", "Easy to use", "Great support"];

  logInfo("Creating articles...");

  // Generate all 3 article types
  const articleTypes: ArticleType[] = ["problem-solution", "feature-deep-dive", "case-study"];
  const articles: Article[] = [];

  for (let i = 0; i < articleTypes.length; i++) {
    const type = articleTypes[i];
    const template = ARTICLE_TEMPLATES[type];
    const articleNum = i + 1;

    logProgress(`Creating article ${articleNum}: ${type}`);

    // Create article directory
    const articleDir = `${articlesDir}/article-${articleNum}`;
    await ensureDir(articleDir);
    await ensureDir(`${articleDir}/images`);

    // Generate outline
    const outline = generateOutline(template, persona, projectName, features, keywords);
    await Bun.write(`${articleDir}/outline.md`, outline);

    // Generate article content
    const generated = generatePlaceholderContent(
      template,
      persona,
      projectName,
      features,
      keywords
    );

    // Save article JSON
    const article: Article = {
      id: `article-${articleNum}`,
      type,
      title: generated.seo.metaTitle.split("|")[0].trim(),
      persona: persona.id,
      stage: template.stage,
      wordCount: generated.metadata.wordCount,
      readTime: generated.metadata.readTime,
      seo: generated.seo,
      sections: generated.structure.sections.map((s) => ({
        heading: s.heading,
        content: s.content,
        wordCount: s.wordCount,
      })),
      ctas: generated.ctas,
      images: generated.images,
      createdAt: new Date().toISOString(),
    };

    await writeJson(`${articleDir}/article.json`, article);
    articles.push(article);

    // Generate markdown
    const markdown = generateArticleMarkdown(generated, projectName);
    await Bun.write(`${articleDir}/article.md`, markdown);
  }

  // Save summary
  const summary = {
    totalArticles: articles.length,
    articles: articles.map((a) => ({
      id: a.id,
      type: a.type,
      title: a.title,
      stage: a.stage,
      wordCount: a.wordCount,
      readTime: a.readTime,
    })),
    persona: {
      id: persona.id,
      name: persona.name,
    },
    generatedAt: new Date().toISOString(),
  };

  await writeJson(`${articlesDir}/summary.json`, summary);

  // Update post-dev plan
  plan.tasks.articles.status = "completed";
  plan.tasks.articles.completedAt = new Date().toISOString();
  plan.tasks.articles.output = {
    articleCount: articles.length,
    types: articleTypes,
  };
  await savePostDevPlan(plan);

  logSuccess(`Created ${articles.length} articles`);
}

/**
 * List existing articles
 */
async function listArticles(): Promise<void> {
  const postDevDir = getPostDevDir();
  const summaryPath = `${postDevDir}/articles/summary.json`;

  if (!(await fileExists(summaryPath))) {
    logWarning("No articles found. Run 'article-write.ts' first.");
    return;
  }

  const summary = await readJson<{
    totalArticles: number;
    articles: Array<{
      id: string;
      type: string;
      title: string;
      stage: string;
      wordCount: number;
      readTime: number;
    }>;
    persona: { id: string; name: string };
    generatedAt: string;
  }>(summaryPath);

  if (!summary) return;

  log("\n📝 Generated Articles\n");

  for (const article of summary.articles) {
    const stageEmoji =
      article.stage === "awareness"
        ? "🔍"
        : article.stage === "consideration"
          ? "🤔"
          : "✅";

    log(`${stageEmoji} ${article.title}`);
    log(`   Type: ${article.type}`);
    log(`   Stage: ${article.stage}`);
    log(`   Words: ${article.wordCount} (~${article.readTime} min read)`);
    log("");
  }

  log(`👤 Target Persona: ${summary.persona.name}`);
  log(`📅 Generated: ${summary.generatedAt}`);
}

/**
 * Export articles for publishing
 */
async function exportArticles(): Promise<void> {
  const postDevDir = getPostDevDir();
  const articlesDir = `${postDevDir}/articles`;
  const exportDir = `${postDevDir}/exports/articles`;

  await ensureDir(exportDir);

  const { readdir, copyFile } = await import("fs/promises");

  // Copy all article markdown files
  const articleDirs = (await readdir(articlesDir)).filter((d) => d.startsWith("article-"));

  for (const dir of articleDirs) {
    const srcDir = `${articlesDir}/${dir}`;
    const destDir = `${exportDir}/${dir}`;
    await ensureDir(destDir);
    await ensureDir(`${destDir}/images`);

    // Copy markdown
    if (await fileExists(`${srcDir}/article.md`)) {
      await copyFile(`${srcDir}/article.md`, `${destDir}/article.md`);
    }

    // Copy JSON
    if (await fileExists(`${srcDir}/article.json`)) {
      await copyFile(`${srcDir}/article.json`, `${destDir}/article.json`);
    }
  }

  logSuccess(`Exported ${articleDirs.length} articles to ${exportDir}`);
}

// ============================================================================
// CLI
// ============================================================================

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || "create";

  switch (command) {
    case "create":
      await createArticles();
      break;

    case "list":
      await listArticles();
      break;

    case "export":
      await exportArticles();
      break;

    default:
      log("Usage: bun run article-write.ts [command]");
      log("");
      log("Commands:");
      log("  create    Generate all articles (default)");
      log("  list      List existing articles");
      log("  export    Export articles for publishing");
  }
}

main().catch((error) => {
  logError(`Fatal error: ${error}`);
  process.exit(1);
});
