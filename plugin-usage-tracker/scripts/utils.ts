import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";

// Types
export interface UsageLog {
  version: string;
  created_at: string;
  updated_at: string;
  sessions: Session[];
  aggregate_stats: AggregateStats;
}

export interface Session {
  session_id: string;
  project_dir: string;
  cwd: string;
  started_at: string;
  ended_at: string | null;
  total_duration_ms: number | null;
  permission_mode: string;
  events: Event[];
  session_stats: SessionStats;
}

export interface Event {
  event_id: string;
  event_type: string;
  timestamp: string;
  tool_name: string | null;
  tool_use_id: string | null;
  cwd: string;
  permission_mode: string;
  description: string | null;
  input_summary: InputSummary | null;
  output_summary: OutputSummary | null;
  duration_ms: number | null;
  matcher: string | null;
  is_mcp_tool: boolean;
  is_plugin_tool: boolean;
  related_event_id: string | null;
}

export interface InputSummary {
  type?: string;
  file_path?: string;
  command?: string;
  query?: string;
  content_length?: number;
}

export interface OutputSummary {
  success?: boolean;
  result_type?: string;
  result_length?: number;
  error?: string;
}

export interface SessionStats {
  total_events: number;
  total_tool_calls: number;
  total_processing_time_ms: number;
  tool_usage_counts: Record<string, number>;
  tool_time_spent: Record<string, number>;
  most_used_tool: string | null;
  slowest_tool: string | null;
  user_prompts_count: number;
  errors_count: number;
}

export interface AggregateStats {
  total_sessions: number;
  total_events: number;
  total_tool_calls: number;
  total_time_tracked_ms: number;
  tool_usage_counts: Record<string, number>;
  tool_time_spent: Record<string, number>;
  project_usage: Record<string, ProjectUsage>;
  daily_activity: Record<string, DailyActivity>;
}

export interface ProjectUsage {
  sessions: number;
  total_time_ms: number;
  tool_calls: number;
}

export interface DailyActivity {
  sessions: number;
  events: number;
  time_ms: number;
}

// Constants
export const PLUGIN_HISTORY_DIR = join(homedir(), ".claude", ".plugin-history");
export const LOG_FILE_PATH = join(PLUGIN_HISTORY_DIR, "usage-log.json");
export const PENDING_EVENTS_PATH = join(PLUGIN_HISTORY_DIR, "pending-events.json");
export const CONFIG_PATH = join(PLUGIN_HISTORY_DIR, "config.json");

// Initialize empty log structure
export function createEmptyLog(): UsageLog {
  const now = new Date().toISOString();
  return {
    version: "1.0.0",
    created_at: now,
    updated_at: now,
    sessions: [],
    aggregate_stats: {
      total_sessions: 0,
      total_events: 0,
      total_tool_calls: 0,
      total_time_tracked_ms: 0,
      tool_usage_counts: {},
      tool_time_spent: {},
      project_usage: {},
      daily_activity: {},
    },
  };
}

// Initialize empty session stats
export function createEmptySessionStats(): SessionStats {
  return {
    total_events: 0,
    total_tool_calls: 0,
    total_processing_time_ms: 0,
    tool_usage_counts: {},
    tool_time_spent: {},
    most_used_tool: null,
    slowest_tool: null,
    user_prompts_count: 0,
    errors_count: 0,
  };
}

// Ensure the plugin history directory exists
export function ensureDirectoryExists(): void {
  if (!existsSync(PLUGIN_HISTORY_DIR)) {
    mkdirSync(PLUGIN_HISTORY_DIR, { recursive: true });
  }
}

// Load the usage log
export function loadLog(): UsageLog {
  ensureDirectoryExists();
  
  if (!existsSync(LOG_FILE_PATH)) {
    const emptyLog = createEmptyLog();
    saveLog(emptyLog);
    return emptyLog;
  }
  
  try {
    const content = readFileSync(LOG_FILE_PATH, "utf-8");
    return JSON.parse(content) as UsageLog;
  } catch (error) {
    console.error("Error loading log, creating new one:", error);
    const emptyLog = createEmptyLog();
    saveLog(emptyLog);
    return emptyLog;
  }
}

