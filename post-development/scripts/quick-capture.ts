#!/usr/bin/env bun
// Quick Screenshot Capture - Single page capture without a plan

import { chromium } from 'playwright';
import * as path from 'path';
import {
  ensureDir,
  getPostDevDir,
  log,
  logSuccess,
  logError,
  validateUrl,
} from './utils';

interface QuickCaptureOptions {
  url: string;
  viewport: 'desktop' | 'tablet' | 'mobile';
  mode: 'light' | 'dark' | 'both';
  name?: string;
  fullPage: boolean;
}

const VIEWPORTS = {
  desktop: { width: 1920, height: 1080, deviceScaleFactor: 1 },
  tablet: { width: 768, height: 1024, deviceScaleFactor: 2, isMobile: true },
  mobile: { width: 375, height: 812, deviceScaleFactor: 3, isMobile: true },
};

async function quickCapture(options: QuickCaptureOptions): Promise<void> {
  if (!validateUrl(options.url)) {
    logError('Invalid URL provided');
    process.exit(1);
  }
  
  const outputDir = path.join(getPostDevDir(), 'screenshots', 'quick');
  ensureDir(outputDir);
  
  const browser = await chromium.launch({ headless: true });
  const viewport = VIEWPORTS[options.viewport];
  
  const modes = options.mode === 'both' ? ['light', 'dark'] : [options.mode];
  const timestamp = Date.now();
  const baseName = options.name || new URL(options.url).pathname.replace(/\//g, '_').slice(1) || 'page';
  
  try {
    for (const mode of modes) {
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        deviceScaleFactor: viewport.deviceScaleFactor || 1,
        isMobile: viewport.isMobile || false,
        colorScheme: mode as 'light' | 'dark',
      });
      
      const page = await context.newPage();
      
      log(`📸 Capturing ${options.url} (${options.viewport}, ${mode})`);
      
      await page.goto(options.url, { waitUntil: 'networkidle', timeout: 30000 });
      
      // Apply color mode via class
      await page.evaluate((isDark) => {
        if (isDark) {
          document.documentElement.classList.add('dark');
        } else {
          document.documentElement.classList.remove('dark');
        }
      }, mode === 'dark');
      
      await page.waitForTimeout(500);
      
      const filename = `${baseName}_${options.viewport}_${mode}_${timestamp}.png`;
      const outputPath = path.join(outputDir, filename);
      
      await page.screenshot({
        path: outputPath,
        fullPage: options.fullPage,
        animations: 'disabled',
      });
      
      logSuccess(`Saved: ${outputPath}`);
      
      await context.close();
    }
  } finally {
    await browser.close();
  }
}

// CLI Entry Point
if (import.meta.main) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    log('Usage: bun run quick-capture.ts <url> [options]');
    log('');
    log('Options:');
    log('  --viewport <desktop|tablet|mobile>  Viewport preset (default: desktop)');
    log('  --mode <light|dark|both>           Color mode (default: both)');
    log('  --name <name>                       Output filename base');
    log('  --no-full-page                      Capture viewport only');
    process.exit(0);
  }
  
  const options: QuickCaptureOptions = {
    url: args[0],
    viewport: 'desktop',
    mode: 'both',
    fullPage: true,
  };
  
  for (let i = 1; i < args.length; i++) {
    switch (args[i]) {
      case '--viewport':
        options.viewport = args[++i] as 'desktop' | 'tablet' | 'mobile';
        break;
      case '--mode':
        options.mode = args[++i] as 'light' | 'dark' | 'both';
        break;
      case '--name':
        options.name = args[++i];
        break;
      case '--no-full-page':
        options.fullPage = false;
        break;
    }
  }
  
  quickCapture(options).catch(error => {
    logError(`Error: ${error}`);
    process.exit(1);
  });
}
