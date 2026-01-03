#!/usr/bin/env bun
import { existsSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const LOG_FILE_PATH = join(homedir(), ".claude", ".plugin-history", "usage-log.json");

interface UsageLog {
  version: string;
  created_at: string;
  updated_at: string;
  sessions: any[];
  aggregate_stats: any;
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
  if (ms < 3600000) return `${(ms / 60000).toFixed(1)}m`;
  return `${(ms / 3600000).toFixed(1)}h`;
}

function formatNumber(n: number): string {
  return n.toLocaleString();
}

async function main() {
  const args = process.argv.slice(2);
  const format = args.includes("--json") ? "json" : "text";
  const days = parseInt(args.find((a) => a.startsWith("--days="))?.split("=")[1] || "30");
  
  if (!existsSync(LOG_FILE_PATH)) {
    console.error("No usage log found. Run /usage-init to initialize tracking.");
    process.exit(1);
  }
  
  const log: UsageLog = JSON.parse(readFileSync(LOG_FILE_PATH, "utf-8"));
  const stats = log.aggregate_stats;
  
  // Filter sessions by date range
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - days);
  const recentSessions = log.sessions.filter(
    (s) => new Date(s.started_at) >= cutoffDate
  );
  
  // Calculate recent stats
  const recentStats = {
    sessions: recentSessions.length,
    events: 0,
    tool_calls: 0,
    time_ms: 0,
    tool_counts: {} as Record<string, number>,
    tool_time: {} as Record<string, number>,
  };
  
  for (const session of recentSessions) {
    recentStats.events += session.session_stats?.total_events || 0;
    recentStats.tool_calls += session.session_stats?.total_tool_calls || 0;
    recentStats.time_ms += session.session_stats?.total_processing_time_ms || 0;
    
    for (const [tool, count] of Object.entries(session.session_stats?.tool_usage_counts || {})) {
      recentStats.tool_counts[tool] = (recentStats.tool_counts[tool] || 0) + (count as number);
    }
    
    for (const [tool, time] of Object.entries(session.session_stats?.tool_time_spent || {})) {
      recentStats.tool_time[tool] = (recentStats.tool_time[tool] || 0) + (time as number);
    }
  }
  
  if (format === "json") {
    console.log(JSON.stringify({
      all_time: stats,
      recent: recentStats,
      days_analyzed: days,
    }, null, 2));
    return;
  }
  
  // Text format output
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("                    📊 USAGE STATISTICS                         ");
  console.log("═══════════════════════════════════════════════════════════════");
  
  console.log("\n📅 ALL TIME STATISTICS");
  console.log("───────────────────────────────────────────────────────────────");
  console.log(`   Total Sessions:    ${formatNumber(stats.total_sessions)}`);
  console.log(`   Total Events:      ${formatNumber(stats.total_events)}`);
  console.log(`   Total Tool Calls:  ${formatNumber(stats.total_tool_calls)}`);
  console.log(`   Total Time:        ${formatDuration(stats.total_time_tracked_ms)}`);
  
  console.log(`\n📈 LAST ${days} DAYS`);
  console.log("───────────────────────────────────────────────────────────────");
  console.log(`   Sessions:          ${formatNumber(recentStats.sessions)}`);
  console.log(`   Events:            ${formatNumber(recentStats.events)}`);
  console.log(`   Tool Calls:        ${formatNumber(recentStats.tool_calls)}`);
  console.log(`   Processing Time:   ${formatDuration(recentStats.time_ms)}`);
  
  // Top tools by usage
  console.log("\n🔧 TOP TOOLS BY USAGE");
  console.log("───────────────────────────────────────────────────────────────");
  const sortedByUsage = Object.entries(recentStats.tool_counts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10);
  
  for (const [tool, count] of sortedByUsage) {
    const time = recentStats.tool_time[tool] || 0;
    const avgTime = count > 0 ? time / count : 0;
    console.log(`   ${tool.padEnd(20)} ${String(count).padStart(6)} calls  (avg: ${formatDuration(avgTime)})`);
  }
  
  // Top tools by time
  console.log("\n⏱️  TOP TOOLS BY TIME SPENT");
  console.log("───────────────────────────────────────────────────────────────");
  const sortedByTime = Object.entries(recentStats.tool_time)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10);
  
  for (const [tool, time] of sortedByTime) {
    const count = recentStats.tool_counts[tool] || 0;
    const percentage = recentStats.time_ms > 0 ? ((time / recentStats.time_ms) * 100).toFixed(1) : "0.0";
    console.log(`   ${tool.padEnd(20)} ${formatDuration(time).padStart(10)}  (${percentage}% of total)`);
  }
  
  // Project usage
  if (Object.keys(stats.project_usage).length > 0) {
    console.log("\n📁 PROJECT USAGE");
    console.log("───────────────────────────────────────────────────────────────");
    const sortedProjects = Object.entries(stats.project_usage)
      .sort(([, a]: any, [, b]: any) => b.sessions - a.sessions)
      .slice(0, 5);
    
    for (const [project, data] of sortedProjects) {
      const projectData = data as any;
      const shortPath = project.replace(homedir(), "~");
      console.log(`   ${shortPath.slice(0, 40).padEnd(42)} ${projectData.sessions} sessions`);
    }
  }
  
  // Daily activity (last 7 days)
  console.log("\n📆 DAILY ACTIVITY (Last 7 Days)");
  console.log("───────────────────────────────────────────────────────────────");
  const today = new Date();
  for (let i = 6; i >= 0; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dateStr = date.toISOString().split("T")[0];
    const activity = stats.daily_activity[dateStr] || { sessions: 0, events: 0, time_ms: 0 };
    const bar = "█".repeat(Math.min(activity.sessions * 2, 20));
    console.log(`   ${dateStr}  ${bar.padEnd(20)} ${activity.sessions} sessions`);
  }
  
  console.log("\n═══════════════════════════════════════════════════════════════");
  console.log(`   Last updated: ${new Date(log.updated_at).toLocaleString()}`);
  console.log("═══════════════════════════════════════════════════════════════\n");
}

main().catch(console.error);