// Save the usage log
export function saveLog(log: UsageLog): void {
  ensureDirectoryExists();
  log.updated_at = new Date().toISOString();
  writeFileSync(LOG_FILE_PATH, JSON.stringify(log, null, 2));
}

// Generate a UUID
export function generateUUID(): string {
  return crypto.randomUUID();
}

// Get or create current session
export function getOrCreateSession(log: UsageLog, sessionId: string, cwd: string, permissionMode: string): Session {
  let session = log.sessions.find((s) => s.session_id === sessionId);
  
  if (!session) {
    session = {
      session_id: sessionId,
      project_dir: cwd,
      cwd: cwd,
      started_at: new Date().toISOString(),
      ended_at: null,
      total_duration_ms: null,
      permission_mode: permissionMode,
      events: [],
      session_stats: createEmptySessionStats(),
    };
    log.sessions.push(session);
  }
  
  return session;
}

// Store pending event (for tracking duration between PreToolUse and PostToolUse)
export interface PendingEvent {
  event_id: string;
  tool_use_id: string;
  start_time: number;
  tool_name: string;
  session_id: string;
}

export function loadPendingEvents(): Record<string, PendingEvent> {
  ensureDirectoryExists();
  
  if (!existsSync(PENDING_EVENTS_PATH)) {
    return {};
  }
  
  try {
    const content = readFileSync(PENDING_EVENTS_PATH, "utf-8");
    return JSON.parse(content);
  } catch {
    return {};
  }
}

export function savePendingEvents(events: Record<string, PendingEvent>): void {
  ensureDirectoryExists();
  writeFileSync(PENDING_EVENTS_PATH, JSON.stringify(events, null, 2));
}

export function addPendingEvent(event: PendingEvent): void {
  const events = loadPendingEvents();
  events[event.tool_use_id] = event;
  savePendingEvents(events);
}

export function getPendingEvent(toolUseId: string): PendingEvent | null {
  const events = loadPendingEvents();
  return events[toolUseId] || null;
}

export function removePendingEvent(toolUseId: string): PendingEvent | null {
  const events = loadPendingEvents();
  const event = events[toolUseId];
  if (event) {
    delete events[toolUseId];
    savePendingEvents(events);
  }
  return event || null;
}

// Sanitize input for logging (remove sensitive data)
export function sanitizeInput(toolName: string, input: any): InputSummary | null {
  if (!input) return null;
  
  const summary: InputSummary = {};
  
  // Handle different tool types
  if (toolName === "Bash") {
    summary.type = "command";
    summary.command = typeof input.command === "string" 
      ? input.command.slice(0, 200) + (input.command.length > 200 ? "..." : "")
      : undefined;
  } else if (toolName === "Read") {
    summary.type = "file_read";
    summary.file_path = input.file_path;
  } else if (toolName === "Write" || toolName === "Edit") {
    summary.type = toolName.toLowerCase();
    summary.file_path = input.file_path;
    summary.content_length = typeof input.content === "string" ? input.content.length : undefined;
  } else if (toolName === "Grep" || toolName === "Glob") {
    summary.type = toolName.toLowerCase();
    summary.query = typeof input.pattern === "string" ? input.pattern : input.path;
  } else if (toolName.startsWith("mcp__")) {
    summary.type = "mcp_tool";
  } else if (toolName === "Task") {
    summary.type = "subagent";
    summary.query = input.description?.slice(0, 200);
  } else {
    summary.type = toolName.toLowerCase();
  }
  
  return summary;
}

// Summarize output for logging
export function summarizeOutput(toolName: string, response: any): OutputSummary | null {
  if (!response) return null;
  
  const summary: OutputSummary = {
    success: true,
  };
  
  if (typeof response === "object") {
    if (response.success !== undefined) {
      summary.success = response.success;
    }
    if (response.error) {
      summary.success = false;
      summary.error = typeof response.error === "string" 
        ? response.error.slice(0, 200) 
        : JSON.stringify(response.error).slice(0, 200);
    }
    summary.result_type = typeof response;
    summary.result_length = JSON.stringify(response).length;
  } else if (typeof response === "string") {
    summary.result_type = "string";
    summary.result_length = response.length;
  }
  
  return summary;
}

