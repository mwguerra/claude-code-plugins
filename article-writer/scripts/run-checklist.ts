#!/usr/bin/env bun
/**
 * Run quality checklists on article folder
 * Usage: bun run run-checklist.ts <article-folder> [--fix] [--json]
 */

import { readFile, readdir, stat, writeFile } from "fs/promises";
import { join } from "path";

const args = process.argv.slice(2);
const folder = args.find(a => !a.startsWith("--"));
const jsonOutput = args.includes("--json");
const autoFix = args.includes("--fix");

if (!folder) {
  console.error("Usage: bun run run-checklist.ts <article-folder> [--fix] [--json]");
  process.exit(1);
}

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function getLatestDraft(): Promise<string | null> {
  const draftsDir = join(folder, "03_drafts");
  if (!(await exists(draftsDir))) return null;
  
  const files = await readdir(draftsDir);
  const drafts = files.filter(f => f.startsWith("draft_") && f.endsWith(".md"));
  if (!drafts.length) return null;
  
  drafts.sort().reverse();
  return join(draftsDir, drafts[0]);
}

interface CheckResult {
  name: string;
  passed: boolean;
  issues: string[];
  suggestions: string[];
}

async function checkAccuracy(): Promise<CheckResult> {
  const issues: string[] = [];
  const suggestions: string[] = [];

  // Check sources
  const sourcesPath = join(folder, "02_research", "sources.md");
  if (await exists(sourcesPath)) {
    const content = await readFile(sourcesPath, "utf-8");
    const primarySources = (content.match(/\| P\d+ \|/g) || []).length;
    const secondarySources = (content.match(/\| S\d+ \|/g) || []).length;
    
    if (primarySources === 0) {
      issues.push("No primary sources documented");
      suggestions.push("Add official documentation or authoritative sources");
    } else if (primarySources < 2) {
      suggestions.push(`Only ${primarySources} primary source - consider adding more`);
    }
  } else {
    issues.push("Missing sources.md");
  }

  // Check fact verification
  const factsPath = join(folder, "02_research", "fact_verification.md");
  if (await exists(factsPath)) {
    const content = await readFile(factsPath, "utf-8");
    const unchecked = (content.match(/\[ \]/g) || []).length;
    if (unchecked > 0) {
      issues.push(`${unchecked} unverified items in fact_verification.md`);
    }
  }

  // Check code samples
  const codePath = join(folder, "02_research", "code_samples");
  if (await exists(codePath)) {
    const files = await readdir(codePath);
    if (files.length === 0) {
      suggestions.push("No code samples in code_samples folder");
    }
  }

  return { 
    name: "Accuracy", 
    passed: issues.length === 0, 
    issues,
    suggestions
  };
}

