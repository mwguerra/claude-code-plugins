/**
 * Run quality checklists on article folder
 */

import { readFile, readdir, stat } from "fs/promises";
import { join } from "path";

const folder = process.argv[2];

if (!folder) {
  console.error("Usage: bun run run-checklist.ts <article-folder>");
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
  const drafts = files.filter((f) => f.startsWith("draft_") && f.endsWith(".md"));
  if (!drafts.length) return null;
  drafts.sort().reverse();
  return join(draftsDir, drafts[0]);
}

interface Result {
  name: string;
  passed: boolean;
  issues: string[];
}

async function checkAccuracy(): Promise<Result> {
  const issues: string[] = [];
  const sourcesPath = join(folder, "02_research", "sources.md");
  if (await exists(sourcesPath)) {
    const content = await readFile(sourcesPath, "utf-8");
    const sources = (content.match(/\| [PS]\d+ \|/g) || []).length;
    if (sources < 2) issues.push(`Only ${sources} sources`);
  } else {
    issues.push("No sources.md");
  }
  return { name: "Accuracy", passed: !issues.length, issues };
}

async function checkReadability(): Promise<Result> {
  const issues: string[] = [];
  const draftPath = await getLatestDraft();
  if (!draftPath) return { name: "Readability", passed: false, issues: ["No draft"] };
  const content = await readFile(draftPath, "utf-8");
  const h2s = (content.match(/^## /gm) || []).length;
  if (h2s < 2) issues.push(`Only ${h2s} H2 sections`);
  return { name: "Readability", passed: !issues.length, issues };
}

async function checkVoice(): Promise<Result> {
  const issues: string[] = [];
  const draftPath = await getLatestDraft();
  if (!draftPath) return { name: "Voice", passed: false, issues: ["No draft"] };
  const content = await readFile(draftPath, "utf-8");
  const actuallyCount = (content.match(/\bactually\b/gi) || []).length;
  if (actuallyCount > 2) issues.push(`"actually" used ${actuallyCount}x`);
  return { name: "Voice", passed: !issues.length, issues };
}

async function checkSEO(): Promise<Result> {
  const issues: string[] = [];
  const draftPath = await getLatestDraft();
  if (!draftPath) return { name: "SEO", passed: false, issues: ["No draft"] };
  const content = await readFile(draftPath, "utf-8");
  if (!content.startsWith("---")) issues.push("Missing frontmatter");
  return { name: "SEO", passed: !issues.length, issues };
}

async function run() {
  console.log(`\n📋 Checking: ${folder}\n`);
  const checks = [
    await checkAccuracy(),
    await checkReadability(),
    await checkVoice(),
    await checkSEO(),
  ];
  let allPassed = true;
  for (const c of checks) {
    console.log(`${c.passed ? "✅" : "⚠️"} ${c.name}`);
    for (const i of c.issues) {
      console.log(`   - ${i}`);
      allPassed = false;
    }
  }
  console.log("\n" + (allPassed ? "✅ All passed" : "⚠️ Issues found"));
  console.log(JSON.stringify({ checks, allPassed }));
}

run().catch(console.error);