// Check if tool is from MCP server
export function isMCPTool(toolName: string): boolean {
  return toolName.startsWith("mcp__");
}

// Check if tool is from a plugin
export function isPluginTool(toolName: string): boolean {
  // Plugin tools typically have a namespace or specific pattern
  return toolName.includes(":") || toolName.startsWith("plugin_");
}

// Update session stats
export function updateSessionStats(session: Session): void {
  const stats = session.session_stats;
  
  stats.total_events = session.events.length;
  stats.total_tool_calls = session.events.filter(
    (e) => e.event_type === "PostToolUse" && e.tool_name
  ).length;
  
  // Calculate tool usage counts and time spent
  const toolCounts: Record<string, number> = {};
  const toolTime: Record<string, number> = {};
  let totalTime = 0;
  let userPrompts = 0;
  let errors = 0;
  
  for (const event of session.events) {
    if (event.event_type === "PostToolUse" && event.tool_name) {
      toolCounts[event.tool_name] = (toolCounts[event.tool_name] || 0) + 1;
      if (event.duration_ms) {
        toolTime[event.tool_name] = (toolTime[event.tool_name] || 0) + event.duration_ms;
        totalTime += event.duration_ms;
      }
      if (event.output_summary?.success === false) {
        errors++;
      }
    } else if (event.event_type === "UserPromptSubmit") {
      userPrompts++;
    }
  }
  
  stats.tool_usage_counts = toolCounts;
  stats.tool_time_spent = toolTime;
  stats.total_processing_time_ms = totalTime;
  stats.user_prompts_count = userPrompts;
  stats.errors_count = errors;
  
  // Find most used tool
  let maxCount = 0;
  for (const [tool, count] of Object.entries(toolCounts)) {
    if (count > maxCount) {
      maxCount = count;
      stats.most_used_tool = tool;
    }
  }
  
  // Find slowest tool
  let maxTime = 0;
  for (const [tool, time] of Object.entries(toolTime)) {
    if (time > maxTime) {
      maxTime = time;
      stats.slowest_tool = tool;
    }
  }
}

// Update aggregate stats
export function updateAggregateStats(log: UsageLog): void {
  const stats = log.aggregate_stats;
  
  stats.total_sessions = log.sessions.length;
  stats.total_events = 0;
  stats.total_tool_calls = 0;
  stats.total_time_tracked_ms = 0;
  stats.tool_usage_counts = {};
  stats.tool_time_spent = {};
  stats.project_usage = {};
  stats.daily_activity = {};
  
  for (const session of log.sessions) {
    stats.total_events += session.session_stats.total_events;
    stats.total_tool_calls += session.session_stats.total_tool_calls;
    stats.total_time_tracked_ms += session.session_stats.total_processing_time_ms;
    
    // Aggregate tool counts
    for (const [tool, count] of Object.entries(session.session_stats.tool_usage_counts)) {
      stats.tool_usage_counts[tool] = (stats.tool_usage_counts[tool] || 0) + count;
    }
    
    // Aggregate tool time
    for (const [tool, time] of Object.entries(session.session_stats.tool_time_spent)) {
      stats.tool_time_spent[tool] = (stats.tool_time_spent[tool] || 0) + time;
    }
    
    // Project usage
    const project = session.project_dir;
    if (!stats.project_usage[project]) {
      stats.project_usage[project] = { sessions: 0, total_time_ms: 0, tool_calls: 0 };
    }
    stats.project_usage[project].sessions++;
    stats.project_usage[project].total_time_ms += session.session_stats.total_processing_time_ms;
    stats.project_usage[project].tool_calls += session.session_stats.total_tool_calls;
    
    // Daily activity
    const date = session.started_at.split("T")[0];
    if (!stats.daily_activity[date]) {
      stats.daily_activity[date] = { sessions: 0, events: 0, time_ms: 0 };
    }
    stats.daily_activity[date].sessions++;
    stats.daily_activity[date].events += session.session_stats.total_events;
    stats.daily_activity[date].time_ms += session.session_stats.total_processing_time_ms;
  }
}

// Read hook input from stdin
export async function readHookInput(): Promise<any> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk);
  }
  const input = Buffer.concat(chunks).toString("utf-8");
  return JSON.parse(input);
}
