#!/usr/bin/env bun
import {
  loadLog,
  saveLog,
  getOrCreateSession,
  generateUUID,
  updateSessionStats,
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
    
    // Add user prompt event (but don't log the actual prompt content for privacy)
    const promptLength = input.prompt?.length || 0;
    
    session.events.push({
      event_id: generateUUID(),
      event_type: "UserPromptSubmit",
      timestamp: new Date().toISOString(),
      tool_name: null,
      tool_use_id: null,
      cwd: input.cwd || process.cwd(),
      permission_mode: input.permission_mode || "default",
      description: `User submitted prompt (${promptLength} characters)`,
      input_summary: {
        type: "user_prompt",
        content_length: promptLength,
      },
      output_summary: null,
      duration_ms: null,
      matcher: null,
      is_mcp_tool: false,
      is_plugin_tool: false,
      related_event_id: null,
    });
    
    updateSessionStats(session);
    saveLog(log);
    
    // Allow the prompt to proceed
    process.exit(0);
    
  } catch (error) {
    console.error("Error in user prompt hook:", error);
    process.exit(0);
  }
}

main();