async function checkReadability(): Promise<CheckResult> {
  const issues: string[] = [];
  const suggestions: string[] = [];
  
  const draftPath = await getLatestDraft();
  if (!draftPath) {
    return { name: "Readability", passed: false, issues: ["No draft found"], suggestions: [] };
  }

  const content = await readFile(draftPath, "utf-8");
  const lines = content.split("\n");

  // Check H2 sections
  const h2s = lines.filter(l => l.startsWith("## ")).length;
  if (h2s < 2) {
    issues.push(`Only ${h2s} H2 section(s) - article needs more structure`);
  }

  // Check paragraph length (rough approximation)
  let longParagraphs = 0;
  let currentParagraph = "";
  
  for (const line of lines) {
    if (line.trim() === "") {
      if (currentParagraph) {
        const sentences = currentParagraph.split(/[.!?]+/).filter(s => s.trim()).length;
        if (sentences > 4) longParagraphs++;
        currentParagraph = "";
      }
    } else if (!line.startsWith("#") && !line.startsWith("```") && !line.startsWith("|")) {
      currentParagraph += " " + line;
    }
  }

  if (longParagraphs > 0) {
    issues.push(`${longParagraphs} paragraph(s) exceed 4 sentences`);
  }

  // Check for hook (first 150 words should be engaging)
  const firstContent = content.split("##")[0];
  const wordCount = firstContent.split(/\s+/).length;
  if (wordCount < 50) {
    suggestions.push("Introduction seems short - ensure hook is compelling");
  }

  // Check heading hierarchy
  const h1s = lines.filter(l => l.match(/^# [^#]/)).length;
  const h3s = lines.filter(l => l.startsWith("### ")).length;
  if (h3s > 0 && h2s === 0) {
    issues.push("H3 headings without H2 - fix heading hierarchy");
  }

  return { name: "Readability", passed: issues.length === 0, issues, suggestions };
}

async function checkVoice(): Promise<CheckResult> {
  const issues: string[] = [];
  const suggestions: string[] = [];

  const draftPath = await getLatestDraft();
  if (!draftPath) {
    return { name: "Voice", passed: false, issues: ["No draft found"], suggestions: [] };
  }

  const content = await readFile(draftPath, "utf-8").then(c => c.toLowerCase());

  // Common filler/weak words
  const weakWords: Record<string, number> = {
    "actually": (content.match(/\bactually\b/g) || []).length,
    "basically": (content.match(/\bbasically\b/g) || []).length,
    "simply": (content.match(/\bsimply\b/g) || []).length,
    "just": (content.match(/\bjust\b/g) || []).length,
    "very": (content.match(/\bvery\b/g) || []).length,
    "really": (content.match(/\breally\b/g) || []).length,
  };

  for (const [word, count] of Object.entries(weakWords)) {
    if (count > 3) {
      suggestions.push(`"${word}" used ${count} times - consider reducing`);
    }
  }

  // Check for passive voice indicators
  const passivePatterns = (content.match(/\b(was|were|been|being|is|are|am)\s+\w+ed\b/g) || []).length;
  if (passivePatterns > 5) {
    suggestions.push(`${passivePatterns} potential passive voice instances - prefer active voice`);
  }

  // Check voice profile exists
  const voicePath = join(folder, "00_context", "voice_profile.md");
  if (!(await exists(voicePath))) {
    issues.push("No voice profile in article context");
  } else {
    const voiceContent = await readFile(voicePath, "utf-8");
    if (voiceContent.includes("Create profile with")) {
      issues.push("Voice profile not configured");
    }
  }

  return { name: "Voice", passed: issues.length === 0, issues, suggestions };
}

async function checkSEO(): Promise<CheckResult> {
  const issues: string[] = [];
  const suggestions: string[] = [];

  const draftPath = await getLatestDraft();
  if (!draftPath) {
    return { name: "SEO", passed: false, issues: ["No draft found"], suggestions: [] };
  }

  const content = await readFile(draftPath, "utf-8");

  // Check frontmatter
  if (!content.startsWith("---")) {
    issues.push("Missing YAML frontmatter");
  } else {
    const frontmatterEnd = content.indexOf("---", 3);
    if (frontmatterEnd !== -1) {
      const frontmatter = content.slice(0, frontmatterEnd);
      
      if (!frontmatter.includes("title:")) {
        issues.push("Missing title in frontmatter");
      }
      if (!frontmatter.includes("description:")) {
        issues.push("Missing description in frontmatter");
      }
      
      // Check title length
      const titleMatch = frontmatter.match(/title:\s*["']?([^"'\n]+)/);
      if (titleMatch && titleMatch[1].length > 60) {
        suggestions.push(`Title is ${titleMatch[1].length} chars - consider under 60 for SEO`);
      }
      
      // Check description length  
      const descMatch = frontmatter.match(/description:\s*["']?([^"'\n]+)/);
      if (descMatch) {
        const descLen = descMatch[1].length;
        if (descLen < 120 || descLen > 160) {
          suggestions.push(`Description is ${descLen} chars - aim for 150-160`);
        }
      }
    }
  }

  // Check for images without alt text (basic check)
  const images = content.match(/!\[([^\]]*)\]/g) || [];
  const emptyAlts = images.filter(img => img === "![]").length;
  if (emptyAlts > 0) {
    issues.push(`${emptyAlts} image(s) missing alt text`);
  }

  return { name: "SEO", passed: issues.length === 0, issues, suggestions };
}

async function updateChecklistFile(name: string, result: CheckResult): Promise<void> {
  const checklistPath = join(folder, "04_review", `checklist_${name.toLowerCase()}.md`);
  if (!(await exists(checklistPath))) return;

  let content = await readFile(checklistPath, "utf-8");
  
  // Add automated results section
  const resultsSection = `
## Automated Check Results

**Status:** ${result.passed ? "✅ Passed" : "⚠️ Issues Found"}
**Run:** ${new Date().toISOString()}

${result.issues.length > 0 ? "### Issues\n" + result.issues.map(i => `- ❌ ${i}`).join("\n") : ""}

${result.suggestions.length > 0 ? "### Suggestions\n" + result.suggestions.map(s => `- 💡 ${s}`).join("\n") : ""}
`;

  // Remove old results if present
  const marker = "## Automated Check Results";
  const markerIdx = content.indexOf(marker);
  if (markerIdx !== -1) {
    content = content.slice(0, markerIdx);
  }

  await writeFile(checklistPath, content.trim() + "\n" + resultsSection);
}

async function run() {
  if (!jsonOutput) {
    console.log(`\n📋 Checking: ${folder}\n`);
  }

  const checks = [
    await checkAccuracy(),
    await checkReadability(),
    await checkVoice(),
    await checkSEO(),
  ];

  let allPassed = true;

  if (jsonOutput) {
    console.log(JSON.stringify({ folder, checks, allPassed: checks.every(c => c.passed) }));
  } else {
    for (const c of checks) {
      const icon = c.passed ? "✅" : "⚠️";
      console.log(`${icon} ${c.name}`);
      
      for (const issue of c.issues) {
        console.log(`   ❌ ${issue}`);
        allPassed = false;
      }
      
      for (const suggestion of c.suggestions) {
        console.log(`   💡 ${suggestion}`);
      }

      if (autoFix) {
        await updateChecklistFile(c.name, c);
      }
    }

    console.log("\n" + (allPassed ? "✅ All checks passed" : "⚠️ Issues found - review above"));
    
    if (autoFix) {
      console.log("📝 Updated checklist files with results");
    }
  }
}

run().catch(e => {
  console.error("Error:", e);
  process.exit(1);
});
