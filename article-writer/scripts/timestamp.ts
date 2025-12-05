#!/usr/bin/env bun
/**
 * Cross-platform timestamp generator
 * Usage: bun run timestamp.ts [--folder|--iso|--slug]
 * 
 * Formats:
 *   (default)   2025-01-15-14-30-45
 *   --folder    2025_01_15
 *   --iso       2025-01-15T14:30:45Z
 *   --slug      20250115
 */

const args = process.argv.slice(2);
const now = new Date();

const pad = (n: number): string => n.toString().padStart(2, "0");

const year = now.getFullYear();
const month = pad(now.getMonth() + 1);
const day = pad(now.getDate());
const hours = pad(now.getHours());
const minutes = pad(now.getMinutes());
const seconds = pad(now.getSeconds());

if (args.includes("--folder")) {
  console.log(`${year}_${month}_${day}`);
} else if (args.includes("--iso")) {
  console.log(now.toISOString());
} else if (args.includes("--slug")) {
  console.log(`${year}${month}${day}`);
} else {
  console.log(`${year}-${month}-${day}-${hours}-${minutes}-${seconds}`);
}
