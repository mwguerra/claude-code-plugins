#!/usr/bin/env bun
import {
  loadLog,
  saveLog,
  generateUUID,
  updateSessionStats,
  readHookInput,
} from "./utils";

async function main() {
  try {
    const input = await readHookInput();
    
    const log = loadLog();
    const session = log.sessions.find((s) => s.session_id === input.session_id);
    
    if (session) {
      session.events.push({
        event_id: generateUUID(),
        event_type: "SubagentStop",
        timestamp: new Date().toISOString(),
        tool_name: "Task",
        tool_use_id: null,
        cwd: input.cwd || session.cwd,
        permission_mode: input.permission_mode || session.permission_mode,
        description: `Subagent stopped${input.stop_hook_active ? " (stop hook active)" : ""}`,
        input_summary: null,
        output_summary: null,
        duration_ms: null,
        matcher: null,
        is_mcp_tool: false,
        is_plugin_tool: false,
        related_event_id: null,
      });
      
      updateSessionStats(session);
      saveLog(log);
    }
    
    // Allow the subagent stop to proceed
    process.exit(0);
    
  } catch (error) {
    console.error("Error in subagent stop hook:", error);
    process.exit(0);
  }
}

main();
