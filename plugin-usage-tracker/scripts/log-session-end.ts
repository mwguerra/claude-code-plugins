#!/usr/bin/env bun
import {
  loadLog,
  saveLog,
  generateUUID,
  updateSessionStats,
  updateAggregateStats,
  readHookInput,
} from "./utils";

async function main() {
  try {
    const input = await readHookInput();
    
    const log = loadLog();
    const session = log.sessions.find((s) => s.session_id === input.session_id);
    
    if (session) {
      const endTime = new Date();
      session.ended_at = endTime.toISOString();
      
      // Calculate total session duration
      const startTime = new Date(session.started_at);
      session.total_duration_ms = endTime.getTime() - startTime.getTime();
      
      // Add session end event
      session.events.push({
        event_id: generateUUID(),
        event_type: "SessionEnd",
        timestamp: endTime.toISOString(),
        tool_name: null,
        tool_use_id: null,
        cwd: input.cwd || session.cwd,
        permission_mode: input.permission_mode || session.permission_mode,
        description: `Session ended (reason: ${input.reason || "unknown"})`,
        input_summary: null,
        output_summary: {
          success: true,
          result_type: "session_end",
          result_length: session.events.length,
        },
        duration_ms: session.total_duration_ms,
        matcher: null,
        is_mcp_tool: false,
        is_plugin_tool: false,
        related_event_id: null,
      });
      
      // Update statistics
      updateSessionStats(session);
      updateAggregateStats(log);
      saveLog(log);
    }
    
    process.exit(0);
    
  } catch (error) {
    console.error("Error in session end hook:", error);
    process.exit(1);
  }
}

main();
