#!/usr/bin/env bun
// Initialize Post-Development Structure

import {
  createPostDevStructure,
  createInitialPlan,
  savePostDevPlan,
  createDefaultScreenshotPlan,
  saveScreenshotPlan,
  getPostDevDir,
  getPostDevPlanPath,
  fileExists,
  log,
  logSuccess,
  logError,
  logInfo,
  parseArgs,
} from './utils';
import * as path from 'path';

async function init(options: { baseUrl?: string; force?: boolean }): Promise<void> {
  const postDevDir = getPostDevDir();
  const planPath = getPostDevPlanPath();
  
  // Check if already initialized
  if (fileExists(planPath) && !options.force) {
    logError('Post-development already initialized. Use --force to reinitialize.');
    process.exit(1);
  }
  
  log('\n📦 Initializing Post-Development');
  log('================================\n');
  
  // Create directory structure
  log('Creating directory structure...');
  createPostDevStructure();
  logSuccess('Directory structure created');
  
  // Create master plan
  log('Creating master plan...');
  const plan = createInitialPlan({
    baseUrl: options.baseUrl || 'http://localhost:3000',
  });
  savePostDevPlan(plan);
  logSuccess('Master plan created');
  
  // Create screenshot plan
  log('Creating screenshot plan...');
  const screenshotPlan = createDefaultScreenshotPlan(options.baseUrl || 'http://localhost:3000');
  saveScreenshotPlan(screenshotPlan);
  logSuccess('Screenshot plan created');
  
  // Summary
  log('\n✅ Post-Development Initialized!\n');
  log(`📁 Output directory: ${postDevDir}`);
  log(`🔗 Base URL: ${options.baseUrl || 'http://localhost:3000'}`);
  log('\nNext steps:');
  log('  1. Analyze your project:  /post-dev run --task seo');
  log('  2. Capture screenshots:   /post-dev run --task screenshots');
  log('  3. Or run everything:     /post-dev run');
  log('');
  logInfo('Edit .post-development/post-development.json to customize settings');
}

// CLI Entry Point
if (import.meta.main) {
  const args = parseArgs(process.argv.slice(2));
  
  init({
    baseUrl: args['base-url'] as string,
    force: args.force === true,
  }).catch(error => {
    logError(`Error: ${error}`);
    process.exit(1);
  });
}
