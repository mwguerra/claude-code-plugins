// Post-Development Plugin Utilities

import * as fs from 'fs';
import * as path from 'path';
import type { PostDevelopmentPlan, ScreenshotPlan, ScreenshotEntry } from './types';

// Project root - use CLAUDE_PROJECT_DIR when available, fall back to process.cwd()
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();

// ============================================
// File System Utilities
// ============================================

export function ensureDir(dirPath: string): void {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

export function readJson<T>(filePath: string): T | null {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(content) as T;
  } catch {
    return null;
  }
}

export function writeJson(filePath: string, data: object): void {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

export function fileExists(filePath: string): boolean {
  return fs.existsSync(filePath);
}

// ============================================
// Post-Development Plan Utilities
// ============================================

export function getPostDevDir(): string {
  return path.join(PROJECT_ROOT, '.post-development');
}

export function getPostDevPlanPath(): string {
  return path.join(getPostDevDir(), 'post-development.json');
}

export function loadPostDevPlan(): PostDevelopmentPlan | null {
  return readJson<PostDevelopmentPlan>(getPostDevPlanPath());
}

export function savePostDevPlan(plan: PostDevelopmentPlan): void {
  plan.updatedAt = new Date().toISOString();
  writeJson(getPostDevPlanPath(), plan);
}

export function createInitialPlan(config: Partial<PostDevelopmentPlan['config']> = {}): PostDevelopmentPlan {
  const now = new Date().toISOString();
  return {
    project: {
      name: '',
      description: '',
      type: 'saas',
      techStack: [],
      baseUrl: config.baseUrl || 'http://localhost:3000',
      routes: [],
      analyzedAt: now,
    },
    tasks: {
      seo: { status: 'pending', dependsOn: [] },
      screenshots: { status: 'pending', dependsOn: [] },
      personas: { status: 'pending', dependsOn: ['seo'] },
      ads: { status: 'pending', dependsOn: ['personas', 'screenshots'] },
      articles: { status: 'pending', dependsOn: ['personas', 'screenshots'] },
      landing: { status: 'pending', dependsOn: ['personas', 'screenshots', 'articles'] },
    },
    config: {
      baseUrl: config.baseUrl || 'http://localhost:3000',
      outputDir: '.post-development',
      targetMarkets: ['b2b'],
      ...config,
    },
    progress: {
      completedTasks: 0,
      totalTasks: 6,
      startedAt: null,
      completedAt: null,
    },
    createdAt: now,
    updatedAt: now,
  };
}

// ============================================
// Screenshot Utilities
// ============================================

export function getScreenshotDir(): string {
  return path.join(getPostDevDir(), 'screenshots');
}

export function getScreenshotPlanPath(): string {
  return path.join(getScreenshotDir(), 'screenshot-plan.json');
}

export function loadScreenshotPlan(): ScreenshotPlan | null {
  return readJson<ScreenshotPlan>(getScreenshotPlanPath());
}

export function saveScreenshotPlan(plan: ScreenshotPlan): void {
  writeJson(getScreenshotPlanPath(), plan);
}

export function createDefaultScreenshotPlan(baseUrl: string): ScreenshotPlan {
  return {
    config: {
      baseUrl,
      outputDir: '.post-development/screenshots',
      format: 'png',
      quality: 100,
      waitTimeout: 30000,
      animationWait: 500,
    },
    viewports: {
      desktop: { width: 1920, height: 1080, deviceScaleFactor: 1 },
      'desktop-hd': { width: 2560, height: 1440, deviceScaleFactor: 2 },
      laptop: { width: 1366, height: 768, deviceScaleFactor: 1 },
      tablet: { width: 768, height: 1024, deviceScaleFactor: 2, isMobile: true },
      mobile: { width: 375, height: 812, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
    },
    colorModes: {
      light: {
        type: 'class',
        setup: { remove: ['dark'], add: [] },
      },
      dark: {
        type: 'class',
        setup: { add: ['dark'], remove: [] },
      },
    },
    screenshots: [],
  };
}

export function sanitizeRouteName(route: string): string {
  return route
    .replace(/^\//, '')
    .replace(/\//g, '_')
    .replace(/[^a-zA-Z0-9_-]/g, '')
    .toLowerCase() || 'homepage';
}

export function generateScreenshotFilename(
  entry: ScreenshotEntry,
  viewport: string,
  mode: string,
  index: number,
  focusName?: string
): string {
  const sequence = String(index).padStart(2, '0');
  const routeName = sanitizeRouteName(entry.route);
  
  if (focusName) {
    return `${sequence}_${routeName}_${viewport}_${mode}_${focusName}.png`;
  }
  return `${sequence}_${routeName}_${viewport}_${mode}_full.png`;
}

// ============================================
// Status Utilities
// ============================================

export function getStatusEmoji(status: string): string {
  switch (status) {
    case 'pending': return '⏳';
    case 'in_progress': return '🔄';
    case 'done': return '✅';
    case 'error': return '❌';
    case 'skipped': return '⏭️';
    default: return '❓';
  }
}

export function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  return `${(ms / 60000).toFixed(1)}m`;
}

export function printProgress(completed: number, total: number, width = 20): string {
  const filled = Math.round((completed / total) * width);
  const empty = width - filled;
  const bar = '█'.repeat(filled) + '░'.repeat(empty);
  const percent = Math.round((completed / total) * 100);
  return `[${bar}] ${percent}% (${completed}/${total})`;
}

// ============================================
// Validation Utilities
// ============================================

export function validateUrl(url: string): boolean {
  try {
    new URL(url);
    return true;
  } catch {
    return false;
  }
}

export function validateViewport(viewport: string, plan: ScreenshotPlan): boolean {
  return viewport in plan.viewports;
}

export function validateColorMode(mode: string, plan: ScreenshotPlan): boolean {
  return mode in plan.colorModes;
}

// ============================================
// Directory Structure Creation
// ============================================

export function createPostDevStructure(): void {
  const baseDir = getPostDevDir();
  
  const dirs = [
    'seo/pages',
    'seo/assets/favicons',
    'seo/assets/og-images',
    'screenshots/desktop/light',
    'screenshots/desktop/dark',
    'screenshots/tablet/light',
    'screenshots/tablet/dark',
    'screenshots/mobile/light',
    'screenshots/mobile/dark',
    'screenshots/focused',
    'personas/personas',
    'personas/strategies',
    'personas/cta/by-persona',
    'personas/cta/by-channel',
    'ads/instagram/feed',
    'ads/instagram/stories',
    'ads/instagram/reels',
    'ads/facebook/feed',
    'ads/facebook/carousel',
    'ads/facebook/stories',
    'ads/linkedin/single-image',
    'ads/linkedin/carousel',
    'ads/twitter/single-image',
    'ads/twitter/carousel',
    'articles/article-1/images',
    'articles/article-2/images',
    'articles/article-3/images',
    'landing-pages',
  ];
  
  for (const dir of dirs) {
    ensureDir(path.join(baseDir, dir));
  }
}

// ============================================
// Argument Parsing
// ============================================

export function parseArgs(args: string[]): Record<string, string | boolean> {
  const result: Record<string, string | boolean> = {};
  
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const nextArg = args[i + 1];
      
      if (nextArg && !nextArg.startsWith('--')) {
        result[key] = nextArg;
        i++;
      } else {
        result[key] = true;
      }
    } else if (!args[i - 1]?.startsWith('--')) {
      // Positional argument
      if (!result._positional) {
        result._positional = arg;
      }
    }
  }
  
  return result;
}

// ============================================
// Logging Utilities
// ============================================

export function log(message: string): void {
  console.log(message);
}

export function logSuccess(message: string): void {
  console.log(`✅ ${message}`);
}

export function logError(message: string): void {
  console.error(`❌ ${message}`);
}

export function logWarning(message: string): void {
  console.warn(`⚠️ ${message}`);
}

export function logInfo(message: string): void {
  console.log(`ℹ️ ${message}`);
}

export function logProgress(current: number, total: number, message: string): void {
  console.log(`[${current}/${total}] ${message}`);
}
