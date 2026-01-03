#!/usr/bin/env bun
import {
  loadLog,
  saveLog,
  generateUUID,
  sanitizeInput,
  summarizeOutput,
  isMCPTool,
  isPluginTool,
  removePendingEvent,
  updateSessionStats,
  readHookInput,
} from "./utils";

// Helper to get project directory with proper fallback chain
const getProjectDir = (inputCwd?: string) =>
  inputCwd || process.env.CLAUDE_PROJECT_DIR || process.cwd();

async function main() {
  try {
    const input = await readHookInput();
    const projectDir = getProjectDir(input.cwd);

    const log = loadLog();
    const session = log.sessions.find((s) => s.session_id === input.session_id);

    if (!session) {
      console.error("Session not found:", input.session_id);
      process.exit(0);
    }

    const toolName = input.tool_name || "Unknown";
    const toolUseId = input.tool_use_id || "";
    const endTime = Date.now();

    // Get pending event to calculate duration
    const pendingEvent = removePendingEvent(toolUseId);
    const duration = pendingEvent ? endTime - pendingEvent.start_time : null;

    // Find the related PreToolUse event
    const preEvent = session.events.find(
      (e) => e.tool_use_id === toolUseId && e.event_type === "PreToolUse"
    );

    const eventId = generateUUID();

    // Add PostToolUse event
    session.events.push({
      event_id: eventId,
      event_type: "PostToolUse",
      timestamp: new Date().toISOString(),
      tool_name: toolName,
      tool_use_id: toolUseId,
      cwd: projectDir,
      permission_mode: input.permission_mode || "default",
      description: `Completed ${toolName}${duration ? ` in ${duration}ms` : ""}`,
      input_summary: sanitizeInput(toolName, input.tool_input),
      output_summary: summarizeOutput(toolName, input.tool_response),
      duration_ms: duration,
      matcher: "*",
      is_mcp_tool: isMCPTool(toolName),
      is_plugin_tool: isPluginTool(toolName),
      related_event_id: preEvent?.event_id || pendingEvent?.event_id || null,
    });
    
    // Update the related PreToolUse event
    if (preEvent) {
      preEvent.related_event_id = eventId;
    }
    
    // Update session stats
    updateSessionStats(session);
    
    saveLog(log);
    
    process.exit(0);
    
  } catch (error) {
    console.error("Error in post-tool hook:", error);
    process.exit(0);
  }
}

main();
