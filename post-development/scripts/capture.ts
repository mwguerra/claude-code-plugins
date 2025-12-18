#!/usr/bin/env bun
// Screenshot Capture Script using Playwright

import { chromium, type Browser, type Page, type BrowserContext } from 'playwright';
import * as path from 'path';
import type { 
  ScreenshotPlan, 
  ScreenshotEntry, 
  ScreenshotAction, 
  ViewportConfig,
  ColorModeConfig,
  FocusArea 
} from './types';
import {
  ensureDir,
  loadScreenshotPlan,
  saveScreenshotPlan,
  generateScreenshotFilename,
  log,
  logSuccess,
  logError,
  logProgress,
  formatDuration,
} from './utils';

// ============================================
// Main Capture Functions
// ============================================

export async function captureScreenshot(
  page: Page,
  outputPath: string,
  fullPage: boolean = true
): Promise<void> {
  ensureDir(path.dirname(outputPath));
  await page.screenshot({ 
    path: outputPath, 
    fullPage,
    animations: 'disabled',
  });
}

export async function captureFocusedScreenshot(
  page: Page,
  selector: string,
  outputPath: string,
  padding: number = 20
): Promise<void> {
  ensureDir(path.dirname(outputPath));
  
  const element = page.locator(selector);
  await element.waitFor({ state: 'visible', timeout: 10000 });
  
  await element.screenshot({
    path: outputPath,
    animations: 'disabled',
  });
}

// ============================================
// Action Execution
// ============================================

export async function executeAction(page: Page, action: ScreenshotAction): Promise<void> {
  switch (action.type) {
    case 'wait':
      await page.waitForTimeout(action.ms || 1000);
      break;
      
    case 'waitFor':
      if (action.selector) {
        await page.waitForSelector(action.selector, { 
          state: 'visible',
          timeout: 10000 
        });
      }
      break;
      
    case 'click':
      if (action.selector) {
        await page.click(action.selector);
      }
      break;
      
    case 'fill':
      if (action.selector && action.value) {
        await page.fill(action.selector, action.value);
      }
      break;
      
    case 'select':
      if (action.selector && action.value) {
        await page.selectOption(action.selector, action.value);
      }
      break;
      
    case 'hover':
      if (action.selector) {
        await page.hover(action.selector);
      }
      break;
      
    case 'scroll':
      if (action.selector) {
        await page.locator(action.selector).scrollIntoViewIfNeeded();
      }
      break;
      
    case 'scrollTo':
      if (action.x !== undefined && action.y !== undefined) {
        await page.evaluate(({ x, y }) => window.scrollTo(x, y), { x: action.x, y: action.y });
      }
      break;
      
    case 'press':
      if (action.key) {
        await page.keyboard.press(action.key);
      }
      break;
      
    case 'evaluate':
      if (action.script) {
        await page.evaluate(action.script);
      }
      break;
  }
}

// ============================================
// Color Mode Setup
// ============================================

export async function setupColorMode(page: Page, config: ColorModeConfig): Promise<void> {
  switch (config.type) {
    case 'class':
      await page.evaluate(({ add, remove }) => {
        const html = document.documentElement;
        remove?.forEach(cls => html.classList.remove(cls));
        add?.forEach(cls => html.classList.add(cls));
      }, { add: config.setup.add, remove: config.setup.remove });
      break;
      
    case 'attribute':
      if (config.setup.attribute) {
        await page.evaluate(({ name, value }) => {
          document.documentElement.setAttribute(name, value);
        }, config.setup.attribute);
      }
      break;
      
    case 'media':
      await page.emulateMedia({ 
        colorScheme: config.setup.add?.includes('dark') ? 'dark' : 'light' 
      });
      break;
      
    case 'toggle':
      if (config.setup.selector) {
        await page.click(config.setup.selector);
        await page.waitForTimeout(500);
      }
      break;
  }
}

// ============================================
// Entry Capture
// ============================================

