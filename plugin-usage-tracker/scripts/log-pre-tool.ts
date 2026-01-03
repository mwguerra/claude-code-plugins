#!/usr/bin/env bun
import {
  loadLog,
  saveLog,
  getOrCreateSession,
  generateUUID,
  sanitizeInput,
  isMCPTool,
  isPluginTool,
  addPendingEvent,
  readHookInput,
} from "./utils";

async function main() {
  try {
    const input = await readHookInput();
    
    const log = loadLog();
    const session = getOrCreateSession(
      log,
      input.session_id,
      input.cwd || process.cwd(),
      input.permission_mode || "default"
    );
    
    const eventId = generateUUID();
    const toolName = input.tool_name || "Unknown";
    const toolUseId = input.tool_use_id || generateUUID();
    const startTime = Date.now();
    
    // Store pending event for duration tracking
    addPendingEvent({
      event_id: eventId,
      tool_use_id: toolUseId,
      start_time: startTime,
      tool_name: toolName,
      session_id: input.session_id,
    });
    
    // Add PreToolUse event
    session.events.push({
      event_id: eventId,
      event_type: "PreToolUse",
      timestamp: new Date().toISOString(),
      tool_name: toolName,
      tool_use_id: toolUseId,
      cwd: input.cwd || process.cwd(),
      permission_mode: input.permission_mode || "default",
      description: `Starting ${toolName}`,
      input_summary: sanitizeInput(toolName, input.tool_input),
      output_summary: null,
      duration_ms: null,
      matcher: "*",
      is_mcp_tool: isMCPTool(toolName),
      is_plugin_tool: isPluginTool(toolName),
      related_event_id: null,
    });
    
    saveLog(log);
    
    // Allow the tool to proceed
    process.exit(0);
    
  } catch (error) {
    console.error("Error in pre-tool hook:", error);
    // Don't block tool execution on logging errors
    process.exit(0);
  }
}

main();
