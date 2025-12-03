/**
 * Cross-platform timestamp generator
 */

const args = process.argv.slice(2);
const folderFormat = args.includes("--folder");

const now = new Date();
const pad = (n: number): string => n.toString().padStart(2, "0");

const year = now.getFullYear();
const month = pad(now.getMonth() + 1);
const day = pad(now.getDate());
const hours = pad(now.getHours());
const minutes = pad(now.getMinutes());
const seconds = pad(now.getSeconds());

if (folderFormat) {
  console.log(`${year}_${month}_${day}`);
} else {
  console.log(`${year}-${month}-${day}-${hours}-${minutes}-${seconds}`);
}