export async function captureEntry(
  context: BrowserContext,
  plan: ScreenshotPlan,
  entry: ScreenshotEntry,
  entryIndex: number
): Promise<{ success: boolean; files: string[]; error?: string; duration: number }> {
  const startTime = Date.now();
  const files: string[] = [];
  
  try {
    for (const viewportName of entry.viewports) {
      const viewport = plan.viewports[viewportName];
      if (!viewport) {
        logError(`Unknown viewport: ${viewportName}`);
        continue;
      }
      
      for (const modeName of entry.modes) {
        const colorMode = plan.colorModes[modeName];
        if (!colorMode) {
          logError(`Unknown color mode: ${modeName}`);
          continue;
        }
        
        // Create new page for each viewport/mode combination
        const page = await context.newPage();
        
        try {
          // Set viewport
          await page.setViewportSize({ 
            width: viewport.width, 
            height: viewport.height 
          });
          
          // Navigate to page
          const url = `${plan.config.baseUrl}${entry.route}`;
          await page.goto(url, { 
            waitUntil: 'networkidle',
            timeout: plan.config.waitTimeout 
          });
          
          // Setup color mode
          await setupColorMode(page, colorMode);
          
          // Wait for animations
          await page.waitForTimeout(plan.config.animationWait);
          
          // Execute pre-capture actions
          if (entry.actions) {
            for (const action of entry.actions) {
              await executeAction(page, action);
            }
          }
          
          // Capture full page
          const outputDir = path.join(
            plan.config.outputDir,
            viewportName,
            modeName
          );
          const filename = generateScreenshotFilename(entry, viewportName, modeName, entryIndex + 1);
          const outputPath = path.join(outputDir, filename);
          
          await captureScreenshot(page, outputPath, entry.fullPage);
          files.push(outputPath);
          log(`  📸 ${filename}`);
          
          // Capture focus areas
          if (entry.focus) {
            for (const focus of entry.focus) {
              const focusFilename = generateScreenshotFilename(
                entry, viewportName, modeName, entryIndex + 1, focus.name
              );
              const focusOutputPath = path.join(
                plan.config.outputDir,
                'focused',
                focusFilename
              );
              
              try {
                await captureFocusedScreenshot(
                  page, 
                  focus.selector, 
                  focusOutputPath,
                  focus.padding
                );
                files.push(focusOutputPath);
                log(`  🎯 ${focusFilename}`);
              } catch (focusError) {
                logError(`  Failed to capture focus area "${focus.name}": ${focusError}`);
              }
            }
          }
          
        } finally {
          await page.close();
        }
      }
    }
    
    const duration = Date.now() - startTime;
    return { success: true, files, duration };
    
  } catch (error) {
    const duration = Date.now() - startTime;
    return { 
      success: false, 
      files, 
      error: error instanceof Error ? error.message : String(error),
      duration 
    };
  }
}

// ============================================
// Main Run Function
// ============================================

export async function runScreenshotPlan(options: {
  id?: string;
  status?: string;
  parallel?: boolean;
  retry?: boolean;
}): Promise<void> {
  const plan = loadScreenshotPlan();
  
  if (!plan) {
    logError('No screenshot plan found. Run /pd-screenshots init first.');
    process.exit(1);
  }
  
  if (plan.screenshots.length === 0) {
    logError('No screenshots configured in plan.');
    process.exit(1);
  }
  
  // Filter entries based on options
  let entries = plan.screenshots;
  
  if (options.id) {
    entries = entries.filter(e => e.id === options.id);
  }
  
  if (options.status) {
    entries = entries.filter(e => e.status === options.status);
  }
  
  if (options.retry) {
    entries = entries.filter(e => e.status === 'error');
  }
  
  if (entries.length === 0) {
    log('No matching entries to capture.');
    return;
  }
  
  log(`\n📸 Starting screenshot capture`);
  log(`   Base URL: ${plan.config.baseUrl}`);
  log(`   Entries: ${entries.length}`);
  log(`   Viewports: ${Object.keys(plan.viewports).join(', ')}`);
  log(`   Color modes: ${Object.keys(plan.colorModes).join(', ')}`);
  log('');
  
  // Launch browser
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    deviceScaleFactor: 2,
  });
  
  let completed = 0;
  let failed = 0;
  
  try {
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const entryIndex = plan.screenshots.findIndex(e => e.id === entry.id);
      
      logProgress(i + 1, entries.length, `Capturing ${entry.name} (${entry.route})`);
      
      // Update status
      plan.screenshots[entryIndex].status = 'in_progress';
      saveScreenshotPlan(plan);
      
      const result = await captureEntry(context, plan, entry, entryIndex);
      
      if (result.success) {
        plan.screenshots[entryIndex].status = 'done';
        plan.screenshots[entryIndex].files = result.files;
        plan.screenshots[entryIndex].lastRun = new Date().toISOString();
        plan.screenshots[entryIndex].duration = result.duration;
        delete plan.screenshots[entryIndex].error;
        completed++;
        logSuccess(`Completed in ${formatDuration(result.duration)}`);
      } else {
        plan.screenshots[entryIndex].status = 'error';
        plan.screenshots[entryIndex].error = result.error;
        plan.screenshots[entryIndex].lastRun = new Date().toISOString();
        plan.screenshots[entryIndex].duration = result.duration;
        failed++;
        logError(`Failed: ${result.error}`);
      }
      
      saveScreenshotPlan(plan);
      log('');
    }
    
  } finally {
    await browser.close();
  }
  
  // Summary
  log('\n📊 Capture Summary');
  log('==================');
  log(`✅ Completed: ${completed}`);
  log(`❌ Failed: ${failed}`);
  log(`📁 Output: ${plan.config.outputDir}`);
}

// ============================================
// CLI Entry Point
// ============================================

if (import.meta.main) {
  const args = process.argv.slice(2);
  const options: {
    id?: string;
    status?: string;
    parallel?: boolean;
    retry?: boolean;
  } = {};
  
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--id':
        options.id = args[++i];
        break;
      case '--status':
        options.status = args[++i];
        break;
      case '--parallel':
        options.parallel = true;
        break;
      case '--retry':
        options.retry = true;
        break;
    }
  }
  
  runScreenshotPlan(options).catch(error => {
    logError(`Fatal error: ${error}`);
    process.exit(1);
  });
}
